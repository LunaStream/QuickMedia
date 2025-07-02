local HTTPStream = require('./mu_http')
local HTTPDefault = require('coro-http')
local Readable = require('stream').Readable

local HLSStream = Readable:extend()

function HLSStream:initialize(method, url, headers, body, customOptions)
  Readable.initialize(self, { objectMode = true })
	self.method = method
  self.uri = HTTPDefault.parseUrl(url)
	self.raw_uri = url
  self.headers = headers or {}
  self.body = body
  self.customOptions = customOptions
	self.uri_table = {}
	self.setup_complete = false
  self:parse_hls(self.raw_uri)
  self.first_run = false
  self.call_stream_running = false
end

function HLSStream:parse_hls(playlistUrl)
  print("Loading HLS stream from URL: " .. playlistUrl)

  local res, body = HTTPDefault.request("GET", playlistUrl)
  if res.code ~= 200 then
    error("HTTP error in playlist: " .. res.code)
    return
  end

  local isMasterPlaylist = body:match("#EXT%-X%-STREAM%-INF")
  if isMasterPlaylist then
    local playlistUrls = {}
    for line in body:gmatch("[^\r\n]+") do
      if not line:match("^#") and line:match("%S") then
        if not line:match("^https?://") then
          local baseUrl = playlistUrl:match("(.*/)")
          line = baseUrl .. line
        end
        table.insert(playlistUrls, line)
      end
    end
    if #playlistUrls > 0 then
      self:parse_hls(playlistUrls[1])
    else
      error("No valid playlist URLs found")
    end
  else
    local segments = {}
    for line in body:gmatch("[^\r\n]+") do
      if not line:match("^#") and line:match("%S") then
        if not line:match("^https?://") then
          local baseUrl = playlistUrl:match("(.*/)")
          line = baseUrl .. line
        end
        table.insert(segments, line)
      end
    end
    for _, segUrl in ipairs(segments) do
      table.insert(self.uri_table, segUrl)
    end
  end
end

function HLSStream:read(n)
  if not self.first_run then
    self.first_run = true
    for _ = 1, 16, 1 do
      self:_read()
    end
  else
    self:_read()
  end
  local data = Readable.read(self, n)
  return data
end

function HLSStream:countinuous_replace_stream(fn)
  self.call_stream_running = true

	if #self.uri_table == 0 then return self:push({}) end
	local get_stream_url = table.remove(self.uri_table, 1)

	self.http_stream = HTTPStream:new("GET", get_stream_url, self.headers, nil, self.customOptions):setup()

  coroutine.wrap(fn)(self)

  self.call_stream_running = false
end

function HLSStream:_read()
  if not self.http_stream and not self.call_stream_running then
    return self:countinuous_replace_stream(HLSStream.final_read_process)
  end

  if self.http_stream then
    return coroutine.wrap(HLSStream.final_read_process)(self)
  end
end

function HLSStream:final_read_process()
  local current_stream_data = self.http_stream:read()
  local length = type(current_stream_data) == "string" and #current_stream_data or "not_avaliable"

  local function recall_stream()
    self.http_stream = nil
    self:countinuous_replace_stream(HLSStream.final_read_process)
  end

  if type(current_stream_data) == "table" then
    return recall_stream()
  end

  if type(current_stream_data) == "string" then
    self:push(current_stream_data)
  end
end

return HLSStream