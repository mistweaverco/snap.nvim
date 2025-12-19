local M = {}
local types = require("snap.types")
local Logger = require("snap.logger")
local Config = require("snap.config")
local Backend = require("snap.backend")
local UIBlock = require("snap.ui.block")

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

---Get highlight definition by name, resolving links
---@param name string Highlight group name
---@return table|nil Highlight definition table or nil
---@return string|nil Actual highlight group name used
local function get_hl_by_name(name)
  if not name or name == "" then
    return nil, nil
  end

  ---Helper to extract highlight properties from hl definition
  ---@param hl table Highlight definition from nvim_get_hl
  ---@return table Normalized highlight table
  local function extract_hl_props(hl)
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
    return t
  end

  local ok, hl

  -- If the name already starts with "@" (e.g. @lsp.type.variable from semantic tokens),
  -- try it directly first. nvim_get_hl with link=false resolves link chains automatically.
  if name:sub(1, 1) == "@" then
    ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    if ok and hl and next(hl) then
      return extract_hl_props(hl), name
    end
  end

  -- HACK:
  -- we need to prepend "@" to make it a valid tree-sitter highlight group
  -- e.g. "function.builtin" -> "@function.builtin"
  -- but some highlight groups are not prefixed, so we try both
  -- e.g. "Normal", "Comment", etc.
  if name:sub(1, 1) ~= "@" then
    ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = "@" .. name, link = false })
    if ok and hl and next(hl) then
      return extract_hl_props(hl), "@" .. name
    end
  end

  ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if ok and hl and next(hl) then
    return extract_hl_props(hl), name
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

---Build a table mapping line -> column -> highlight group using syntax highlighting (fallback)
---@param bufnr number Buffer number
---@return table hl_map Highlight map
local function build_hl_map_fallback(bufnr)
  local hl_map = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for row_idx, line in ipairs(lines) do
    local row = row_idx - 1 -- Convert to 0-based
    hl_map[row] = {}

    -- Skip empty lines
    if #line > 0 then
      local current_hl = nil
      local segment_start = 0

      for col = 0, #line - 1 do
        -- Get syntax ID at this position and resolve to actual highlight group
        local syn_id = vim.fn.synID(row + 1, col + 1, 1) -- synID uses 1-based indexing
        local trans_id = vim.fn.synIDtrans(syn_id) -- Get resolved highlight group (follows links)
        local hl_name = vim.fn.synIDattr(trans_id, "name")

        -- Normalize empty highlight names to "Normal"
        if hl_name == "" or hl_name == nil then
          hl_name = "Normal"
        end

        if hl_name ~= current_hl then
          -- Save previous segment if it exists
          if current_hl and segment_start < col then
            table.insert(hl_map[row], {
              start_col = segment_start,
              end_col = col,
              hl_group = current_hl,
            })
          end
          current_hl = hl_name
          segment_start = col
        end
      end

      -- Save the last segment
      if current_hl and segment_start < #line then
        table.insert(hl_map[row], {
          start_col = segment_start,
          end_col = #line,
          hl_group = current_hl,
        })
      end
    end
  end

  return hl_map
end

---Build a table mapping line -> column -> highlight group using Tree-sitter
---@param bufnr number Buffer number
---@return table hl_map Highlight map
local function build_hl_map_treesitter(bufnr)
  -- Check if treesitter is available
  local ok, parser = pcall(function()
    local ft = vim.bo[bufnr].filetype
    return vim.treesitter.get_parser(bufnr, ft)
  end)

  if not ok or not parser then
    -- Treesitter not available, use fallback
    return build_hl_map_fallback(bufnr)
  end

  local tree = parser:parse()[1]
  if not tree then
    -- Tree parsing failed, use fallback
    return build_hl_map_fallback(bufnr)
  end

  local ft = vim.bo[bufnr].filetype
  local query = vim.treesitter.query.get(ft, "highlights")
  if not query then
    -- Query not available, use fallback
    return build_hl_map_fallback(bufnr)
  end

  local hl_map = {}

  -- Use pcall to safely iterate captures
  local capture_ok, _ = pcall(function()
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
  end)

  if not capture_ok then
    -- Capture iteration failed, use fallback
    return build_hl_map_fallback(bufnr)
  end

  return hl_map
end

---Build a table mapping line -> column -> highlight group
---Uses Tree-sitter with syntax highlighting fallback
---Note: Semantic tokens are resolved at lookup time via get_hl_at for accuracy
---@param bufnr number Buffer number
---@return table hl_map Highlight map
local function build_hl_map(bufnr)
  return build_hl_map_treesitter(bufnr)
end

---Extract semantic token highlight from vim.inspect_pos result
---Semantic tokens can be in extmarks (with ns matching "semantic_tokens") or in semantic_tokens field
---Returns the highest priority semantic token highlight
---Note: In Neovim, lower priority values have higher precedence (priority 0 > priority 100)
---@param info table Result from vim.inspect_pos
---@return string|nil Highlight group name or nil
local function extract_semantic_hl(info)
  if not info then
    return nil
  end

  local best_hl = nil
  local best_priority = math.huge

  -- Check extmarks for semantic tokens (namespace contains "semantic_tokens")
  if info.extmarks then
    for _, extmark in ipairs(info.extmarks) do
      local ns = extmark.ns or ""
      if ns:match("semantic_tokens") then
        local hl = extmark.opts and extmark.opts.hl_group
        local priority = (extmark.opts and extmark.opts.priority) or 0

        -- Lower priority values have higher precedence in Neovim
        if hl and priority < best_priority then
          best_hl = hl
          best_priority = priority
        end
      end
    end
  end

  -- Also check semantic_tokens field (older Neovim versions or different structure)
  if info.semantic_tokens then
    for _, token in ipairs(info.semantic_tokens) do
      local hl = token.hl_group or (token.opts and token.opts.hl_group)
      local priority = token.priority or (token.opts and token.opts.priority) or 0

      -- Lower priority values have higher precedence in Neovim
      if hl and priority < best_priority then
        best_hl = hl
        best_priority = priority
      end
    end
  end

  return best_hl
end

---Extract treesitter capture from vim.inspect_pos result
---Note: The first element has the highest priority (lowest priority value)
---@param info table Result from vim.inspect_pos
---@return string|nil Highlight group name or nil
local function extract_treesitter_hl(info)
  if info and info.treesitter and #info.treesitter > 0 then
    -- Get the last (highest priority) treesitter capture
    -- In Neovim, Treesitter arrays are ordered by priority with lowest priority value first
    -- This is in contrast to the LSP semantic tokens where usually lower index = higher priority
    local captures = info.treesitter
    local hl_group = captures[#captures].hl_group
    if hl_group then
      return hl_group
    end
  end
  return nil
end

-- TODO: Optimize scrolling
-- Check for visual selection to avoid unnecessary scrolling
-- Show loading indicator during scrolling
-- Check if it is possible to prevent user-interaction during automated scrolling

---Scroll view to specific position temporarily
---@param row number Line number (0-based)
---@param col number Column number (0-based)
---@return nil
local scroll_into_view = function(winnr, row, col)
  local nvim_cursor = vim.api.nvim_win_get_cursor(winnr)
  local height = vim.api.nvim_win_get_height(winnr)
  -- check if already in view via cursor position,
  -- if in view, no need to scroll
  if row >= (nvim_cursor[1] - 1) and row < (nvim_cursor[1] - 1 + height) then
    return
  end
  -- scroll so that row is the top most line
  vim.api.nvim_win_set_cursor(winnr, { row + 1, col })
  vim.cmd("redraw")
end

---Scroll back if at last row of the view
---@param winnr number Window number
---@param row number Line number (0-based)
---@param view vim.fn.winsaveview.ret View state to restore later
local restore_view = function(winnr, row, view)
  local rows = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(winnr))
  if row >= (rows - 1) then
    vim.fn.winrestview(view)
  end
end

---Get highlight group at specific position using vim.inspect_pos
---This reliably gets all highlights including extmarks, semantic tokens, treesitter, and syntax
---Priority: extmarks > semantic_tokens > treesitter > syntax
---Because certain highlights (like semantic tokens) are only rendered when in view,
---we pass in the cursor position to jump back after inspection
---This will scroll the view temporarily
---@param winnr number Window number
---@param bufnr number Buffer number
---@param row number Line number (0-based)
---@param col number Column number (0-based byte offset)
---@param view vim.fn.winsaveview.ret View state to restore later
---@return string|nil Highlight group name or nil
local function get_hl_at_pos(winnr, bufnr, row, col, view)
  scroll_into_view(winnr, row, col)

  local ok, info = pcall(vim.inspect_pos, bufnr, row, col)
  if not ok or not info then
    return nil
  end

  -- Priority 1: Extmarks with highlights (highest precedence)
  if info.extmarks and #info.extmarks > 0 then
    for i = #info.extmarks, 1, -1 do
      local extmark = info.extmarks[i]
      if extmark.opts and extmark.opts.hl_group then
        restore_view(winnr, row, view)
        return extmark.opts.hl_group
      end
    end
  end

  -- Priority 2: Semantic tokens
  local semantic_hl = extract_semantic_hl(info)
  if semantic_hl then
    restore_view(winnr, row, view)
    return semantic_hl
  end

  -- Priority 3: Treesitter captures
  local treesitter_hl = extract_treesitter_hl(info)
  if treesitter_hl then
    restore_view(winnr, row, view)
    return treesitter_hl
  end

  -- Priority 4: Syntax highlighting
  if info.syntax and #info.syntax > 0 then
    local syn = info.syntax[#info.syntax]
    if syn.hl_group then
      restore_view(winnr, row, view)
      return syn.hl_group
    end
  end

  restore_view(winnr, row, view)
  return nil
end

---Get highlight group at specific position
---Uses vim.inspect_pos for accurate results including semantic tokens
---Falls back to hl_map lookup if vim.inspect_pos is not available
---@param winr number Window number
---@param hl_map table Highlight map (used as fallback)
---@param bufnr number Buffer number
---@param row number Line number (0-based)
---@param col number Column number (0-based byte offset)
---@param view vim.fn.winsaveview.ret View state to restore later
---@return string|nil Highlight group name or nil
local function get_hl_at(winr, hl_map, bufnr, row, col, view)
  if vim.inspect_pos then
    local hl = get_hl_at_pos(winr, bufnr, row, col, view)
    if hl then
      return hl
    end
  end

  -- Fallback to hl_map lookup
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
  -- Save current view to restore later
  local view = vim.fn.winsaveview()

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
      template = user_config.template or "default",
      toClipboard = true,
      filepath = filepath,
      fontSettings = user_config.font_settings or Config.defaults.font_settings,
      outputImageFormat = types.SnapImageOutputFormat.png,
      templateFilepath = user_config.templateFilepath or nil,
      transparent = true,
      minWidth = 0,
      type = opts.type or types.SnapPayloadType.html,
    },
  }

  -- Calculate the longest line length (in characters) for min width calculation
  local longest_line_len = 0
  for _, line in ipairs(lines) do
    if #line > longest_line_len then
      longest_line_len = #line
    end
  end

  -- Calculate minimum width in pixels
  -- Monospace character width is approximately 0.6 * font_size
  -- Add padding (15px * 2 = 30px from template)
  local font_size = snap_payload.data.fontSettings.size or 14
  local char_width_factor = 0.6
  local padding = 30
  snap_payload.data.minWidth = math.ceil(longest_line_len * font_size * char_width_factor) + padding
  local win = vim.api.nvim_get_current_win()
  local ui_block_releaser = UIBlock.show_loading_locked("Fetching highlights...")

  for row, line in ipairs(lines) do
    local out_line = {}
    local col = 0
    local current_hl = nil
    local current_segment = ""
    while col < #line do
      local ch = line:sub(col + 1, col + 1)
      local hl_group = get_hl_at(win, hl_map, bufnr, row - 1, col, view)
      if hl_group ~= current_hl then
        if current_segment ~= "" then
          ---@type SnapHighlightStyle|nil
          local style = nil
          local resolved_hl = nil
          if current_hl then
            local cached = hl_style_cache[current_hl]
            if cached then
              style = cached.style
              resolved_hl = cached.resolved_hl
            else
              local hldef
              hldef, resolved_hl = get_hl_by_name(current_hl)
              style = hl_table_to_style(hldef)
              hl_style_cache[current_hl] = { style = style, resolved_hl = resolved_hl }
            end
          end
          if style then
            table.insert(
              out_line,
              string.format(
                '<span data-hlgroup="%s" style="%s" class="%s">%s</span>',
                resolved_hl or current_hl or "default",
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
      local resolved_hl = nil
      if current_hl then
        local cached = hl_style_cache[current_hl]
        if cached then
          style = cached.style
          resolved_hl = cached.resolved_hl
        else
          local hldef
          hldef, resolved_hl = get_hl_by_name(current_hl)
          style = hl_table_to_style(hldef)
          hl_style_cache[current_hl] = { style = style, resolved_hl = resolved_hl }
        end
      end
      if style then
        table.insert(
          out_line,
          string.format(
            '<span data-hlgroup="%s" style="%s" class="%s">%s</span>',
            resolved_hl or current_hl or "default",
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
  ui_block_releaser()
  return snap_payload
end

---Export current buffer to HTML
---@param opts SnapExportOptions|nil Export options
M.html_to_clipboard = function(opts)
  opts = opts or {}
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
---@param opts SnapExportOptions|nil Export options
M.image_to_clipboard = function(opts)
  opts = opts or {}
  local user_config = Config.get()
  local save_path = M.get_default_save_path()
  if not save_path then
    Logger.error("No valid save path found for screenshots. Please set 'output_dir' in config")
    return
  end
  local filename = user_config.filename_pattern
      and (user_config.filename_pattern:gsub("%%t", os.date("%Y%m%d_%H%M%S")) or user_config.filename_pattern)
    or nil
  if not filename then
    Logger.error("Filename pattern is not set correctly.")
    return
  end
  local filepath = save_path and filename and (save_path .. "/" .. filename .. ".png") or ""
  local jsonPayload = vim.fn.json_encode(export_buf_to_html({
    filepath = filepath,
    range = opts.range,
    type = types.SnapPayloadType.image,
  }))
  local system_args = nil

  local cwd = nil

  if user_config.debug ~= nil and user_config.debug.backend ~= nil then
    cwd = get_absolute_plugin_path("backend", user_config.debug.backend)
    if not vim.fn.isdirectory(cwd) then
      error("Backend directory not found: " .. cwd)
    end
    -- Try to find backend bin in PATH
    local backend_bin_path = vim.fn.exepath(user_config.debug.backend)
    if backend_bin_path == "" then
      error(user_config.debug.backend .. " executable not found in PATH")
    else
      system_args = { backend_bin_path, "run", "." }
    end
  else
    system_args = { BACKEND_BIN_PATH }
  end

  local system_obj = vim.system(
    system_args,
    {
      timeout = user_config.timeout,
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
---@param opts SnapRunOptions|nil Options for running the screenshot
M.run = function(opts)
  opts = opts or {}
  Backend.ensure_installed(function()
    -- If range is provided from command (visual mode), use it
    if opts.range then
      if opts.type == types.SnapPayloadType.image then
        M.image_to_clipboard({ range = opts.range })
      else
        M.html_to_clipboard({ range = opts.range })
      end
      return
    end
    if opts.type == types.SnapPayloadType.image then
      M.image_to_clipboard()
    else
      M.html_to_clipboard()
    end
  end)
end

return M
