local M = {}
local Types = require("snap.types")
local Logger = require("snap.logger")
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

    -- Parse arguments: support both type and key-value pairs/instructions
    -- Examples:
    --   :Snap image
    --   :Snap image cache=false
    --   :Snap image nocache
    --   :Snap image cache=false ui=true
    local args_str = opts.args or ""
    local args_list = {}

    -- Split arguments by spaces
    if args_str ~= "" then
      for arg in args_str:gmatch("%S+") do
        table.insert(args_list, arg)
      end
    end

    -- Parse arguments
    local type = Types.SnapPayloadType.image -- Default
    local command_opts = {
      use_cache = true, -- Default to caching
      use_ui_attach = false, -- Default to buffer-based method
    }

    for _, arg in ipairs(args_list) do
      -- Check if it's a payload type
      if Types.SnapPayloadType[arg] ~= nil then
        type = arg
      -- Check if it's a key-value pair (e.g., cache=false)
      elseif arg:find("=") then
        local key, value = arg:match("([^=]+)=(.+)")
        if key and value then
          key = key:lower()
          if key == "cache" then
            command_opts.use_cache = value:lower() ~= "false" and value:lower() ~= "0"
          elseif key == "ui" or key == "ui_attach" then
            command_opts.use_ui_attach = value:lower() == "true" or value:lower() == "1"
          end
        end
      -- Check if it's an instruction (e.g., nocache)
      else
        local instruction = arg:lower()
        if instruction == "nocache" then
          command_opts.use_cache = false
        elseif instruction == "cache" then
          command_opts.use_cache = true
        elseif instruction == "ui" or instruction == "ui_attach" then
          command_opts.use_ui_attach = true
        end
      end
    end

    Runner.run({
      type = type,
      range = range,
      use_cache = command_opts.use_cache,
      use_ui_attach = command_opts.use_ui_attach,
    })
  end, {
    desc = "Take a screenshot of the current file or visual selection",
    nargs = "*", -- Allow multiple arguments
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
