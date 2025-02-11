local fs = require('fs')
local mu_opus = require('mu_opus')
local stream = require('stream')
local Transform = stream.Transform

local CustomWriteStream = Transform:extend()

function CustomWriteStream:initialize()
  Transform.initialize(self)
  self.fd = fs.openSync('./lab/results/speech.ogg.demux', 'w')
end

function CustomWriteStream:_transform(chunk, done)
  fs.writeSync(self.fd, -1, chunk)
  done(nil)
end

fs.createReadStream('./lab/sample/speech.ogg')
  :pipe(mu_opus.OggDemuxer:new())
  :pipe(CustomWriteStream:new())