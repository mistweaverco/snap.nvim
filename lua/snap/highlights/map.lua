local M = {}

--- Check if a highlight exists in the map for given range
--- @param hl_map table Highlight map
--- @param row number Line number (0-based)
--- @param start_col number Start column (0-based)
--- @param end_col number End column (0-based)
--- @return table|nil Highlight segments or nil
function M.exists_in_hl_map(hl_map, row, start_col, end_col)
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
function M.build_hl_map(bufnr)
  return build_hl_map_treesitter(bufnr)
end

return M
