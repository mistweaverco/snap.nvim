local Globals = require("snap.globals")
local Logger = require("snap.logger")
local Api = require("snap.api")
local M = {}

---Sets up Snap with the provided configuration.
---@param config SnapConfig|nil Configuration table for Snap
M.setup = function(config)
  Api.setup(config)
end

M.run = function()
  Api.run()
end

M.install_backend = function()
  Api.install_backend()
end

---Prints the current Snap version and Neovim version to the log.
M.version = function()
  local neovim_version = vim.fn.execute("version") or "Unknown"
  Logger.info("Snap version: " .. Globals.VERSION .. "\n\n" .. "Neovim version: " .. neovim_version)
end

return M
