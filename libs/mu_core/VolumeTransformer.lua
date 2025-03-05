-- ported from prism-media (NODE.js) <prism-media github link here>

-- TODO: Comments for methods/functions

local Buffer = require("buffer").Buffer
local stream = require("stream")

local Transform = stream.Transform

local VolumeTransformer = Transform:extend()

function VolumeTransformer:initialize(options)
    
    Transform.initialize(self)
    -- some vars/props here
    if options.type == 's16le' then
        function VolumeTransformer:_readInt(buffer, index)
            p('called [readInt]', 'index: ', index, type(buffer))
            -- Stuck below somewhere
            p('hi', buffer:readInt16LE(index))
            return buffer:readInt16LE(index);
        end

        function VolumeTransformer:_writeInt(buffer, int, index)
            p('called [writeInt]', index)
            buffer.writeInt16LE(int, index)
        end

        self._bits = 16;

        p('VolumeTransformer - setting functions', options.type, self._bits, self._readInt, self._writeInt)
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

    self._chunk = Buffer:new(0);
end


    function VolumeTransformer:_readInt(buffer, index)
        return index;
    end

    function VolumeTransformer:_writeInt(buffer, int, index) 
        return index;
    end

    function VolumeTransformer:_transform(chunk, done) 
        p('VolumeTransformer - default log', #chunk, chunk.length, type(chunk))
        -- If the volume is 1, act like a passthrough stream
        if self.volume == 1 then
            p('VolumeTransformer', #chunk)
            self:push(chunk);
            return done();
        end

        chunk = self._chunk .. chunk
        p('hi', chunk.length, self._bytes, #chunk < self._bytes)

        p('Hello after hi')

        if #chunk < self._bytes then
            p("hmm")
            return done()
        end
        
        p('moved to before complete variable', chunk.length, self._bytes)

        local complete = math.floor(#chunk / self._bytes) * self._bytes;

        p('moved after complete', complete - 1)
        for i = 0, complete - 1, self._bytes do
            p('looping', i, complete, self._bytes, self._extremum)
            -- p(chunk, self.volume, math.floor(self.volume * i))
            p('readInt output logged from loop ->', self:_readInt(chunk, i))
            -- local int = math.min(self._extremum - 1, math.max(-self._extremum, math.floor(self.volume * self:_readInt(chunk, i))))
            -- self:_writeInt(chunk, int, i)
        end
        p('moved after loop')
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