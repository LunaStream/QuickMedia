local fs = require('fs')
local file_data = fs.readFileSync('./results/videoplayback.raw.opus')

p(string.sub(file_data, 1, 5))
