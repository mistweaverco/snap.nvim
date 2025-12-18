local plugin_version = require("snap.globals.versions.plugin")
local backend_version = require("snap.globals.versions.backend")
local M = {}

M.VERSION = plugin_version
M.BACKEND_VERSION = backend_version
M.NAME = "snap.nvim"

return M
