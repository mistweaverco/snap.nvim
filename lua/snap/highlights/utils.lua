local M = {}

---Convert a color number to hex string
---@param color number Color as integer
---@return string Hex color string or nil
function M.convert_color_to_hex(color)
  return string.format("#%06x", color)
end

local DEFAULT_BG = "#000000"
pcall(function()
  local bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
  if bg then
    DEFAULT_BG = M.convert_color_to_hex(bg)
  end
end)

local DEFAULT_FG = "#ffffff"
pcall(function()
  local fg = vim.api.nvim_get_hl(0, { name = "Normal" }).fg
  if fg then
    DEFAULT_FG = M.convert_color_to_hex(fg)
  end
end)

---Get default background color
---@return string Default background color
function M.get_default_bg()
  return DEFAULT_BG
end

---Get default foreground color
---@return string Default foreground color
function M.get_default_fg()
  return DEFAULT_FG
end

---Create a key from highlight attributes for comparison and caching
---@param hl_attrs table|nil Highlight attributes table
---@return string|nil Key string or nil
function M.hl_attrs_to_key(hl_attrs)
  if not hl_attrs then
    return nil
  end
  -- Create a unique key from the highlight attributes
  return string.format(
    "%s|%s|%s|%s|%s",
    hl_attrs.fg or "",
    hl_attrs.bg or "",
    tostring(hl_attrs.bold or false),
    tostring(hl_attrs.italic or false),
    tostring(hl_attrs.underline or false)
  )
end

return M
