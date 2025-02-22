local WebmBase = require('mu_core/WebmBase')

local WebmDemuxer = WebmBase:extend()

function WebmDemuxer:initialize()
  WebmBase.initialize(self)
end

function WebmDemuxer:_checkHead(data)
  if string.sub(data, 1, 8) ~= "OpusHead" then
    error('Audio codec is not Opus!')
  end
end

return WebmDemuxer
