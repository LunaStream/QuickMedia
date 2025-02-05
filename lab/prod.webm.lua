local fs = require('fs')
local prism_opus = require('opus')
local Transform = require('stream').Transform

local CustomWriteStream = Transform:extend()

function CustomWriteStream:initialize()
  Transform.initialize(self)
  self.fd = fs.openSync('./lab/results/videoplayback.webm.demux', 'w')
end

function CustomWriteStream:_transform(chunk, done)
  fs.writeSync(self.fd, -1, chunk)
  done(nil)
end

fs.createReadStream('./lab/sample/videoplayback.webm')
  :pipe(prism_opus.WebmDemuxer:new())
  :pipe(CustomWriteStream:new())