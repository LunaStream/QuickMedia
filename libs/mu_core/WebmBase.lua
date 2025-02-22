local Transform = require('stream').Transform

local WebmBase = Transform:extend()

local TAGS = {
  ['\026E\223\163'] = true, -- EBML (1a45dfa3)
  ['\024S\128g'] = true, -- Segment (18538067)
  ['\031C\182u'] = true, -- Cluster (1f43b675)
  ['\022T\174k'] = true, -- Tracks (1654ae6b)
  ['\174'] = true, -- TrackEntry (ae)
  ['\215'] = false, -- TrackNumber (d7)
  ['\131'] = false, -- TrackType (83)
  ['\163'] = false, -- SimpleBlock (a3)
  ['c\162'] = false, -- (63a2)
}

function WebmBase:initialize()
  Transform.initialize(self, { objectMode = true })
  self.count = 1
  self.length = 0
  self.ebmlFound = false
  self.skipUntil = nil
  self._track = nil
  self._incompleteTrack = {}
  self.remind_buffer = nil
  self.chunk_debug = nil
  self:on(
    'end', function()
      coroutine.wrap(self.freeMem)(self)
    end
  )
end

function WebmBase:freeMem()
  self.count = 1
  self.length = 0
  self.ebmlFound = false
  self.skipUntil = nil
  self._track = nil
  self._incompleteTrack = {}
  self.remind_buffer = nil
  self.chunk_debug = nil
  collectgarbage("collect")
end

function WebmBase:_checkHead(data)
  error('checkHead not yet implemented')
end

function WebmBase:_transform(chunk, done)
  if type(chunk) ~= "string" then
    self:push(chunk)
    done()
    return
  end

  self.length = self.length + #chunk

  if self.remind_buffer and #self.remind_buffer > 0 then
    chunk = self.remind_buffer .. chunk
    self.remind_buffer = nil
  end

  local offset = 1

  if self.skipUntil and self.length > self.skipUntil then
    offset = self.skipUntil - self.count
    self.skipUntil = nil
  elseif type(self.skipUntil) ~= "nil" then
    self.count = self.count + #chunk
    done()
    return
  end

  local result = nil
  while result ~= "TOO_SHORT" do
    local success
    success, result = pcall(self.readTag, self, chunk, offset)
    if not success then
      done(result)
      return
    end
    if result == "TOO_SHORT" then
      break
    end
    if result.skipUntil then
      self.skipUntil = result.skipUntil
      break
    end
    if result.offset then
      offset = result.offset
    else
      break
    end
  end

  self.count = self.count + offset
  self.remind_buffer = string.sub(chunk, offset)

  done(nil)
end

function WebmBase:readTag(data, offset)
  local idData = self:readEBMLId(data, offset)
  if idData == "TOO_SHORT" then
    return "TOO_SHORT"
  end
  local ebmlID = idData.id
  if not self.ebmlFound then
    if ebmlID == "\026E\223\163" then
      self.ebmlFound = true
    else
      error('Did not find the EBML tag at the start of the stream')
    end
  end

  offset = idData.offset

  -- Read header tag data size
  local sizeData = self:readTagDataSize(data, offset)
  if sizeData == "TOO_SHORT" then
    return "TOO_SHORT"
  end
  offset = sizeData.offset

  local dataLength = sizeData.dataLength

  if type(TAGS[ebmlID]) == "nil" then
    if #data > offset + dataLength then
      return { offset = offset + dataLength }
    end
    return { offset = offset, skipUntil = self.count + offset + dataLength + 1 }
  end

  local tagHasChildren = TAGS[ebmlID]
  if tagHasChildren then
    return { offset = offset }
  end

  if (dataLength == 'TOO_SHORT') or (offset + dataLength > #data) then
    return 'TOO_SHORT'
  end
  local process_data = string.sub(data, offset, offset + dataLength)
  if not self._track then
    if ebmlID == '\174' then
      self._incompleteTrack = {}
    end
    if ebmlID == '\215' then
      self._incompleteTrack.number = string.byte(process_data, 1, 1)
    end
    if ebmlID == '\131' then
      self._incompleteTrack.type = string.byte(process_data, 1, 1)
    end
    if self._incompleteTrack.type == 2 and self._incompleteTrack.number then
      self._track = self._incompleteTrack
    end
  end

  if ebmlID == 'c\162' then
    self:_checkHead(process_data)
  elseif ebmlID == '\163' then
    if not self._track then
      error('No audio track in this webm!')
    end
    if bit.band(string.byte(process_data, 1, 1), 0xF) == self._track.number then
      self:push(string.sub(process_data, 5, #process_data - 1))
    end
  end

  return { offset = offset + dataLength }
end

function WebmBase:readEBMLId(data, t_offset)
  local idLength = self:vintLength(data, t_offset)
  if idLength == "TOO_SHORT" then
    return "TOO_SHORT"
  end
  return {
    id = string.sub(data, t_offset, t_offset + idLength - 1),
    offset = t_offset + idLength,
  }
end

function WebmBase:readTagDataSize(data, t_offset)
  local sizeLength = self:vintLength(data, t_offset)
  if sizeLength == "TOO_SHORT" then
    return "TOO_SHORT"
  end
  local dataLength = self:expandVint(data, t_offset, t_offset + sizeLength)
  return {
    offset = t_offset + sizeLength,
    dataLength = dataLength,
    sizeLength = sizeLength,
  }
end

function WebmBase:vintLength(buffer, index)
  if index < 1 or index > #buffer then
    return "TOO_SHORT"
  end

  local i = 0
  for j = 0, 7 do
    if bit.band(bit.lshift(1, 7 - j), string.byte(buffer, index)) ~= 0 then
      break
    end
    i = i + 1
  end
  i = i + 1

  if index + i - 1 > #buffer then
    return "TOO_SHORT"
  end

  return i
end

function WebmBase:expandVint(buffer, start, _end)
  local length = self:vintLength(buffer, start)
  if _end > #buffer or length == "TOO_SHORT" then
    return "TOO_SHORT"
  end

  local mask = (bit.lshift(1, 8 - length)) - 1
  local value = bit.band(string.byte(buffer, start), mask)

  for i = start + 1, _end - 1 do
    value = bit.lshift(value, 8) + string.byte(buffer, i) -- left shift by 8, then add next byte
  end

  return value
end

return WebmBase
