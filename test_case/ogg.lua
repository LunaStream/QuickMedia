local fs = require('fs')
local prism_opus = require('opus')
local Transform = require('stream').Transform

local CustomWriteStream = Transform:extend()

function CustomWriteStream:initialize()
  Transform.initialize(self)
  self.fd = fs.openSync('./results/speech.ogg.json.debug.2', 'w')
end

function CustomWriteStream:_transform(chunk, done)
  fs.writeSync(self.fd, -1, chunk)
  done(nil)
end

fs.createReadStream('./sample/speech.ogg')
  :pipe(prism_opus.OggDemuxer:new())
  :pipe(CustomWriteStream:new())