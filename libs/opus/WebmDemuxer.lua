local WebmBaseDemuxer = require('base/WebmBaseDemuxer')

local WebmDemuxer = WebmBaseDemuxer:extend()

function WebmDemuxer:initialize()
  WebmBaseDemuxer.initialize(self)
end

function WebmDemuxer:_checkHead(data)
  if string.sub(data, 1, 8) ~= "OpusHead" then
    error('Audio codec is not Opus!')
  end
end

return WebmDemuxer