local M = {}

---@enum SnapConfigBackend
local SnapConfigBackend = {
  bun = "bun",
}

---SnapConfigDebug configuration for debugging the screenshot plugin
---@class SnapConfigDebug
---@field backend SnapConfigBackend Screenshot backend to debug
---@field log_level string Log level for debugging (e.g., "info", "debug", "warn", "error")

---Default configuration for the screenshot plugin
---@class SnapConfig
---@field debug SnapConfigDebug|nil Debug configuration
---@field output_dir string|nil Output directory for screenshots (defaults to $HOME/Pictures/Screenshots if nil)
---@field timeout number Timeout for screenshot operations in milliseconds
---@field filename_pattern string Screenshot filename pattern (supports %t for timestamp)
M.defaults = {
  debug = nil,
  timeout = 5000,
  -- Output directory for screenshots (defaults to $HOME/Pictrures/Screenshots if nil)
  output_dir = nil,
  -- Screenshot filename pattern (supports %t for timestamp)
  filename_pattern = "snap.nvim_%t.png",
}

M.options = M.defaults

---Initialize the configuration with user-provided settings
---@param config SnapConfig|nil User configuration to override defaults
M.setup = function(config)
  config = config or {}
  M.options = vim.tbl_deep_extend("force", M.defaults, config or {})
end

---Set configuration options
---@param config SnapConfig User configuration to override current settings
M.set = function(config)
  M.options = vim.tbl_deep_extend("force", M.options, config or {})
end

---Get the current configuration
---@return SnapConfig snapConfig configuration
M.get = function()
  return M.options
end

return M
