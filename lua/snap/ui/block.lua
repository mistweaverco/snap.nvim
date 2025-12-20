local M = {}

local spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" }

--- Creates a centered floating window that locks user interaction.
--- @param text string|nil
--- @return function stop_fn Callback to restore interaction and close the window.
M.show_loading_locked = function(text)
  text = text or "Generation in progress"

  -- 1. Save original state to restore later
  local original_win = vim.api.nvim_get_current_win()
  local original_mouse = vim.opt.mouse

  -- Disable mouse and prepare dimensions
  vim.opt.mouse = ""
  local win_width = #text + 10
  local win_height = 3
  local row = math.floor((vim.o.lines - win_height) / 2)
  local col = math.floor((vim.o.columns - win_width) / 2)

  -- 2. Create Buffer and Window
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, { -- 'true' makes it focusable
    relative = "editor",
    style = "minimal",
    border = "rounded",
    row = row,
    col = col,
    width = win_width,
    height = win_height,
    zindex = 300, -- High z-index to stay above everything
    focusable = true,
  })

  -- 3. Lock the buffer mappings (Optional extra security)
  -- This prevents someone from accidentally hitting 'i' or ':' and doing something
  local opts = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set("n", "<Esc>", "<Nop>", opts)
  -- You could loop through more keys here, but the Vacuum below handles it globally

  -- 4. The Animation + Input Vacuum Timer
  local frame_idx = 1
  local timer = vim.uv.new_timer()

  -- Initial display
  -- So we have at least one frame displayed,
  -- when something else blocks the event loop
  vim.api.nvim_buf_set_lines(buf, 1, 2, false, { string.format("  %s  %s", spinner_frames[frame_idx], text) })

  local update_callback = vim.schedule_wrap(function()
    if not vim.api.nvim_win_is_valid(win) then
      if timer and not timer:is_closing() then
        timer:stop()
        timer:close()
      end
      return
    end

    -- A. THE INPUT VACUUM
    -- This discards every single keypress that happened since the last frame
    while vim.fn.getchar(0) ~= 0 do
      -- Do nothing, just eating the input
    end

    -- B. Update Animation
    local spinner = spinner_frames[frame_idx]
    local line = string.format("  %s  %s", spinner, text)

    vim.api.nvim_buf_set_lines(buf, 1, 2, false, { line })
    frame_idx = (frame_idx % #spinner_frames) + 1
  end)

  timer:start(0, 80, update_callback)

  -- 5. Return the "Unlock" function
  return function()
    -- Stop timer
    if timer then
      timer:stop()
      if not timer:is_closing() then
        timer:close()
      end
    end

    -- Restore mouse and focus
    vim.opt.mouse = original_mouse
    if vim.api.nvim_win_is_valid(original_win) then
      vim.api.nvim_set_current_win(original_win)
    end

    -- Close the shield
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
end

return M
