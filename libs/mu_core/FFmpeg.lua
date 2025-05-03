local Duplex = require('stream').Duplex
local childprocess = require('childprocess')
local coro_channel = require('coro-channel')
local net = require('net')
local uv = require('uv')

local ModifiedSocket = net.Socket:extend()

function ModifiedSocket:initialize(options)
  net.Socket.initialize(self, options)
  self.this_is_modified = true
  local read_stream, write_stream = coro_channel.wrapStream(self._handle)
  self.read_stream = read_stream
  self.write_stream = write_stream
end

function ModifiedSocket:_read(n) end

local FFmpeg = Duplex:extend()

function FFmpeg:initialize(options)
  -- Configurations
	options = options or {}
	Duplex.initialize(self, { objectMode = true })

  --Args
  self.args = options.args or {}
  self.path = assert(options.path, 'Binary path missing')
  self.finished_function = nil

  -- Child process
  local child, err = childprocess.spawn(self.path, self.args, {
    stdio = {
      net.Socket:new({ handle = uv.new_pipe(false) }),
      ModifiedSocket:new({ handle = uv.new_pipe(false) }),
      net.Socket:new({ handle = uv.new_pipe(false) }),
    }
  })
  if not child then
    self.failed = err
    return
  end
  self.child = child
  self.write_done = false
end

function FFmpeg:_write(chunk, done)
  if type(chunk) == "table" then
    self.write_done = true
    return done()
  end
  self.child.stdin:write(chunk, done)
end

function FFmpeg:read(n)
  if #self._readableState.buffer == 0 and self.write_done then
    self.write_done = false
    return {}
  end
  return Duplex.read(self, n)
end

function FFmpeg:_read()
  coroutine.wrap(function (...)
    local data, err = self.child.stdout:read_stream()
    if err then
      return self:destroy(err)
    elseif data then
      self:push(data)
    else
      self.child.stdin:destroy()
    end
  end)()
end

return FFmpeg