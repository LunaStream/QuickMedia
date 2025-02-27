-- ported from prism-media (NODE.js) <prism-media github link here>

-- TODO: Comments for methods/functions

local Buffer = require("buffer")
local stream = require("stream")

local Transform = stream.Transform

local VolumeTransformer = Transform:extend()

function VolumeTransformer:initialize(options)
    
    Transform.initialize(self, options)
    -- some vars/props here
    if options.type == 's16le' then
        self._readInt = function (buffer, index)
            buffer.readInt16LE(index);
        end

        self._writeInt = function (buffer, int, index)
            buffer.writeInt16LE(int, index)
        end

        self._bits = 16;
    end

    if options.type == 's16be' then
        self._readInt = function (buffer, index)
            buffer.readInt16BE(index);
        end

        self._writeInt = function (buffer, int, index)
            buffer.writeInt16BE(int, index)
        end

        self._bits = 16;
    end

    if options.type == "s32le" then
        self._readInt = function (buffer, index)
            buffer.readInt32LE(index);
        end

        self._writeInt = function (buffer, int, index)
            buffer.writeInt32LE(int, index)
        end

        self._bits = 32;
    end

    if options.type == 's32be' then
        
        self._readInt = function (buffer, index)
            buffer.readInt32BE(index);
        end

        self._writeInt = function (buffer, int, index)
            buffer.writeInt32BE(int, index)
        end

        self._bits = 32;

    end
    
    if not options.type then
        error("VolumeTransformer type only accepts one of s16le, s16be, s32le, s32be types.")
    end

    self._bytes = self._bits / 8;
    
    self._extremum = math.pow(2, self._bits - 1)

    self.volume = options.volume or 1;

    self._chunk = Buffer.alloc(0);
end


    function VolumeTransformer:_readInt(buffer, index)
        return index;
    end

    function VolumeTransformer:_writeInt(buffer, int, index) 
        return index;
    end

    function VolumeTransformer:_transform(chunk, encoding, done) 
        -- If the volume is 1, act like a passthrough stream
        if self.volume == 1 then
            self:push(chunk);
            return done();
        end

        chunk = Buffer.concat(self._chunk, chunk);

        if chunk.length < self._bytes then
            return done()
        end

        local complete = math.floor(chunk.length / self._bytes) * self._bytes;

        for i = 0, complete - 1, self._bytes do
            local int = math.min(self._extremum - 1, math.max(-self._extremum, math.floor(self.volume * self:_readInt(chunk, i))))
            self:_writeInt(chunk, int, i)
        end

        self:push(chunk:sub(1, complete))

        return done()
    end

    function VolumeTransformer:_destroy()
        self._cleanup()
        self._chunk = nil;
    end

    function VolumeTransformer:setVolume(volume)
        self.volume = volume
    end

    function VolumeTransformer:setVolumeDecibels(db)
        self:setVolume(math.pow(10, db / 20))
    end

    function VolumeTransformer:setVolumeLogarithmic(value)
        self:setVolume(math.pow(value, 1.660964))
    end

return VolumeTransformer