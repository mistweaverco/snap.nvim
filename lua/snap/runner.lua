local M = {}
local types = require("snap.types")
local Logger = require("snap.logger")
local Config = require("snap.config")
local Backend = require("snap.backend")
local UIBlock = require("snap.ui.block")

local BACKEND_BIN_PATH = Backend.get_bin_path()

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

---Get raw highlight definition by name (without defaults), resolving links
---@param name string Highlight group name
---@return table|nil Raw highlight definition table (only includes attributes that are set) or nil
---@return string|nil Actual highlight group name used
local function get_raw_hl_by_name(name)
  if not name or name == "" then
    return nil, nil
  end

  local ok, hl

  -- If the name already starts with "@" (e.g. @lsp.type.variable from semantic tokens),
  -- try it directly first. nvim_get_hl with link=false resolves link chains automatically.
  if name:sub(1, 1) == "@" then
    ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    if ok and hl and next(hl) then
      return hl, name
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
      return hl, "@" .. name
    end
  end

  ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if ok and hl and next(hl) then
    return hl, name
  end

  return nil, nil
end

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
---@param text string Text content (for future use)
---@return SnapPayloadDataCodeItem|nil Highlight style or nil
local function get_snap_payload_data_code_item(t, text)
  if not t then
    return nil
  end
  return {
    fg = t.fg or DEFAULT_FG,
    bg = t.bg or DEFAULT_BG,
    text = text,
    bold = t.bold or false,
    italic = t.italic or false,
    underline = t.underline or false,
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
---Note: In Neovim, higher priority values have higher precedence (priority 200 > priority 100)
---@param info table Result from vim.inspect_pos
---@return string|nil Highlight group name or nil
local function extract_semantic_hl(info)
  if not info then
    return nil
  end

  local best_hl = nil
  local best_priority = 0

  -- Check extmarks for semantic tokens (namespace contains "semantic_tokens")
  if info.extmarks then
    for _, extmark in ipairs(info.extmarks) do
      local ns = extmark.ns or ""
      if ns:match("semantic_tokens") then
        local hl = extmark.opts and extmark.opts.hl_group
        local priority = (extmark.opts and extmark.opts.priority) or 0

        -- Higher priority values have higher precedence in Neovim
        if hl and priority > best_priority then
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

      -- Higher priority values have higher precedence in Neovim
      if hl and priority > best_priority then
        best_hl = hl
        best_priority = priority
      end
    end
  end

  return best_hl
end

---Extract all treesitter captures from vim.inspect_pos result
---Treesitter captures are ordered by priority (highest priority value = highest precedence first)
---Each capture has a capture name (like @comment.typescript) that is the highlight group name
---@param info table Result from vim.inspect_pos
---@return table Array of {hl_group = string, priority = number} or empty table
local function extract_treesitter_highlights(info)
  local treesitter_highlights = {}
  if info and info.treesitter and #info.treesitter > 0 then
    -- Treesitter captures are ordered by priority (highest priority value = highest precedence first)
    -- The structure can be:
    -- 1. Array of strings (capture names like "@comment.typescript")
    -- 2. Array of objects with capture/hl_group fields
    for i, capture in ipairs(info.treesitter) do
      local capture_name = nil
      local priority = 100 -- Treesitter default priority

      if type(capture) == "string" then
        -- Simple case: capture is a string (the capture name)
        capture_name = capture
      elseif type(capture) == "table" then
        -- Object case: extract capture name and priority
        -- Prefer hl_group (the actual highlight group name like "@comment.typescript")
        -- over capture (just the capture name like "comment")
        capture_name = capture.hl_group or capture.capture or capture.name or capture[1]
        priority = capture.priority or 100
      end

      if capture_name and capture_name ~= "" then
        -- Use the capture name directly as the highlight group
        -- get_hl_by_name will handle resolution (including "@" prefix)
        table.insert(treesitter_highlights, { hl_group = capture_name, priority = priority })
      elseif type(capture) == "table" then
        -- Last resort: try to find any string value in the table that looks like a capture name
        for k, v in pairs(capture) do
          if type(v) == "string" and (v:match("^@") or v ~= "") then
            -- Prefer capture names starting with "@", but accept any non-empty string
            if v:match("^@") or not capture_name then
              capture_name = v
            end
          end
        end
        if capture_name and capture_name ~= "" then
          table.insert(treesitter_highlights, { hl_group = capture_name, priority = priority })
        end
      end
    end
  end
  return treesitter_highlights
end

-- TODO: Optimize scrolling
-- Check for visual selection to avoid unnecessary scrolling
-- Show loading indicator during scrolling
-- Check if it is possible to prevent user-interaction during automated scrolling

---Scroll view to specific position temporarily
---@param winnr number Window number
---@param row number Line number (0-based)
---@param col number Column number (0-based)
---@param range SnapVisualRange|nil Range to consider
---@return nil
local scroll_into_view = function(winnr, row, col, range)
  local nvim_cursor = vim.api.nvim_win_get_cursor(winnr)
  local height = vim.api.nvim_win_get_height(winnr)
  -- check if already in view via cursor position,
  -- if in view, no need to scroll
  if row >= (nvim_cursor[1] - 1) and row < (nvim_cursor[1] - 1 + height) then
    vim.cmd("redraw")
    return
  end
  if range then
    -- check if range is already in view
    -- if in view, no need to scroll
    if range.start_line >= (nvim_cursor[1] - 1) and range.end_line < (nvim_cursor[1] - 1 + height) then
      vim.cmd("redraw")
      return
    end
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

---Merge multiple highlight definitions, with higher priority taking precedence
---for each attribute. Attributes from lower priority highlights are preserved if not specified in
---higher priority highlights. When priorities are equal, the last one added (higher index) wins.
---@param highlights table Array of {hl_group = string, priority = number}
---@return table|nil Merged highlight definition table (normalized with defaults) or nil
local function merge_highlights(highlights)
  if not highlights or #highlights == 0 then
    return nil
  end

  -- Add original index to each highlight for tie-breaking
  for i, hl in ipairs(highlights) do
    hl._original_index = i
  end

  -- Sort by priority (higher priority value = higher precedence, comes first)
  -- When priorities are equal, higher original index (last one added) wins
  table.sort(highlights, function(a, b)
    local a_priority = a.priority or 0
    local b_priority = b.priority or 0
    if a_priority ~= b_priority then
      return a_priority > b_priority
    end
    -- Equal priority: last one added (higher index) wins
    return (a._original_index or 0) > (b._original_index or 0)
  end)

  -- Start with the highest priority (highest priority value) highlight as base
  -- Use raw highlight to see which attributes are actually set
  local merged_raw = {}
  local base_raw_hl, _ = get_raw_hl_by_name(highlights[1].hl_group)
  if base_raw_hl then
    -- Copy attributes that are actually set in the raw highlight
    if base_raw_hl.fg ~= nil then
      merged_raw.fg = base_raw_hl.fg
    end
    if base_raw_hl.bg ~= nil then
      merged_raw.bg = base_raw_hl.bg
    end
    if base_raw_hl.bold ~= nil then
      merged_raw.bold = base_raw_hl.bold
    end
    if base_raw_hl.italic ~= nil then
      merged_raw.italic = base_raw_hl.italic
    end
    if base_raw_hl.underline ~= nil then
      merged_raw.underline = base_raw_hl.underline
    end
  end

  -- Merge remaining highlights (lower priority, but may have attributes not in higher priority)
  -- We iterate from highest to lowest priority, so higher priority attributes override lower ones
  for i = 2, #highlights do
    local raw_hl, _ = get_raw_hl_by_name(highlights[i].hl_group)
    if raw_hl then
      -- Fill in missing attributes from lower priority highlights
      -- Only use attributes that are actually set in the raw highlight
      if merged_raw.fg == nil and raw_hl.fg ~= nil then
        merged_raw.fg = raw_hl.fg
      end
      if merged_raw.bg == nil and raw_hl.bg ~= nil then
        merged_raw.bg = raw_hl.bg
      end
      if merged_raw.bold == nil and raw_hl.bold ~= nil then
        merged_raw.bold = raw_hl.bold
      end
      if merged_raw.italic == nil and raw_hl.italic ~= nil then
        merged_raw.italic = raw_hl.italic
      end
      if merged_raw.underline == nil and raw_hl.underline ~= nil then
        merged_raw.underline = raw_hl.underline
      end
    end
  end

  -- Normalize the merged result (convert colors to hex, apply defaults)
  local merged = {}
  -- Store the primary highlight group (highest priority, highest priority value)
  merged.hl_group = highlights[1].hl_group
  if merged_raw.fg then
    merged.fg = convert_color_to_hex(merged_raw.fg)
  else
    merged.fg = DEFAULT_FG
  end
  if merged_raw.bg then
    merged.bg = convert_color_to_hex(merged_raw.bg)
  else
    merged.bg = DEFAULT_BG
  end
  merged.bold = merged_raw.bold or false
  merged.italic = merged_raw.italic or false
  merged.underline = merged_raw.underline or false

  return merged
end

---Collect all highlights at a position, ordered by priority
---We collect in reverse order (syntax -> treesitter -> extmarks) so that extmarks
---(which typically have the highest precedence) are added last and can override others
---@param info table Result from vim.inspect_pos
---@return table Array of {hl_group = string, priority = number} sorted by priority
local function collect_all_highlights(info)
  local highlights = {}

  -- Priority 3: Syntax highlighting (default priority 50) - collect first
  if info.syntax and #info.syntax > 0 then
    local syn = info.syntax[#info.syntax]
    if syn.hl_group then
      -- Syntax default priority is 50
      table.insert(highlights, { hl_group = syn.hl_group, priority = 50 })
    end
  end

  -- Priority 2: Treesitter highlights (default priority 100) - collect second
  -- Treesitter highlights are typically already captured as extmarks with priority 100,
  -- but we check the treesitter field as a fallback for compatibility
  local treesitter_highlights = extract_treesitter_highlights(info)
  for _, ts_hl in ipairs(treesitter_highlights) do
    -- Check if we already have this highlight
    local already_exists = false
    for _, hl in ipairs(highlights) do
      if hl.hl_group == ts_hl.hl_group then
        already_exists = true
        break
      end
    end
    if not already_exists then
      table.insert(highlights, ts_hl)
    end
  end

  -- Priority 1: Extmarks with hl_group/virt_text (explicit priority) - collect LAST
  -- This includes: diagnostics, LSP semantic tokens, treesitter (default priority 100),
  -- plugins (git signs, indent guides, rainbow delimiters, todo-comments, etc.)
  -- Extmarks have the highest precedence and should override treesitter/syntax
  if info.extmarks and #info.extmarks > 0 then
    for _, extmark in ipairs(info.extmarks) do
      -- Check for hl_group in opts first, then directly in extmark
      local hl_group = nil
      if extmark.opts and extmark.opts.hl_group then
        hl_group = extmark.opts.hl_group
      elseif extmark.hl_group then
        hl_group = extmark.hl_group
      end

      if hl_group then
        -- Priority handling for extmarks:
        -- - Treesitter extmarks: use priority 100 (or explicit if set and > 100)
        -- - Other extmarks: should have highest precedence to override treesitter/syntax
        --   Higher priority value = higher precedence
        local ns = tostring(extmark.ns or "")
        local is_treesitter = ns:match("^treesitter") or ns:match("^nvim%-treesitter") or ns == "TS"

        -- Get explicit priority from opts if available
        local extmark_priority = nil
        if extmark.opts and extmark.opts.priority ~= nil then
          extmark_priority = extmark.opts.priority
        elseif extmark.priority ~= nil then
          extmark_priority = extmark.priority
        end

        local priority
        if is_treesitter then
          -- Treesitter extmarks: default to 100, but use explicit if it's higher
          priority = extmark_priority or 100
        else
          -- Non-treesitter extmarks: should override treesitter (100) and syntax (50)
          -- If explicit priority is <= 100 (lower precedence), override to 200 (higher precedence)
          -- If explicit priority is > 100 (higher precedence), use it as-is
          if extmark_priority == nil then
            priority = 200 -- No explicit priority: use high precedence to override treesitter
          elseif extmark_priority <= 100 then
            priority = 200 -- Explicit priority is too low: override to higher precedence
          else
            priority = extmark_priority -- Explicit priority is good (higher): use it
          end
        end

        -- Check if we already have this highlight group
        -- If we do, replace it with the extmark version (higher precedence)
        local found_index = nil
        for i, hl in ipairs(highlights) do
          if hl.hl_group == hl_group then
            found_index = i
            break
          end
        end

        if found_index then
          -- Replace existing highlight with extmark version (higher precedence)
          highlights[found_index] = { hl_group = hl_group, priority = priority }
        else
          -- Add new extmark highlight
          table.insert(highlights, { hl_group = hl_group, priority = priority })
        end
      end
    end
  end

  return highlights
end

---Get merged highlight attributes at specific position using vim.inspect_pos
---This reliably gets all highlights following the correct hierarchy and merges them:
---1. Extmarks with hl_group/virt_text (explicit priority) - includes diagnostics, LSP semantic tokens,
---   treesitter (default priority 100), plugins, etc. Higher priority value = higher precedence.
---2. Syntax highlights (default priority 50)
---3. Fallback/UI highlights (Normal, CursorLine, Visual, etc.)
---Highlights are merged: higher priority highlights override lower priority ones for each attribute,
---but attributes not specified in higher priority highlights are preserved from lower priority ones.
---Because certain highlights (like semantic tokens) are only rendered when in view,
---we pass in the cursor position to jump back after inspection
---This will scroll the view temporarily
---@param winnr number Window number
---@param bufnr number Buffer number
---@param row number Line number (0-based)
---@param col number Column number (0-based byte offset)
---@param view vim.fn.winsaveview.ret View state to restore later
---@param range SnapVisualRange|nil Range to consider
---@return table|nil Merged highlight definition table or nil
local function get_hl_at_pos(winnr, bufnr, row, col, view, range)
  scroll_into_view(winnr, row, col, range)

  local ok, info = pcall(vim.inspect_pos, bufnr, row, col)
  if not ok or not info then
    restore_view(winnr, row, view)
    return nil
  end

  -- Collect all highlights at this position
  local highlights = collect_all_highlights(info)

  -- Merge highlights by priority
  local merged = merge_highlights(highlights)

  restore_view(winnr, row, view)
  return merged
end

---Create a key from highlight attributes for comparison and caching
---@param hl_attrs table|nil Highlight attributes table
---@return string|nil Key string or nil
local function hl_attrs_to_key(hl_attrs)
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

---Get merged highlight attributes at specific position
---Uses vim.inspect_pos for accurate results including semantic tokens
---Falls back to hl_map lookup if vim.inspect_pos is not available
---@param winr number Window number
---@param hl_map table Highlight map (used as fallback)
---@param bufnr number Buffer number
---@param row number Line number (0-based)
---@param col number Column number (0-based byte offset)
---@param view vim.fn.winsaveview.ret View state to restore later
---@param range SnapVisualRange|nil Range to consider
---@return table|nil Merged highlight attributes table or nil
local function get_hl_at(winr, hl_map, bufnr, row, col, view, range)
  if vim.inspect_pos then
    local hl = get_hl_at_pos(winr, bufnr, row, col, view, range)
    if hl then
      return hl
    end
  end

  -- Fallback to hl_map lookup - resolve highlight group to attributes
  if not hl_map[row] then
    return nil
  end
  local existing_segments = exists_in_hl_map(hl_map, row, col, col + 1)
  if existing_segments and #existing_segments > 0 then
    -- Get the highlight group from the segment
    local hl_group = existing_segments[#existing_segments].hl_group
    if hl_group then
      local hldef, resolved_hl = get_hl_by_name(hl_group)
      if hldef then
        -- Include the highlight group name in the result
        hldef.hl_group = resolved_hl or hl_group
        return hldef
      end
    end
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

---Generate backend JSON payload from current buffer
---@param opts SnapExportOptions|nil Export options
---@return SnapPayload JSON payload for backend
local function get_backend_payload_from_buf(opts)
  opts = opts or {}

  local user_config = Config.get()
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = opts.filepath or default_output_path(bufnr)
  -- Save current view to restore later
  local view = vim.fn.winsaveview()

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local hl_map = build_hl_map(bufnr)

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
      type = opts.type or types.SnapPayloadType.image,
    },
  }

  -- Calculate the longest line length (in characters) for min width calculation
  -- based on the selection or entire buffer
  -- This is a rough estimate and may not be accurate for proportional fonts
  local longest_line_len = 0
  for row, line in ipairs(lines) do
    if opts.range then
      if row >= opts.range.start_line and row <= opts.range.end_line then
        if #line > longest_line_len then
          longest_line_len = #line
        end
      end
    else
      if #line > longest_line_len then
        longest_line_len = #line
      end
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
    ---@type table<SnapPayloadDataCodeItem|nil>
    local line_items = {}
    local col = 0
    local current_hl_key = nil
    local current_hl_attrs = nil
    local current_segment = ""
    while col < #line do
      local ch = line:sub(col + 1, col + 1)
      local hl_attrs = get_hl_at(win, hl_map, bufnr, row - 1, col, view, opts.range)
      -- If no highlight attributes, create a default one with "Normal"
      if not hl_attrs then
        hl_attrs = {
          hl_group = "Normal",
          fg = DEFAULT_FG,
          bg = DEFAULT_BG,
          bold = false,
          italic = false,
          underline = false,
        }
      end
      local hl_key = hl_attrs_to_key(hl_attrs)
      if hl_key ~= current_hl_key then
        if current_segment ~= "" then
          ---@type SnapPayloadDataCodeItem|nil
          local snap_payload_data_code_item = nil
          local hl_name = "Normal"
          if current_hl_attrs and current_hl_attrs.hl_group then
            hl_name = current_hl_attrs.hl_group
            snap_payload_data_code_item = get_snap_payload_data_code_item(current_hl_attrs, current_segment)
          end
          if snap_payload_data_code_item then
            table.insert(line_items, {
              fg = snap_payload_data_code_item.fg,
              bg = snap_payload_data_code_item.bg,
              text = current_segment,
              bold = snap_payload_data_code_item.bold,
              italic = snap_payload_data_code_item.italic,
              underline = snap_payload_data_code_item.underline,
              hl_name = hl_name,
            })
          else
            table.insert(line_items, {
              fg = DEFAULT_FG,
              bg = DEFAULT_BG,
              text = current_segment,
              bold = false,
              italic = false,
              underline = false,
              hl_name = hl_name,
            })
          end
        end
        current_segment = ch
        current_hl_key = hl_key
        current_hl_attrs = hl_attrs
      else
        current_segment = current_segment .. ch
      end
      col = col + 1
    end
    if current_segment ~= "" then
      ---@type SnapPayloadDataCodeItem|nil
      local snap_payload_data_code_item = nil
      local hl_name = "Normal"
      if current_hl_attrs and current_hl_attrs.hl_group then
        hl_name = current_hl_attrs.hl_group
        snap_payload_data_code_item = get_snap_payload_data_code_item(current_hl_attrs, current_segment)
      end
      if snap_payload_data_code_item then
        table.insert(line_items, {
          fg = snap_payload_data_code_item.fg,
          bg = snap_payload_data_code_item.bg,
          text = current_segment,
          bold = snap_payload_data_code_item.bold,
          italic = snap_payload_data_code_item.italic,
          underline = snap_payload_data_code_item.underline,
          hl_name = hl_name,
        })
      else
        table.insert(line_items, {
          fg = DEFAULT_FG,
          bg = DEFAULT_BG,
          text = current_segment,
          bold = false,
          italic = false,
          underline = false,
          hl_name = hl_name,
        })
      end
    end
    if opts.range then
      if row >= opts.range.start_line and row <= opts.range.end_line then
        table.insert(snap_payload.data.code, line_items)
      end
    else
      table.insert(snap_payload.data.code, line_items)
    end
  end
  ui_block_releaser()
  return snap_payload
end

---Export current buffer to HTML
---@param opts SnapExportOptions|nil Export options
M.rtf_to_clipboard = function(opts)
  opts = opts or {}
  local jsonPayload = vim.fn.json_encode(get_backend_payload_from_buf({
    range = opts.range,
    type = types.SnapPayloadType.rtf,
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
          Logger.info("Exported RTF to: " .. tostring(res.data.filepath))
        else
          print("Backend error when exporting RTF failed: " .. vim.inspect(res))
        end
      end
      if result.stderr and result.stderr ~= "" then
        print("Error exporting RTF: " .. vim.inspect(result.stderr))
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

---Export current buffer to HTML
---@param opts SnapExportOptions|nil Export options
M.html_to_clipboard = function(opts)
  opts = opts or {}
  local jsonPayload = vim.fn.json_encode(get_backend_payload_from_buf({
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
  local jsonPayload = vim.fn.json_encode(get_backend_payload_from_buf({
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
      elseif opts.type == types.SnapPayloadType.html then
        M.html_to_clipboard({ range = opts.range })
      elseif opts.type == types.SnapPayloadType.rtf then
        M.rtf_to_clipboard({ range = opts.range })
      else
        Logger.error("Unsupported export type: " .. tostring(opts.type))
      end
      return
    end
    if opts.type == types.SnapPayloadType.image then
      M.image_to_clipboard()
    elseif opts.type == types.SnapPayloadType.html then
      M.html_to_clipboard()
    elseif opts.type == types.SnapPayloadType.rtf then
      M.rtf_to_clipboard()
    else
    end
  end)
end

return M
