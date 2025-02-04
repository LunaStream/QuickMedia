local fs = require('fs')
local prism_opus = require('opus')

fs.createReadStream('./sample/speech.ogg')
  :pipe(prism_opus.OggDemuxer:new())
  :pipe(fs.createWriteStream('./results/speech.ogg.json.debug.2'))