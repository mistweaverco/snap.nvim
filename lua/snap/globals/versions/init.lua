local backend_version = require("snap.globals.versions.backend")
local plugin_version = require("lua.snap.globals.versions.plugin")

local M = {
  plugin = plugin_version,
  backend = backend_version,
}

return M
