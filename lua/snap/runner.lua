local M = {}
local Logger = require("snap.logger")
local Config = require("snap.config")
local Backend = require("snap.backend")

local BACKEND_BIN_PATH = Backend.get_bin_path()

---Calculate optimal size based on content
---@param content_lines table Array of content lines
---@param show_number boolean Whether line numbers are shown
---@return number width width in characters
---@return number height height in characters
local function calculate_size(content_lines, show_number)
  -- Calculate max line length
  local max_line_len = 0
  for _, line in ipairs(content_lines) do
    -- Count display width (handles tabs as spaces)
    local display_len = vim.fn.strdisplaywidth(line)
    if display_len > max_line_len then
      max_line_len = display_len
    end
  end

  -- Calculate width needed
  local line_count = #content_lines
  local line_number_width = show_number and math.max(4, math.floor(math.log10(line_count)) + 1) or 0
  local width = max_line_len + line_number_width + 4 -- +4 for margins/padding
  -- Ensure minimum width
  width = math.max(40, width)
  -- Round up to reasonable size
  width = math.min(120, math.ceil(width / 10) * 10)

  -- Calculate height needed
  local height = line_count + 4 -- +4 for status line and padding
  -- Ensure minimum height
  height = math.max(10, height)
  -- Round up slightly
  height = math.ceil(height / 2) * 2

  return width, height
end

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
  ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = "@" .. name })
  if ok and hl and not hl.link then
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
  ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name })
  if ok and hl and not hl.link then
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
---@return string CSS style string
local function hl_table_to_style(t)
  if not t then
    return ""
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
  end
  if t.italic then
    table.insert(parts, "font-style:italic")
  end
  if t.underline then
    table.insert(parts, "text-decoration:underline")
  end
  return table.concat(parts, "; ")
end

--- Check if a highlight exists in the map for given range
--- @param row number Line number (0-based)
--- @param start_col number Start column (0-based)
--- @param end_col number End column (0-based)
--- @return number|nil Index of existing highlight segment or nil
local exists_in_hl_map = function(hl_map, row, start_col, end_col)
  if not hl_map[row] then
    return nil
  end
  for idx, seg in ipairs(hl_map[row]) do
    if not (end_col <= seg.start_col or start_col >= seg.end_col) then
      return idx
    end
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

  -- higher priority captures later
  for id, node, _ in query:iter_captures(tree:root(), bufnr, 0, -1) do
    -- e.g. "punctuation.bracket", "function.builtin", "operator", "string", etc.
    local hl_group = query.captures[id]
    local start_row, start_col, end_row, end_col = node:range()

    for r = start_row, end_row do
      hl_map[r] = hl_map[r] or {}
      local c_start = (r == start_row) and start_col or 0
      local c_end = (r == end_row) and end_col or math.huge
      local existing_idx = exists_in_hl_map(hl_map, r, c_start, c_end)
      if existing_idx then
        hl_map[r][existing_idx] = { start_col = c_start, end_col = c_end, hl_group = hl_group }
      else
        table.insert(hl_map[r], { start_col = c_start, end_col = c_end, hl_group = hl_group })
      end
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
  local exists = exists_in_hl_map(hl_map, row, col, col + 1)
  if exists then
    return hl_map[row][exists].hl_group
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
---@param opts table|nil Options
---@param export_type string|nil Export type ("html" or "image")
local function export_buf_to_html(opts, export_type)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local filepath = opts.filepath or default_output_path(bufnr)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local hl_map = build_hl_map(bufnr)
  local hl_style_cache = {}

  local out_data = {
    success = true,
    data = {
      type = export_type or "html",
      code = "",
      filepath = filepath,
      outputImageFormat = "png",
      outputImageHeight = -1,
      outputImageWidth = -1,
      transparent = true,
    },
  }
  out_data.data.codeContainerCSS = "background-color:"
    .. DEFAULT_BG
    .. ";color:"
    .. DEFAULT_FG
    .. ";font-color:"
    .. DEFAULT_FG
    .. ";"

  for row, line in ipairs(lines) do
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
                '<span data-hlgroup="%s" style="%s">%s</span>',
                current_resolved_hl or "undefined",
                style,
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
            '<span data-hlgroup="%s" style="%s">%s</span>',
            current_resolved_hl or "undefined",
            style,
            html_escape(current_segment)
          )
        )
      else
        table.insert(out_line, html_escape(current_segment))
      end
    end
    out_data.data.code = table.concat(out_line)
  end
  return vim.fn.json_encode(out_data)
end

---Export current buffer to HTML
M.html_to_clipboard = function()
  Backend.ensure_installed(Config.get().debug)
  local jsonPayload = export_buf_to_html(nil, "html")
  local conf = Config.get()
  local backend_dir
  local system_args = nil

  if conf.backend ~= "bun" and conf.backend ~= "node" then
    error("Unsupported backend: " .. tostring(conf.backend))
  else
    backend_dir = "nodejs"
  end

  local cwd = get_absolute_plugin_path("backend", backend_dir)
  if not vim.fn.isdirectory(cwd) then
    error("Backend directory not found: " .. cwd)
  end

  -- Try to find backend bin in PATH
  local backend_bin_path = vim.fn.exepath(conf.backend)
  if backend_bin_path == "" then
    error(conf.backend .. " executable not found in PATH")
  else
    system_args = { backend_bin_path, "run", "." }
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
          print("Export HTML failed: " .. vim.inspect(res))
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
M.image_to_clipboard = function()
  Backend.ensure_installed(Config.get().debug)
  local conf = Config.get()
  local save_path = M.get_default_save_path()
  local filename = conf.filename_pattern and conf.filename_pattern:gsub("%%t", os.date("%Y%m%d_%H%M%S")) or nil
  local opts = {
    filepath = save_path and filename and (save_path .. "/" .. filename) or nil,
  }
  local jsonPayload = export_buf_to_html(opts, "image")
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
          print("Export HTML failed: " .. vim.inspect(res))
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

vim.api.nvim_create_user_command("SnapHTML", function()
  local ok, path_or_err = pcall(M.html_to_clipboard)
  if not ok then
    vim.notify("SnapHTML failed", vim.log.levels.ERROR)
    print("SnapHTML failed: \n\n" .. tostring(path_or_err))
    return
  end
end, { nargs = "?" })

vim.api.nvim_create_user_command("SnapImage", function()
  local ok, path_or_err = pcall(M.image_to_clipboard)
  if not ok then
    vim.notify("SnapImage failed", vim.log.levels.ERROR)
    print("SnapImage failed: \n\n" .. tostring(path_or_err))
    return
  end
end, { nargs = "?", complete = "file" })

---Get the visual selection or entire buffer content
---@return string content
---@return number start_line
---@return number end_line
---@return boolean has_selection
local function get_content()
  local start_line, end_line
  local content = {}
  local has_selection = false
  local current_buf = vim.api.nvim_get_current_buf()

  -- First, try to get visual selection using marks
  -- These marks are set when leaving visual mode
  -- Use vim.fn.line() which is simpler and more reliable
  local mark_start = vim.fn.line("'<")
  local mark_end = vim.fn.line("'>")

  -- Check if marks exist (non-zero means they exist)
  if mark_start > 0 and mark_end > 0 then
    -- Verify marks are valid for current buffer
    local buf_line_count = vim.api.nvim_buf_line_count(0)
    if mark_start <= buf_line_count and mark_end <= buf_line_count then
      start_line = math.min(mark_start, mark_end)
      end_line = math.max(mark_start, mark_end)
      has_selection = true
    end
  end

  -- If no selection found via marks, check if we're currently in visual mode
  if not has_selection then
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "\22" then
      -- Currently in visual mode - get selection directly
      local start_pos = vim.fn.getpos("v")
      local end_pos = vim.fn.getpos(".")
      start_line = math.min(start_pos[2], end_pos[2])
      end_line = math.max(start_pos[2], end_pos[2])
      has_selection = true
    end
  end

  if has_selection then
    -- Get the selected lines (end_line is inclusive)
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    content = lines
  else
    -- No selection, get entire buffer
    local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    content = buf_lines
    start_line = 1
    end_line = #buf_lines
  end

  return table.concat(content, "\n"), start_line, end_line, has_selection
end

---Run the screenshot process
---@param range_start number|nil Start line from command range
---@param range_end number|nil End line from command range
M.run = function(range_start, range_end)
  local start_line, end_line, has_selection
  local content = {}

  -- If range is provided from command (visual mode), use it
  if range_start and range_end and range_start > 0 and range_end > 0 then
    start_line = math.min(range_start, range_end)
    end_line = math.max(range_start, range_end)
    has_selection = true
    -- Get the selected lines (end_line is inclusive in nvim_buf_get_lines)
    content = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    Logger.info(string.format("Extracted %d lines from buffer (lines %d-%d)", #content, start_line, end_line))
  else
    -- Otherwise, try to detect visual selection
    Logger.info("No range provided, trying to detect visual selection...")
    local content_result, start, end_line_num, has_sel = get_content()
    start_line = start
    end_line = end_line_num
    has_selection = has_sel
    content = vim.split(content_result, "\n")
  end

  -- Convert content array to string
  local content_str = table.concat(content, "\n")
  if not content_str or content_str == "" then
    Logger.warn("No content to capture")
    return
  end

  -- Debug: log what we're capturing
  if has_selection then
    Logger.info(
      string.format("Capturing selected lines %d-%d (%d lines, %d chars)", start_line, end_line, #content, #content_str)
    )
  else
    Logger.info(string.format("Capturing full buffer (%d lines, %d chars)", #content, #content_str))
  end
end

return M
