local Transform = require('stream').Transform

local PCMStream = Transform:extend()

function PCMStream:initialize()
  Transform.initialize(self)
end

function PCMStream:_transform(chunk, done)
  self:emit('raw-pcm-data', chunk)
  done(nil)
end

return PCMStream