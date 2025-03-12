local fs = require('fs')
local timer = require('timer')
local mu_opus = require('mu_opus')
local mu_stream = require('mu_stream')
local mu_core = require('mu_core')

local fd = fs.openSync('./lab/results/videoplayback.pcm', 'w+')

local audioStream = mu_stream.file:new('./lab/sample/videoplayback.webm')
  :pipe(mu_opus.WebmDemuxer:new())
  :pipe(quickmedia.opus.Decoder:new('D:/Github/LunaStream/LunaStream/bin/opus-win32-x64.dll'))
  :pipe(mu_core.VolumeTransformer:new({ type = "s16le", volume = 0.1 }))

timer.setInterval(2, function ()
  local data = audioStream:read()
  p('Result: ', type(data) == "string" and #data or data)
  if type(data) == "string" then fs.writeSync(fd, -1, data) end
end)