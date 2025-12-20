local M = {}

---Scroll view to specific position temporarily
---@param winnr number Window number
---@param row number Line number (0-based)
---@param col number Column number (0-based)
---@param range SnapVisualRange|nil Range to consider
---@return boolean Whether scrolling occurred (true) or content was already in view (false)
function M.scroll_into_view(winnr, row, col, range)
  local nvim_cursor = vim.api.nvim_win_get_cursor(winnr)
  local height = vim.api.nvim_win_get_height(winnr)
  -- check if already in view via cursor position,
  -- if in view, no need to scroll
  if row >= (nvim_cursor[1] - 1) and row < (nvim_cursor[1] - 1 + height) then
    vim.cmd("redraw")
    return false
  end
  if range then
    -- check if range is already in view
    -- if in view, no need to scroll
    if range.start_line >= (nvim_cursor[1] - 1) and range.end_line < (nvim_cursor[1] - 1 + height) then
      vim.cmd("redraw")
      return false
    end
  end
  -- scroll so that row is the top most line
  vim.api.nvim_win_set_cursor(winnr, { row + 1, col })
  vim.cmd("redraw")
  return true
end

---Restore view state after scrolling
---@param winnr number Window number
---@param row number Line number (0-based) - used to determine if we scrolled
---@param view vim.fn.winsaveview.ret View state to restore
function M.restore_view(winnr, row, view)
  -- Always restore the view state to return to original position
  -- This is safe to call even if we didn't scroll (winrestview is idempotent)
  vim.fn.winrestview(view)
end

return M
