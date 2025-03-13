local Transform = require('stream').Transform
local ffi = require("ffi")
local Decoder = Transform:extend()

local CHUNK_STRING_SIZE_MAX = 8192

---------------------------------------------------------------
-- Function: truncate
-- Parameters: num (number) - the number to truncate.
-- Objective: Truncates a number towards zero.
---------------------------------------------------------------
local function truncate(num)
  if num >= 0 then
    return math.floor(num)
  else
    return math.ceil(num)
  end
end

---------------------------------------------------------------
-- Function: round_then_truncate
-- Parameters: num (number) - the number to round and then truncate.
-- Objective: Rounds the number (adding 0.5 then flooring) and then truncates it.
---------------------------------------------------------------
local function round_then_truncate(num)
  local rounded = math.floor(num + 0.5)
  return truncate(rounded)
end

---------------------------------------------------------------
-- Function: splitByChunk
-- Parameters: 
--    text (string) - the text to split,
--    chunkSize (number) - the size of each chunk.
-- Objective: Splits a string into chunks of the specified size and returns them as an array.
---------------------------------------------------------------
local function splitByChunk(text, chunkSize)
  local s = {}
  for i = 1, #text, chunkSize do
    s[#s + 1] = text:sub(i, i + chunkSize - 1)
  end
  return s
end

function Decoder:initialize(bin_path)
  Transform.initialize(self, { objectMode = true })

  ffi.cdef[[
    typedef struct {
        unsigned min_blocksize;
        unsigned max_blocksize;
        unsigned min_framesize;
        unsigned max_framesize;
        unsigned sample_rate;
        unsigned channels;
        unsigned bits_per_sample;
        uint64_t total_samples;
        uint8_t md5sum[16];
    } FLAC__StreamMetadata_StreamInfo;

    typedef struct {
        int type; // Metadata type (0 = StreamInfo)
        int is_last;
        unsigned length;
        union {
            FLAC__StreamMetadata_StreamInfo stream_info;
        } data;
    } FLAC__StreamMetadata;

    typedef struct FLAC__StreamDecoder FLAC__StreamDecoder;

    typedef enum {
        FLAC__STREAM_DECODER_INIT_STATUS_OK = 0
    } FLAC__StreamDecoderInitStatus;

    typedef enum {
      FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE = 0,
      FLAC__STREAM_DECODER_WRITE_STATUS_ABORT = 1
    } FLAC__StreamDecoderWriteStatus;

    typedef enum {
      FLAC__STREAM_DECODER_READ_STATUS_CONTINUE = 0,
      FLAC__STREAM_DECODER_READ_STATUS_END_OF_STREAM = 1,
      FLAC__STREAM_DECODER_READ_STATUS_ABORT = 2
    } FLAC__StreamDecoderReadStatus;

    typedef enum {
      FLAC__STREAM_DECODER_SEARCH_FOR_METADATA = 0,
      FLAC__STREAM_DECODER_READ_METADATA,
      FLAC__STREAM_DECODER_SEARCH_FOR_FRAME_SYNC,
      FLAC__STREAM_DECODER_READ_FRAME,
      FLAC__STREAM_DECODER_END_OF_STREAM,
      FLAC__STREAM_DECODER_OGG_ERROR,
      FLAC__STREAM_DECODER_SEEK_ERROR,
      FLAC__STREAM_DECODER_ABORTED,
      FLAC__STREAM_DECODER_MEMORY_ALLOCATION_ERROR,
      FLAC__STREAM_DECODER_UNINITIALIZED
    } FLAC__StreamDecoderState;

    typedef FLAC__StreamDecoderReadStatus (*FLAC__StreamDecoderReadCallback)(
        const FLAC__StreamDecoder *decoder,
        void *buffer, size_t *bytes,
        void *client_data
    );

    typedef FLAC__StreamDecoderWriteStatus (*FLAC__StreamDecoderWriteCallback)(
        const FLAC__StreamDecoder *decoder,
        const void *frame,
        const int32_t * const buffer[],
        void *client_data
    );

    typedef void (*FLAC__StreamDecoderMetadataCallback)(
        const FLAC__StreamDecoder *decoder,
        const FLAC__StreamMetadata_StreamInfo *metadata,
        void *client_data
    );

    typedef void (*FLAC__StreamDecoderErrorCallback)(
        const FLAC__StreamDecoder *decoder,
        int status, void *client_data
    );

    FLAC__StreamDecoder *FLAC__stream_decoder_new(void);
    FLAC__StreamDecoderInitStatus FLAC__stream_decoder_init_stream(
        FLAC__StreamDecoder *decoder,
        FLAC__StreamDecoderReadCallback read_callback,
        void *seek_callback,
        void *tell_callback,
        void *length_callback,
        void *eof_callback,
        FLAC__StreamDecoderWriteCallback write_callback,
        FLAC__StreamDecoderMetadataCallback metadata_callback,
        FLAC__StreamDecoderErrorCallback error_callback,
        void *client_data
    );
    int FLAC__stream_decoder_get_state(FLAC__StreamDecoder *decoder);
    int FLAC__stream_decoder_process_single(FLAC__StreamDecoder *decoder);
    int FLAC__stream_decoder_finish(FLAC__StreamDecoder *decoder);
    void FLAC__stream_decoder_delete(FLAC__StreamDecoder *decoder);

    typedef struct {
      struct {
          unsigned blocksize;
          unsigned sample_rate;
          unsigned channels;
          unsigned bits_per_sample;
          unsigned number_type;
          unsigned crc;
      } header;
    } FLAC__Frame;
  ]]

  local loaded, lib = pcall(ffi.load, bin_path)
  if not loaded then
    error(lib)
  end
  self._lib = lib

  self._current_bps = nil
  self._decoder = nil

  self._is_stop = false
  self._chunk_cache = {}
  self._current_done = nil

  self:once('close', function () self:close() end)

  self:setupListener()
end

function Decoder:setupListener()
  -- Read request from flac lib
  local function read_callback(decoder, buffer, bytes, client_data)
    if #self._chunk_cache == 0 then
      return ffi.C.FLAC__STREAM_DECODER_READ_STATUS_CONTINUE
    end

    local current_data = table.remove(self._chunk_cache, 1)

    if type(current_data) == "table" then
      bytes[0] = 0
      return ffi.C.FLAC__STREAM_DECODER_READ_STATUS_END_OF_STREAM
    end

    ffi.copy(buffer, current_data, #current_data)

    bytes[0] = #current_data
    return ffi.C.FLAC__STREAM_DECODER_READ_STATUS_CONTINUE
  end

  -- Write response from flac library
  local function write_callback(decoder, frame, buffer, client_data)
    local frame_ptr = ffi.cast("FLAC__Frame*", frame)
    local samples = frame_ptr.header.blocksize
    local channels = frame_ptr.header.channels

    local pcm_data = {}

    for i = 0, samples - 1 do
      for ch = 0, channels - 1 do
        local sample = ffi.cast("int32_t*", buffer[ch])[i]
        -- Convert sample based on bit depth
        if self._current_bps == 16 then
          sample = bit.rshift(sample, 16)  -- Convert to 16-bit
          table.insert(pcm_data, string.pack("<i2", sample))
        elseif self._current_bps == 24 then
          local b1 = sample % 256
          local b2 = math.floor(sample / 256) % 256
          local b3 = math.floor(sample / 65536) % 256
          table.insert(pcm_data, string.char(b1, b2, b3))  -- Pack 24-bit
        else
          table.insert(pcm_data, string.pack("<i4", sample)) -- Default to 32-bit
        end
      end
    end

    self:push(table.concat(pcm_data))

    return ffi.C.FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE
  end

  -- Metadata callback
  local function metadata_callback(decoder, metadata, client_data)
    local meta = ffi.cast("FLAC__StreamMetadata*", metadata)
    if meta.type == 0 then
      self._current_bps = meta.data.stream_info.bits_per_sample
    end
  end

  -- Error callback
  local function error_callback(decoder, status, client_data)
    self:close()
  end

  -- Create FLAC decoder
  self._decoder = self._lib.FLAC__stream_decoder_new()
  if self._decoder == nil then
    error("Failed to create FLAC decoder")
  end

  -- Initialize FLAC decoder
  local initial_res = self._lib.FLAC__stream_decoder_init_stream(
    self._decoder,
    read_callback,
    nil, nil, nil, nil,
    write_callback,
    metadata_callback,
    error_callback, nil
  )
  if initial_res ~= ffi.C.FLAC__STREAM_DECODER_INIT_STATUS_OK then
    error("Failed to initialize FLAC decoder")
  end
end

function Decoder:_transform(chunk, done)
  if type(chunk) ~= "string" then
    if type(chunk) == "table" then
      table.insert(self._chunk_cache, {})

      while self._lib.FLAC__stream_decoder_get_state(self._decoder) == ffi.C.FLAC__STREAM_DECODER_END_OF_STREAM do
        self._lib.FLAC__stream_decoder_process_single(self._decoder)
      end

      self:close()
    end
    self:push(chunk)
    return done()
  end

  if #chunk <= CHUNK_STRING_SIZE_MAX then
    table.insert(self._chunk_cache, chunk)
  else
    local caculation = round_then_truncate(#chunk / CHUNK_STRING_SIZE_MAX)
    for _, mini_chunk in pairs(splitByChunk(chunk, round_then_truncate(#chunk / caculation))) do
      table.insert(self._chunk_cache, mini_chunk)
    end
  end

  while true do
    if #self._chunk_cache <= 3 then return done() end
    self._lib.FLAC__stream_decoder_process_single(self._decoder)
  end
end

function Decoder:close()
  self._lib.FLAC__stream_decoder_delete(self._decoder)
end

return Decoder