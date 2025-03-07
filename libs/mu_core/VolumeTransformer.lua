local Transform = require('stream').Transform

local VolumeTransformer = Transform:extend()

function VolumeTransformer:initialize(options)
	options = options or {}
	Transform.initialize(options)

	self._maxSample = nil
	self._sampleSize = nil
	self._format = nil

	self._options = options
  self.volume = self._options.volume or 1.0

	if self._options == "s16le" then
		self._maxSample = 32768
    self._sampleSize = 2
    self._format = "<h"
	elseif self._options == "s16be" then
		self._maxSample = 32768
    self._sampleSize = 2
    self._format = ">h"
	elseif self._options == "s32le" then
		self._maxSample = 2147483648
    self._sampleSize = 4
    self._format = "<h"
	elseif self._options == "s32be" then
		self._maxSample = 2147483648
    self._sampleSize = 4
    self._format = ">h"
	end
end

function VolumeTransformer:_transform(data, done)
	if type(data) ~= "string" then
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