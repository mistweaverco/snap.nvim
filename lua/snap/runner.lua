local M = {}
local types = require("snap.types")
local Logger = require("snap.logger")
local Config = require("snap.config")
local Backend = require("snap.backend")

local BACKEND_BIN_PATH = Backend.get_bin_path()

local function html_escape(s)
  s = s:gsub("&", "&amp;")
  s = s:gsub("<", "&lt;")
  s = s:gsub(">", "&gt;")
  s = s:gsub('"', "&quot;")
  return s
end

---Convert a color number to hex string
---@param color number Color as integer
---@return string Hex color string or nil
local function convert_color_to_hex(color)
  return string.format("#%06x", color)
end

local DEFAULT_BG = "#000000"
pcall(function()
  local bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
  if bg then
    DEFAULT_BG = convert_color_to_hex(bg)
  end
end)

local DEFAULT_FG = "#ffffff"
pcall(function()
  local fg = vim.api.nvim_get_hl(0, { name = "Normal" }).fg
  if fg then
    DEFAULT_FG = convert_color_to_hex(fg)
  end
end)

---Get highlight definition by name
---@param name string Highlight group name
---@return table|nil Highlight definition table or nil
---@return string|nil Actual highlight group name used
local function get_hl_by_name(name)
  if not name or name == "" then
    return nil, nil
  end
  local ok, hl
  -- HACK:
  -- we need to prepend "@" to make it a valid tree-sitter highlight group
  -- e.g. "function.builtin" -> "@function.builtin"
  -- but some highlight groups are not prefixed, so we try both
  -- e.g. "Normal", "Comment", etc.
  ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = "@" .. name, link = false })
  if ok and hl then
    -- if hl.link then
    --   return get_hl_by_name(hl.link)
    -- end
    local t = {}
    if hl.fg then
      t.fg = convert_color_to_hex(hl.fg)
    else
      t.fg = DEFAULT_FG
    end
    if hl.bg then
      t.bg = convert_color_to_hex(hl.bg)
    else
      t.bg = DEFAULT_BG
    end
    if hl.bold then
      t.bold = true
    end
    if hl.italic then
      t.italic = true
    end
    if hl.underline then
      t.underline = true
    end
    return t, "@" .. name
  end
  ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if ok and hl then
    -- if hl.link then
    --   return get_hl_by_name(hl.link)
    -- end
    local t = {}
    if hl.fg then
      t.fg = convert_color_to_hex(hl.fg)
    else
      t.fg = DEFAULT_FG
    end
    if hl.bg then
      t.bg = convert_color_to_hex(hl.bg)
    else
      t.bg = DEFAULT_BG
    end
    if hl.bold then
      t.bold = true
    end
    if hl.italic then
      t.italic = true
    end
    if hl.underline then
      t.underline = true
    end
    return t, name
  end
  return nil, nil
end

---Convert highlight definition table to CSS style string
---@param t table|nil Highlight definition table
---@return SnapHighlightStyle|nil style CSS style object
local function hl_table_to_style(t)
  local cls_names = {}
  if not t then
    return nil
  end
  local parts = {}
  if t.fg then
    table.insert(parts, "color:" .. t.fg)
  end
  if t.bg then
    table.insert(parts, "background-color:" .. t.bg)
  end
  if t.bold then
    table.insert(parts, "font-weight:bold")
    table.insert(cls_names, "snap-is-bold")
  end
  if t.italic then
    table.insert(parts, "font-style:italic")
    table.insert(cls_names, "snap-is-italic")
  end
  if t.underline then
    table.insert(parts, "text-decoration:underline")
    table.insert(cls_names, "snap-is-underline")
  end
  return {
    inline_css = table.concat(parts, "; "),
    cls_name = #cls_names > 0 and table.concat(cls_names, " ") or nil,
    hl_table = t,
  }
end

--- Check if a highlight exists in the map for given range
--- @param row number Line number (0-based)
--- @param start_col number Start column (0-based)
--- @param end_col number End column (0-based)
--- @return table|nil Highlight segments or nil
local exists_in_hl_map = function(hl_map, row, start_col, end_col)
  if not hl_map[row] then
    return nil
  end
  local overlapping_segments = {}
  for _, seg in ipairs(hl_map[row]) do
    if not (end_col <= seg.start_col or start_col >= seg.end_col) then
      table.insert(overlapping_segments, seg)
    end
  end
  if #overlapping_segments > 0 then
    return overlapping_segments
  end
  return nil
end

---Build a table mapping line -> column -> highlight group using Tree-sitter
---@param bufnr number Buffer number
---@return table hl_map Highlight map
local function build_hl_map(bufnr)
  local ft = vim.bo[bufnr].filetype
  local parser = vim.treesitter.get_parser(bufnr, ft)
  if not parser then
    return {}
  end
  local tree = parser:parse()[1]
  if not tree then
    return {}
  end

  local query = vim.treesitter.query.get(ft, "highlights")
  if not query then
    return {}
  end

  local hl_map = {}

  for id, node, _ in query:iter_captures(tree:root(), bufnr, 0, -1) do
    -- e.g. "punctuation.bracket", "function.builtin", "operator", "string", etc.
    local hl_group = query.captures[id]
    local start_row, start_col, end_row, end_col = node:range()

    for r = start_row, end_row do
      hl_map[r] = hl_map[r] or {}
      local c_start = (r == start_row) and start_col or 0
      local c_end = (r == end_row) and end_col or math.huge
      table.insert(hl_map[r], { start_col = c_start, end_col = c_end, hl_group = hl_group })
    end
  end

  return hl_map
end

---Get highlight group at specific position
---@param hl_map table Highlight map
---@param row number Line number (0-based)
---@param col number Column number (0-based)
---@return string|nil Highlight group name or nil
local function get_hl_at(hl_map, row, col)
  if not hl_map[row] then
    return nil
  end
  local existing_segments = exists_in_hl_map(hl_map, row, col, col + 1)
  if existing_segments then
    return existing_segments[#existing_segments].hl_group
  end
  return nil
end

---Get default output path for buffer
---@param bufnr number Buffer number
---@return string Output file path
local function default_output_path(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    name = "untitled"
  end
  local fname = vim.fn.fnamemodify(name, ":t")
  return vim.fn.getcwd() .. "/" .. fname .. ".html"
end

local get_absolute_plugin_path = function(...)
  local ps = package.config:sub(1, 1)
  local path = table.concat({ ... }, ps)
  local this_script_dir = debug.getinfo(1, "S").source:sub(2)
  local plugin_root = vim.fn.fnamemodify(this_script_dir, ":h:h")
  return vim.fn.fnamemodify(plugin_root .. ps .. ".." .. ps .. path, ":p")
end

---Export buffer to HTML file with syntax highlighting
---@param opts SnapExportOptions|nil Export options
---@return SnapPayload JSON payload for backend
local function export_buf_to_html(opts)
  opts = opts or {}

  local user_config = Config.get()
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = opts.filepath or default_output_path(bufnr)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local hl_map = build_hl_map(bufnr)
  local hl_style_cache = {}

  --- @type SnapPayload
  local snap_payload = {
    success = true,
    debug = user_config.debug and true or false,
    data = {
      additional_template_data = user_config.additional_template_data or {},
      code = {},
      theme = {
        bgColor = DEFAULT_BG,
        fgColor = DEFAULT_FG,
      },
      filepath = filepath,
      fontSettings = user_config.font_settings or Config.defaults.font_settings,
      outputImageFormat = types.SnapImageOutputFormat.png,
      templateFilepath = user_config.templateFilepath or nil,
      transparent = true,
      type = opts.type or types.SnapPayloadType.html,
    },
  }

  for row, line in pairs(lines) do
    local out_line = {}
    local col = 0
    local current_hl = nil
    local current_resolved_hl = nil
    local current_segment = ""
    while col < #line do
      local ch = line:sub(col + 1, col + 1)
      local hl_group = get_hl_at(hl_map, row - 1, col)
      if hl_group ~= current_hl then
        if current_segment ~= "" then
          ---@type SnapHighlightStyle|nil
          local style = nil
          if current_hl then
            style = hl_style_cache[current_hl]
            if not style then
              local hldef
              hldef, current_resolved_hl = get_hl_by_name(current_hl)
              style = hl_table_to_style(hldef)
              hl_style_cache[current_hl] = style
            end
          end
          if style then
            table.insert(
              out_line,
              string.format(
                '<span data-hlgroup="%s" style="%s" class="%s">%s</span>',
                current_resolved_hl or "default",
                style.inline_css,
                style.cls_name,
                html_escape(current_segment)
              )
            )
          else
            table.insert(out_line, html_escape(current_segment))
          end
        end
        current_segment = ch
        current_hl = hl_group
      else
        current_segment = current_segment .. ch
      end
      col = col + 1
    end
    if current_segment ~= "" then
      ---@type SnapHighlightStyle|nil
      local style = nil
      if current_hl then
        style = hl_style_cache[current_hl]
        if not style then
          local hldef
          hldef, current_resolved_hl = get_hl_by_name(current_hl)
          style = hl_table_to_style(hldef)
          hl_style_cache[current_hl] = style
        end
      end
      if style then
        table.insert(
          out_line,
          string.format(
            '<span data-hlgroup="%s" style="%s" class="%s">%s</span>',
            current_resolved_hl or "default",
            style.inline_css,
            style.cls_name,
            html_escape(current_segment)
          )
        )
      else
        table.insert(out_line, html_escape(current_segment))
      end
    end
    -- table.insert(snap_payload.data.code, table.concat(out_line, ""))
    if opts.range then
      if row >= opts.range.start_line and row <= opts.range.end_line then
        table.insert(snap_payload.data.code, table.concat(out_line, ""))
      end
    else
      table.insert(snap_payload.data.code, table.concat(out_line, ""))
    end
  end
  return snap_payload
end

---Export current buffer to HTML
---@param opts SnapExportOptions|nil Export options
M.html_to_clipboard = function(opts)
  opts = opts or {}
  Backend.ensure_installed(Config.get().debug)
  local jsonPayload = vim.fn.json_encode(export_buf_to_html({
    range = opts.range,
    type = types.SnapPayloadType.html,
  }))
  local conf = Config.get()
  local system_args = nil

  local cwd = nil

  if conf.debug ~= nil then
    cwd = get_absolute_plugin_path("backend", conf.debug.backend)
    if not vim.fn.isdirectory(cwd) then
      error("Backend directory not found: " .. cwd)
    end
    -- Try to find backend bin in PATH
    local backend_bin_path = vim.fn.exepath(conf.debug.backend)
    if backend_bin_path == "" then
      error(conf.debug.backend .. " executable not found in PATH")
    else
      system_args = { backend_bin_path, "run", "." }
    end
  else
    system_args = { BACKEND_BIN_PATH }
  end

  local system_obj = vim.system(
    system_args,
    {
      timeout = conf.timeout,
      stdin = true,
      cwd = cwd,
      env = vim.fn.environ(),
      text = true,
    },
    vim.schedule_wrap(function(result)
      if result.stdout and result.stdout ~= "" then
        local ok, res = pcall(vim.fn.json_decode, result.stdout)
        if not ok then
          Logger.warn("Failed to decode JSON output: " .. tostring(res))
          return
        end
        if res.success then
          Logger.info("Exported HTML to: " .. tostring(res.data.filepath))
        else
          print("Backend error when exporting HTML failed: " .. vim.inspect(res))
        end
      end
      if result.stderr and result.stderr ~= "" then
        print("Error exporting HTML: " .. vim.inspect(result.stderr))
      end
      if result.code ~= 0 then
        print("Process exited with non-zero code: " .. tostring(result.code))
      end
    end)
  )

  -- Write JSON payload to stdin
  system_obj:write(jsonPayload)
  -- Close stdin to signal end of input
  system_obj:write(nil)
end

---Get default save path for screenshots
---@return string|nil Default save path or nil
M.get_default_save_path = function()
  local home = vim.fn.expand("~")
  local screenshots_dir = home .. "/Pictures/Screenshots"
  if vim.fn.isdirectory(screenshots_dir) == 1 then
    return screenshots_dir
  end
  local conf = Config.get()
  local filepath = conf.output_dir and vim.fn.fnamemodify(conf.output_dir, ":p") or nil
  if filepath and vim.fn.isdirectory(filepath) == 1 then
    return filepath
  end
  return nil
end

---Export current buffer to HTML using backend
---@param range SnapVisualRange|nil Visual range (optional)
M.image_to_clipboard = function(range)
  Backend.ensure_installed(Config.get().debug)
  local conf = Config.get()
  local save_path = M.get_default_save_path()
  local filename = conf.filename_pattern and conf.filename_pattern:gsub("%%t", os.date("%Y%m%d_%H%M%S")) or nil
  local jsonPayload = vim.fn.json_encode(export_buf_to_html({
    filepath = save_path and filename and (save_path .. "/" .. filename) or nil,
    range = range,
    type = types.SnapPayloadType.image,
  }))
  local system_args = nil

  local cwd = nil

  if conf.debug ~= nil then
    cwd = get_absolute_plugin_path("backend", conf.debug.backend)
    if not vim.fn.isdirectory(cwd) then
      error("Backend directory not found: " .. cwd)
    end
    -- Try to find backend bin in PATH
    local backend_bin_path = vim.fn.exepath(conf.debug.backend)
    if backend_bin_path == "" then
      error(conf.debug.backend .. " executable not found in PATH")
    else
      system_args = { backend_bin_path, "run", "." }
    end
  else
    system_args = { BACKEND_BIN_PATH }
  end

  local system_obj = vim.system(
    system_args,
    {
      timeout = conf.timeout,
      stdin = true,
      cwd = cwd,
      env = vim.fn.environ(),
      text = true,
    },
    vim.schedule_wrap(function(result)
      if result.stdout and result.stdout ~= "" then
        local ok, res = pcall(vim.fn.json_decode, result.stdout)
        if not ok then
          Logger.warn("Failed to decode JSON output: " .. tostring(res))
          return
        end
        if res.success then
          Logger.info("Exported image to: " .. tostring(res.data.filepath))
        else
          print("Backend error when exporting image: " .. vim.inspect(res))
        end
      end
      if result.stderr and result.stderr ~= "" then
        print("Error exporting image: " .. vim.inspect(result.stderr))
      end
      if result.code ~= 0 then
        print("Process exited with non-zero code: " .. tostring(result.code))
      end
    end)
  )

  -- Write JSON payload to stdin
  system_obj:write(jsonPayload)
  -- Close stdin to signal end of input
  system_obj:write(nil)
end

---Run the screenshot process
---@param range SnapRunOptions|nil Options for running the screenshot
M.run = function(opts)
  opts = opts or {}
  local range = opts.range
  local type = opts.type or types.SnapPayloadType.image
  -- If range is provided from command (visual mode), use it
  if range then
    if type == types.SnapPayloadType.image then
      M.image_to_clipboard(range)
    else
      M.html_to_clipboard(range)
    end
    return
  end
  -- Otherwise, get all content
  Logger.info("No range provided, get all content")

  if type == types.SnapPayloadType.image then
    M.image_to_clipboard()
  else
    M.html_to_clipboard()
  end
end

return M
