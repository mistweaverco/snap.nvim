local utils = require("snap.highlights.utils")

local M = {}

---Get raw highlight definition by name (without defaults), resolving links
---@param name string Highlight group name
---@return table|nil Raw highlight definition table (only includes attributes that are set) or nil
---@return string|nil Actual highlight group name used
function M.get_raw_hl_by_name(name)
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
function M.get_hl_by_name(name)
  if not name or name == "" then
    return nil, nil
  end

  local DEFAULT_BG = utils.get_default_bg()
  local DEFAULT_FG = utils.get_default_fg()

  ---Helper to extract highlight properties from hl definition
  ---@param hl table Highlight definition from nvim_get_hl
  ---@return table Normalized highlight table
  local function extract_hl_props(hl)
    local t = {}
    if hl.fg then
      t.fg = utils.convert_color_to_hex(hl.fg)
    else
      t.fg = DEFAULT_FG
    end
    if hl.bg then
      t.bg = utils.convert_color_to_hex(hl.bg)
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

---Extract semantic token highlight from vim.inspect_pos result
---Semantic tokens can be in extmarks (with ns matching "semantic_tokens") or in semantic_tokens field
---Returns the highest priority semantic token highlight
---Note: In Neovim, higher priority values have higher precedence (priority 200 > priority 100)
---@param info table Result from vim.inspect_pos
---@return string|nil Highlight group name or nil
function M.extract_semantic_hl(info)
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
function M.extract_treesitter_highlights(info)
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

return M
