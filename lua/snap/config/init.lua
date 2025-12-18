require("snap.types")

local M = {}

---Default configuration for the screenshot plugin
---@type SnapConfig
M.defaults = {
  user_command = "Snap", -- Name of the user command to take screenshots
  debug = nil,
  timeout = 5000,
  template = "default", -- Built-in template name or "default"
  templateFilepath = nil, -- Absolute path to a custom HTML template file (optional)
  additional_template_data = nil, -- Table of additional data to pass to the template (optional)
  -- Output directory for screenshots (defaults to $HOME/Pictrures/Screenshots if nil)
  output_dir = nil,
  -- Generated filename pattern (supports %t for timestamp)
  -- e.g., "screenshot_%t" -> "screenshot_20240615_153045.png"
  filename_pattern = "snap.nvim_%t",
  copy_to_clipboard = {
    image = true, -- Whether to copy the image to clipboard
    html = true, -- Whether to copy the HTML to clipboard
  },
  notify = {
    enabled = true, -- Whether to show notifications
    provider = "notify", -- Notification provider: "notify", "print"
  },
  font_settings = {
    size = 14, -- Default font size for the screenshot
    line_height = 0.8, -- Default line height for the screenshot
    fonts = {
      default = {
        name = "FiraCode Nerd Font", -- Default font name for the screenshot
        file = nil, -- Absolute path to a custom font file (.ttf) (optional)
        -- Only needed if the font is not installed system-wide
        -- or if you want to export as HTML with the font embedded
        -- so you can view it correctly in E-mails or browsers
      },
      italic = {
        name = "FiraCode Nerd Font",
        file = nil,
      },
      bold = {
        name = "FiraCode Nerd Font",
        file = nil,
      },
      bold_italic = {
        name = "FiraCode Nerd Font",
        file = nil,
      },
    },
  },
}

---Current configuration options
---@type SnapConfig
M.options = M.defaults

---Initialize the configuration with user-provided settings
---merging them with the defaults
---@param config SnapUserConfig|nil User configuration to override defaults
M.setup = function(config)
  config = config or {}
  M.options = vim.tbl_deep_extend("force", M.defaults, config or {})
end

---Set configuration options, overriding default settings
---@param config SnapUserConfig User configuration to override current settings
M.set = function(config)
  M.options = vim.tbl_deep_extend("force", M.options, config or {})
end

---Get the current configuration, merged with defaults
---@return SnapConfig snapConfig configuration
M.get = function()
  return M.options
end

return M
