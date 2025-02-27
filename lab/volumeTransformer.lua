-- VolumeTransformer Test

local buffer = require("buffer")
local VolumeTransformer = require("../libs/mu_core/VolumeTransformer")

local Readable = require('stream').Readable

local AudioSource = Readable:extend()

function AudioSource:initialize(options)
  Readable.initialize(self, options)
  self._writeData = options.data
end

function AudioSource:_read()
  self:push(self._writeData)
  self:push(nil)
end

local function streamToBuffer(stream)
    local chunks = table.pack(stream:read())
    p(chunks)
    return buffer.concat(chunks)
end

local function writeBuffer(ints, format)
    local buf
    if format == "s16le" then
        buf = buffer.new(#ints * 2)
        for i, value in ipairs(ints) do
            buf:writeInt16LE(value, (i - 1) * 2)
        end
    elseif format == "s16be" then
        buf = buffer.new(#ints * 2)
        for i, value in ipairs(ints) do
            buf:writeInt16BE(value, (i - 1) * 2)
        end
    elseif format == "s32le" then
        buf = buffer.new(#ints * 4)
        for i, value in ipairs(ints) do
            buf:writeInt32LE(value, (i - 1) * 4)
        end
    elseif format == "s32be" then
        buf = buffer.new(#ints * 4)
        for i, value in ipairs(ints) do
            buf:writeInt32BE(value, (i - 1) * 4)
        end
    else
        error("Unknown type '" .. format .. "'")
    end
    return buf
end

local function testVolume(type)
    local output = AudioSource:new({ data = writeBuffer({ 1,2,3}, type) }):pipe(VolumeTransformer:new({ type = type, volume = 1}))

    local buf = streamToBuffer(output)

    p(buf)
end

p(testVolume('s16le'))