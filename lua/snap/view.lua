local M = {}

---Scroll view to specific position temporarily
---@param winnr number Window number
---@param row number Line number (0-based)
---@param col number Column number (0-based)
---@param range SnapVisualRange|nil Range to consider
---@return nil
function M.scroll_into_view(winnr, row, col, range)
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
function M.restore_view(winnr, row, view)
  local rows = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(winnr))
  if row >= (rows - 1) then
    vim.fn.winrestview(view)
  end
end

return M
