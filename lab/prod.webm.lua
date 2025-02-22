local fs = require('fs')
local timer = require('timer')
local mu_opus = require('mu_opus')
local mu_core = require('mu_core')
local Transform = require('stream').Transform

local CustomWriteStream = Transform:extend()

function CustomWriteStream:initialize()
  Transform.initialize(self)
  self.fd = fs.openSync('./lab/results/videoplayback.pcm', 'w')
end

function CustomWriteStream:_transform(chunk, done)
  fs.writeSync(self.fd, -1, chunk)
  done(nil)
end

local audioStream = fs.createReadStream('./lab/sample/videoplayback.webm'):pipe(mu_opus.WebmDemuxer:new()):pipe(
  mu_opus.Decoder:new(
    'D:/Github/LunaStream/LunaStream/bin/opus_win32_x64.dll'
  )
)

-- :pipe(CustomWriteStream:new())

timer.setTimeout(
  7000, coroutine.wrap(
    function()
      local pcm = mu_core.PCMStream:new()
      pcm:on('raw-pcm-data', function(chunk) p(#chunk) end)
      p('Voice EXP: Now play the song')
      audioStream:pipe(pcm)
    end
  )
)
