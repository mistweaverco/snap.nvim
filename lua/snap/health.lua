local Globals = require("snap.globals")
local Backend = require("snap.backend")

local health = vim.health
local info = health.info
local backend_version = Backend.get_installed_version() or nil
local backend_info = backend_version and "version" .. backend_version .. " in " .. Backend.get_bin_path()
  or "not installed"

local M = {}

M.check = function()
  info("{snap.nvim} version " .. Globals.VERSION)
  info("Backend: " .. backend_info)
end

return M
