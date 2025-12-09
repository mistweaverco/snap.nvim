local M = {}
local Config = require("snap.config")
local Runner = require("snap.runner")
local Backend = require("snap.backend")

---Sets up Snap with the provided configuration.
---@param config SnapConfig|nil Configuration table for Snap
M.setup = function(config)
  Config.setup(config)

  -- Create user command
  -- Allow range so it can be called from visual mode
  vim.api.nvim_create_user_command("Snap", function(opts)
    -- Use the range from the command if available (when called from visual mode)
    -- When range is provided, opts.line1 and opts.line2 contain the start and end lines
    -- opts.range contains the count (line2 - line1 + 1)
    local range_start = nil
    local range_end = nil

    -- Check if range was provided (opts.range will be set if command was called with range)
    if opts.range and opts.range > 0 and opts.line1 and opts.line2 then
      range_start = opts.line1
      range_end = opts.line2
    end

    Runner.run(range_start, range_end)
  end, {
    desc = "Take a screenshot of the current file or visual selection",
    nargs = 0,
    range = true, -- Allow range so it works in visual mode
  })
end

M.install_backend = function()
  Backend.install()
end

M.run = function()
  Runner.run()
end

return M
