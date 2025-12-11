local M = {}

---@enum SnapPayloadType
M.SnapPayloadType = {
  image = "image",
  html = "html",
}

---@enum SnapImageOutputFormat
M.SnapImageOutputFormat = {
  png = "png",
  jpg = "jpg",
}

---@enum SnapConfigBackend
M.SnapConfigBackend = {
  bun = "bun",
}

---@enum SnapConfigFontSettingsFont
M.SnapConfigFontSettingsFont = {
  default = "default",
  italic = "italic",
  bold = "bold",
  bold_italic = "bold_italic",
}

---Visual range for taking a screenshot
---@class SnapVisualRange
---@field start_line number Start line (1-based)
---@field end_line number End line (1-based)

---@class SnapExportOptions
---@field filepath string|nil Absolute path to save the exported screenshot
---@field range SnapVisualRange|nil Visual range for taking a screenshot (optional)
---@field type SnapPayloadType|nil Type of screenshot to take ("image" or "html", defaults to "image" if nil)

---SnapRunOptions options for taking a screenshot command
---@class SnapRunOptions
---@field type SnapPayloadType|nil Type of screenshot to take ("image" or "html", defaults to "image" if nil)
---@field range SnapVisualRange|nil Visual range for taking a screenshot (optional)

---@class SnapHighlightStyle
---@field inline_css string CSS style string
---@field cls_name string|nil Class name string for HTML elements
---(possible concat values are "snap-is-bold", "snap-is-italic", "snap-is-underline")
---the output string can contain multiple classes separated by spaces
---e.g., "snap-is-bold snap-is-italic"
---@field hl_table table Highlight definition table

---User configuration for the screenshot plugin, extending SnapConfig
---@class SnapUserConfig
---@field user_command string|nil Name of the user command to take screenshots, defaults to "Snap"
---@field debug SnapConfigDebug|nil Debug configuration
---@field templateFilepath string|nil Absolute path to a custom HTML template file (optional)
---@field additional_template_data table|nil Table of additional data to pass to the template (optional)
---@field output_dir string|nil Output directory for screenshots (defaults to $HOME/Pictures/Screenshots if nil)
---@field timeout number|nil Timeout for screenshot operations in milliseconds
---@field filename_pattern string|nil Screenshot filename pattern (supports %t for timestamp)
---@field font_settings SnapConfigFontSettings|nil Font settings for the screenshot

---@class SnapPayloadDataTheme theme colors for the screenshot
---@field bgColor string Background color in hex format (e.g., "#000000")
---field fgColor string Foreground color in hex format (e.g., "#ffffff")

---@class SnapPayloadData
---field theme SnapPayloadDataTheme Theme colors for the screenshot
---@field additional_template_data table
---@field code table[] Array of code lines with their respective highlight styles
---@field filepath string
---@field fontSettings SnapConfigFontSettings
---@field outputImageFormat SnapImageOutputFormat
---@field templateFilepath string|nil
---@field transparent boolean
---@field type SnapPayloadType

---@class SnapPayload
---@field success boolean Whether the screenshot operation was successful
---@field debug boolean Whether debug mode was enabled for this payload (optional)
---@field data SnapPayloadData Payload data (optional)

---SnapConfigFontSetting configuration for a font setting
---@class SnapConfigFontSetting
---@field name string Font name for the screenshot
---@field file string|nil Absolute path to a custom font file (.ttf) (optional)
---@field size number Font size for the screenshot in pixels
---@field line_height number Line height for the screenshot (as a multiplier of font size) in pixels
---
---SnapConfigFontSettingsFonts configuration for font settings for different styles
---@class SnapConfigFontSettingFonts
---@field default SnapConfigFontSetting Default font setting for the screenshot
---@field italic SnapConfigFontSetting|nil Italic font setting for the screenshot (optional)
---@field bold SnapConfigFontSetting|nil Bold font setting for the screenshot (optional)
---@field bold_italic SnapConfigFontSetting|nil Bold italic font setting for the screenshot (

---SnapConfigFontSettings configuration for font settings
---@class SnapConfigFontSettings
---@field size number Default font size for the screenshot
---@field line_height number Default line height for the screenshot
---@field fonts table<SnapConfigFontSettingsFont, SnapConfigFontSetting> Font settings for different styles

---SnapConfigDebug configuration for debugging the screenshot plugin
---@class SnapConfigDebug
---@field backend SnapConfigBackend Screenshot backend to debug
---@field log_level string Log level for debugging (e.g., "info", "debug", "warn", "error")

---Default configuration for the screenshot plugin
---@class SnapConfig
---@field user_command string Name of the user command to take screenshots, defaults to "Snap"
---@field debug SnapConfigDebug|nil Debug configuration
---@field templateFilepath string|nil Absolute path to a custom HTML template file (optional)
---@field additional_template_data table|nil Table of additional data to pass to the template (optional)
---@field output_dir string|nil Output directory for screenshots (defaults to $HOME/Pictures/Screenshots if nil)
---@field timeout number Timeout for screenshot operations in milliseconds
---@field filename_pattern string Screenshot filename pattern (supports %t for timestamp)
---@field font_settings SnapConfigFontSettings Font settings for the screenshot
return M
