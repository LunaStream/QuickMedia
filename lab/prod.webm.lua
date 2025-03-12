local fs = require('fs')
local timer = require('timer')
local mu_opus = require('mu_opus')
local mu_stream = require('mu_stream')

local fd = fs.openSync('./lab/results/videoplayback.pcm', 'w+')

local audioStream = mu_stream.file:new('./lab/sample/videoplayback.webm')
  :pipe(mu_opus.WebmDemuxer:new())
  :pipe(MusicUtils.opus.Decoder:new('D:/Github/LunaStream/LunaStream/bin/opus-win32-x64.dll'))

timer.setInterval(2, function ()
  local data = audioStream:read()
  p('Result: ', type(data) == "string" and #data or data)
  if type(data) == "string" then fs.writeSync(fd, -1, data) end
end)