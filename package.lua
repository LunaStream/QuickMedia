return {
  name = "RainyXeon/quickmedia",
  version = "0.0.1",
  description = "A library that contains all ports code from prism-media (js to lua) and additional class, feature to processing audio on lua/luvit",
  tags = { "lua", "lit", "luvit" },
  license = "BSD-2-Clause",
  author = { name = "RainyXeon", email = "xeondev@xeondex.onmicrosoft.com" },
  homepage = "https://github.com/LunaStream/QuickMedia",
  dependencies = {
    "creationix/coro-http@v3.2.3",
  },
  files = { "**.lua", "!test*", "!lab*", "!tests*", },
}
