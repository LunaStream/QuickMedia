local Transform = require('stream').Transform

local VolumeTransformer = Transform:extend()

function VolumeTransformer:initialize(options, pipe_option)
	options = options or {}
	Transform.initialize(self, pipe_option)

	self._maxSample = nil
	self._sampleSize = nil
	self._format = nil

	self._options = options
  self.volume = self._options.volume or 1.0

	if self._options.type == "s16le" then
		self._maxSample = 32768
    self._sampleSize = 2
    self._format = "<h"
	elseif self._options.type == "s16be" then
		self._maxSample = 32768
    self._sampleSize = 2
    self._format = ">h"
	elseif self._options.type == "s32le" then
		self._maxSample = 2147483648
    self._sampleSize = 4
    self._format = "<h"
	elseif self._options.type == "s32be" then
		self._maxSample = 2147483648
    self._sampleSize = 4
    self._format = ">h"
  else
    error('VolumeTransformer type should be one of s16le, s16be, s32le, s32be')
  end
end

function VolumeTransformer:_transform(data, done)
	if type(data) ~= "string" or self.volume == 1.0 then
    self:push(data)
    done()
    return
  end

  local newData = {}
  for i = 1, #data, self._sampleSize do
    local sample = string.unpack(self._format, data, i) * self.volume
    if sample > self._maxSample - 1 then
      sample = self._maxSample - 1
    elseif sample < -self._maxSample then
      sample = -self._maxSample
    end
    table.insert(newData, string.pack(self._format, math.floor(sample)))
  end

	self:push(table.concat(newData))
	done()
end

function VolumeTransformer:setVolume(volume)
  self.volume = volume
end

function VolumeTransformer:getVolume()
  return self.volume
end

return VolumeTransformer