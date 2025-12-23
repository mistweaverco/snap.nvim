local extraction = require("snap.highlights.extraction")
local utils = require("snap.highlights.utils")
local view = require("snap.view")

local M = {}

---Merge multiple highlight definitions, with higher priority taking precedence
---for each attribute. Attributes from lower priority highlights are preserved if not specified in
---higher priority highlights. When priorities are equal, the last one added (higher index) wins.
---@param highlights table Array of {hl_group = string, priority = number}
---@return table|nil Merged highlight definition table (normalized with defaults) or nil
function M.merge_highlights(highlights)
  local default_bg = utils.get_default_bg()
  local default_fg = utils.get_default_fg()

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
  local base_raw_hl, _ = extraction.get_raw_hl_by_name(highlights[1].hl_group)
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
    local raw_hl, _ = extraction.get_raw_hl_by_name(highlights[i].hl_group)
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
    merged.fg = utils.convert_color_to_hex(merged_raw.fg)
  else
    merged.fg = default_fg
  end
  if merged_raw.bg then
    merged.bg = utils.convert_color_to_hex(merged_raw.bg)
  else
    merged.bg = default_bg
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
function M.collect_all_highlights(info)
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
  local treesitter_highlights = extraction.extract_treesitter_highlights(info)
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

  -- Priority 1: Semantic tokens (if in semantic_tokens field) - collect before extmarks
  -- Semantic tokens from LSP have explicit priorities (typically 125-127)
  if info.semantic_tokens and #info.semantic_tokens > 0 then
    for _, token in ipairs(info.semantic_tokens) do
      local hl_group = token.hl_group or (token.opts and token.opts.hl_group)
      local priority = token.priority or (token.opts and token.opts.priority)

      if hl_group and priority then
        -- Check if we already have this highlight group
        local found_index = nil
        for i, hl in ipairs(highlights) do
          if hl.hl_group == hl_group then
            found_index = i
            break
          end
        end

        if found_index then
          -- Replace with semantic token version if it has higher priority
          if priority > (highlights[found_index].priority or 0) then
            highlights[found_index] = { hl_group = hl_group, priority = priority }
          end
        else
          -- Add new semantic token highlight
          table.insert(highlights, { hl_group = hl_group, priority = priority })
        end
      end
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
        -- - Semantic tokens (LSP): use their explicit priority (typically 125-127)
        -- - Other extmarks: should have highest precedence to override treesitter/syntax
        --   Higher priority value = higher precedence
        local ns = tostring(extmark.ns or "")
        local is_treesitter = ns:match("^treesitter") or ns:match("^nvim%-treesitter") or ns == "TS"
        local is_semantic_token = ns:match("semantic") or (hl_group and hl_group:match("^@lsp"))

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
        elseif is_semantic_token then
          -- Semantic tokens: use their explicit priority (typically 125-127)
          -- If no explicit priority, use high precedence to override treesitter
          priority = extmark_priority or 200
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
---@param view_state vim.fn.winsaveview.ret View state to restore later
---@param range SnapVisualRange|nil Range to consider
---@return table|nil Merged highlight definition table or nil
function M.get_hl_at_pos(winnr, bufnr, row, col, view_state, range)
  local did_scroll = view.scroll_into_view(winnr, row, col, range)

  -- Inspect highlights synchronously - scroll_into_view already handled redraw
  local ok, info = pcall(vim.inspect_pos, bufnr, row, col)
  if not ok or not info then
    -- Don't restore view here - will be restored at end of processing
    return nil
  end

  -- Collect all highlights at this position
  local highlights = M.collect_all_highlights(info)

  -- Merge highlights by priority
  local result = M.merge_highlights(highlights)

  -- Don't restore view after each character - restore once at end of processing
  -- This avoids interfering with async batch processing

  return result
end

---Get merged highlight attributes at specific position
---Uses vim.inspect_pos for accurate results including semantic tokens
---Falls back to hl_map lookup if vim.inspect_pos is not available
---@param winr number Window number
---@param hl_map table Highlight map (used as fallback)
---@param bufnr number Buffer number
---@param row number Line number (0-based)
---@param col number Column number (0-based byte offset)
---@param view_state vim.fn.winsaveview.ret View state to restore later
---@param range SnapVisualRange|nil Range to consider
---@return table|nil Merged highlight attributes table or nil
function M.get_hl_at(winr, hl_map, bufnr, row, col, view_state, range)
  if vim.inspect_pos then
    local hl = M.get_hl_at_pos(winr, bufnr, row, col, view_state, range)
    if hl then
      return hl
    end
  end

  -- Fallback to hl_map lookup - resolve highlight group to attributes
  local hl_map_module = require("snap.highlights.map")
  if not hl_map[row] then
    return nil
  end
  local existing_segments = hl_map_module.exists_in_hl_map(hl_map, row, col, col + 1)
  if existing_segments and #existing_segments > 0 then
    -- Get the highlight group from the segment
    local hl_group = existing_segments[#existing_segments].hl_group
    if hl_group then
      local hldef, resolved_hl = extraction.get_hl_by_name(hl_group)
      if hldef then
        -- Include the highlight group name in the result
        hldef.hl_group = resolved_hl or hl_group
        return hldef
      end
    end
  end
  return nil
end

return M
