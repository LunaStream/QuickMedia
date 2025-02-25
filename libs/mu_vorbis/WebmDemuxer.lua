local WebmBase = require('mu_core/WebmBase')

local WebmDemuxer = WebmBase:extend()

function WebmDemuxer:initialize()
  WebmBase.initialize(self)
end

function WebmDemuxer:_checkHead(data)
  if string.byte(data, 1) ~= 2 and string.sub(data, 5, 10) ~= "vorbis" then
    error('Audio codec is not Vorbis!')
  end

  self:push(string.sub(data, 4, 3 + string.byte(data, 2)))
  self:push(string.sub(data, 4 + string.byte(data, 2), 3 + string.byte(data, 2) + string.byte(data, 3)))
  self:push(string.sub(data, 4 + string.byte(data, 2) + string.byte(data, 3)))
end

return WebmDemuxer