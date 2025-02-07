local fs = require('fs')
local setInterval = require('timer').setInterval
local prism_opus = require('opus')
local stream = require('stream')
local Transform = stream.Transform

local CustomReadableTransform = Transform:extend()

function CustomReadableTransform:initialize()
  Transform.initialize(self)
  self.buffer_cache = {}
  self.is_stream_end = false
end

function CustomReadableTransform:_transform(chunk, done)
  table.insert(self.buffer_cache, chunk)
  done(nil)
end

function CustomReadableTransform:exRead()
  if self.is_stream_end then return nil end
  local res = self.buffer_cache[1]
  table.remove(self.buffer_cache, 1)
  if #self.buffer_cache == 0 then
    self.is_stream_end = true
  end
  return res
end

local pre_stream = fs.createReadStream('./lab/sample/speech.ogg')
  :pipe(prism_opus.OggDemuxer:new())
  :pipe(CustomReadableTransform:new())

setInterval(200, function ()
  coroutine.wrap(function()
    local res = pre_stream:exRead()
    if res then p(#res, res) end
  end)()
end)

-- pre_stream:on('prefinish', function ()
--   p('Prefinish')
-- end)

-- pre_stream:on('finish', function ()
--   p('Finished')
-- end)

-- pre_stream:on('end', function ()
--   p('Ended')
--   p(pre_stream:readDay())
-- end)

-- p(stream:read()) <-- This supposed to return a string (buffer) right