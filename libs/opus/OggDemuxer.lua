local Transform = require('stream').Transform

local OggDemuxer = Transform:extend()

function OggDemuxer:initialize()
  Transform.initialize(self)
  self.bitstream_serial_number = nil
  self.head_detected = nil
  self.remind_buffer = nil
  self:on('unknownSegment', function (segment)
    p('Unknown segment: ', string.sub(segment, 1, 10))
  end)
end

function OggDemuxer:_transform(chunk, done)
  if self.remind_buffer and #self.remind_buffer > 0 then
    chunk = self.remind_buffer .. chunk
    self.remind_buffer = nil
  end

  while chunk do
    local success, result = pcall(self.readPage, self, chunk)
    if not success then
      p('Error:', result)
      done(result)
      return
    end
    p('Next Part: ', (#result > 10) and string.sub(result, 1, 10) or 'Not avaliable')
    if result and #result > 0 then chunk = result
    else break end
  end
  self.remind_buffer = chunk
  done(nil)
end

function OggDemuxer:readPage(chunk)
  local bitstream_serial_number = string.unpack("<I4", chunk, 15)
  local page_segments = string.unpack("<I1", chunk, 27)
  local seg_table = string.sub(chunk, 28, 28 + page_segments)

  local sizes = {}
  local totalSize = 0
  local i = 1 -- Lua uses 1-indexing

  while i <= page_segments do
    local size = 0
    local x = 255

    while x == 255 do
      if i > #seg_table then
        return false
      end
      x = string.byte(seg_table, i)  -- string.byte returns the byte value at position i
      i = i + 1
      size = size + x
    end

    table.insert(sizes, size)
    totalSize = totalSize + size
  end

  local start = 28 + page_segments
  for _, size in pairs(sizes) do
    local segment = string.sub(chunk, start, start + size)
    local header = string.sub(segment, 1, 8)
    if self.head_detected then
      if header == "OpusTags" then
        self:emit('tags', segment)
      elseif self.bitstream_serial_signature == bitstream_serial_number then
        self:push(segment)
      end
    elseif header == 'OpusHead' then
      self:emit('head', segment);
      self.head_detected = segment
      self.bitstream_serial_signature = bitstream_serial_number
    else
      self:emit('unknownSegment', segment);
    end
    start = start + size;
  end

  return string.sub(chunk, start)
end

function OggDemuxer:_destroy(err, cb)
  self:_cleanup()
  return cb and cb(err) or nil
end

function OggDemuxer:_final(cb)
  self:_cleanup()
  return cb()
end

function OggDemuxer:_cleanup()
  self.remind_buffer = nil
  self.head_detected = nil
  self.bitstream_serial_number = nil
end

return OggDemuxer