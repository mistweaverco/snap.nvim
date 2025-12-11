local M = {}
local Config = require("snap.config")
local Runner = require("snap.runner")
local Backend = require("snap.backend")

---Sets up Snap with the provided configuration.
---@param config SnapUserConfig|nil Configuration table for Snap
M.setup = function(config)
  Config.setup(config)
  local conf = Config.get()

  -- Create user command
  vim.api.nvim_create_user_command(conf.user_command, function(opts)
    local range = nil

    --INFO:
    --Check if range was provided
    -- (opts.range will be set if command was called with range)
    if opts.range and opts.range > 0 and opts.line1 and opts.line2 then
      range = {
        start_line = opts.line1,
        end_line = opts.line2,
      }
    end

    Runner.run({
      range = range,
    })
  end, {
    desc = "Take a screenshot of the current file or visual selection",
    nargs = 0,
    range = true,
  })
end

M.install_backend = function()
  Backend.install()
end

M.run = function()
  Runner.run()
end

return M
