---UI Attach Module
---
---This module implements UI attach functionality to capture the complete Neovim UI state
---including all grids, windows, floating windows, statuslines, etc.
---
---Implementation Notes:
---- The nvim_ui_attach API creates an embedded UI client that receives redraw events
---  through the UI protocol. The actual event handling mechanism may vary depending on
---  Neovim version and how events are exposed to Lua plugins.
---
---- Redraw events include:
---  * grid_resize - Grid size changes
---  * grid_line - Line updates with cells (text, hl_id, repeat)
---  * grid_clear - Grid cleared
---  * grid_cursor_goto - Cursor position updates
---  * win_pos - Window position updates
---  * hl_attr_define - Highlight attribute definitions
---
---- Highlight IDs are cached by default to improve performance across multiple snapshots.
---  Use :Snap image nocache or :Snap image cache=false to force cache rebuild.
---
---@module snap.ui_attach
local M = {}
local Logger = require("snap.logger")
local highlights_utils = require("snap.highlights.utils")

---@class UIGridCell
---@field text string Cell text content
---@field hl_id number Highlight ID for this cell
---@field repeat_count number|nil Repeat count for the cell

---@class UIGridLine
---@field row number Row number (0-based)
---@field cells UIGridCell[] Array of cells in this line

---@class UIGrid
---@field id number Grid ID
---@field width number Grid width
---@field height number Grid height
---@field lines table<number, UIGridLine> Lines indexed by row (0-based)
---@field cursor_row number|nil Cursor row (0-based)
---@field cursor_col number|nil Cursor column (0-based)
---@field win_id number|nil Window ID associated with this grid
---@field win_row number|nil Window row position (0-based)
---@field win_col number|nil Window column position (0-based)

---@class UIHighlightAttr
---@field id number Highlight ID
---@field foreground number|nil RGB foreground color (0xRRGGBB)
---@field background number|nil RGB background color (0xRRGGBB)
---@field bold boolean|nil
---@field italic boolean|nil
---@field underline boolean|nil
---@field undercurl boolean|nil
---@field strikethrough boolean|nil

---@class UIScene
---@field grids table<number, UIGrid> Grids indexed by grid ID
---@field highlights table<number, UIHighlightAttr> Highlight attributes indexed by highlight ID
---@field default_bg string Default background color
---@field default_fg string Default foreground color

--- Highlight ID cache
---@type table<number, UIHighlightAttr>
local hl_cache = {}

--- Current UI attach state
---@type {client_id: number, scene: UIScene, callback: function|nil, use_cache: boolean}|nil
local attach_state = nil

---Convert RGB number to hex string
---@param rgb number|nil RGB color as integer (0xRRGGBB)
---@return string|nil Hex color string or nil
local function rgb_to_hex(rgb)
  if not rgb then
    return nil
  end
  return string.format("#%06x", rgb)
end

---Get or create highlight attribute from highlight ID
---@param hl_id number Highlight ID
---@param rgb_attrs table|nil RGB attributes from hl_attr_define
---@param cterm_attrs table|nil Cterm attributes from hl_attr_define
---@param use_cache boolean Whether to use cache
---@return UIHighlightAttr
local function get_highlight_attr(hl_id, rgb_attrs, cterm_attrs, use_cache)
  -- Check cache first if enabled
  if use_cache and hl_cache[hl_id] then
    return hl_cache[hl_id]
  end

  local attr = {
    id = hl_id,
    foreground = rgb_attrs and rgb_attrs.foreground or nil,
    background = rgb_attrs and rgb_attrs.background or nil,
    bold = rgb_attrs and rgb_attrs.bold or false,
    italic = rgb_attrs and rgb_attrs.italic or false,
    underline = rgb_attrs and rgb_attrs.underline or false,
    undercurl = rgb_attrs and rgb_attrs.undercurl or false,
    strikethrough = rgb_attrs and rgb_attrs.strikethrough or false,
  }

  -- Cache if enabled
  if use_cache then
    hl_cache[hl_id] = attr
  end

  return attr
end

---Handle redraw events from UI attach
---@param event_name string Event name
---@param args table Event arguments
---@param scene UIScene Current scene state
---@param use_cache boolean Whether to use highlight cache
local function handle_redraw_event(event_name, args, scene, use_cache)
  if event_name == "grid_resize" then
    local grid_id = args[1]
    local width = args[2]
    local height = args[3]

    if not scene.grids[grid_id] then
      scene.grids[grid_id] = {
        id = grid_id,
        width = width,
        height = height,
        lines = {},
      }
    else
      scene.grids[grid_id].width = width
      scene.grids[grid_id].height = height
      -- Clear existing lines when grid is resized
      scene.grids[grid_id].lines = {}
    end
  elseif event_name == "grid_line" then
    local grid_id = args[1]
    local row = args[2]
    local col_start = args[3]
    local cells = args[4]

    if not scene.grids[grid_id] then
      scene.grids[grid_id] = {
        id = grid_id,
        width = 0,
        height = 0,
        lines = {},
      }
    end

    if not scene.grids[grid_id].lines[row] then
      scene.grids[grid_id].lines[row] = {
        row = row,
        cells = {},
      }
    end

    local line = scene.grids[grid_id].lines[row]
    local current_col = col_start

    -- Process cells
    for _, cell in ipairs(cells) do
      local text = cell[1] or ""
      local hl_id = cell[2] or 0
      local repeat_count = cell[3] or 1

      -- Handle wide characters and special cases
      if text == "" and repeat_count > 0 then
        -- Empty cell with repeat, likely a continuation
        text = " "
      end

      -- Expand repeat count
      for _ = 1, repeat_count do
        table.insert(line.cells, {
          text = text,
          hl_id = hl_id,
          repeat_count = repeat_count,
        })
        current_col = current_col + 1
      end
    end
  elseif event_name == "grid_clear" then
    local grid_id = args[1]
    if scene.grids[grid_id] then
      scene.grids[grid_id].lines = {}
    end
  elseif event_name == "grid_cursor_goto" then
    local grid_id = args[1]
    local row = args[2]
    local col = args[3]

    if not scene.grids[grid_id] then
      scene.grids[grid_id] = {
        id = grid_id,
        width = 0,
        height = 0,
        lines = {},
      }
    end

    scene.grids[grid_id].cursor_row = row
    scene.grids[grid_id].cursor_col = col
  elseif event_name == "win_pos" then
    local grid_id = args[1]
    local win_id = args[2]
    local row = args[3]
    local col = args[4]
    local width = args[5]
    local height = args[6]

    if not scene.grids[grid_id] then
      scene.grids[grid_id] = {
        id = grid_id,
        width = width,
        height = height,
        lines = {},
      }
    end

    scene.grids[grid_id].win_id = win_id
    scene.grids[grid_id].win_row = row
    scene.grids[grid_id].win_col = col
    scene.grids[grid_id].width = width
    scene.grids[grid_id].height = height
  elseif event_name == "hl_attr_define" then
    local hl_id = args[1]
    local rgb_attrs = args[2]
    local cterm_attrs = args[3]

    local attr = get_highlight_attr(hl_id, rgb_attrs, cterm_attrs, use_cache)
    scene.highlights[hl_id] = attr
  end
end

---Attach to UI using embedded Neovim instance
---This uses --embed mode to start a separate Neovim instance and capture UI events
---@param opts {use_cache: boolean, timeout: number|nil, content: string[]|nil} Options
---@param callback function Callback function(scene: UIScene|nil, error: string|nil)
---@return number|nil Process ID or nil on error
function M.attach_via_embed(opts, callback)
  opts = opts or {}
  local use_cache = opts.use_cache ~= false -- Default to true
  local timeout = opts.timeout or 2000 -- 2 seconds default
  local content = opts.content or {}

  -- Get UI dimensions
  local width = vim.o.columns
  local height = vim.o.lines

  -- Get current buffer content if not provided
  if #content == 0 then
    local bufnr = vim.api.nvim_get_current_buf()
    content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end

  -- Create a temporary script that will run in embedded mode
  -- This script will load content and attempt to capture UI state
  local script_content = string.format(
    [[
    local width = %d
    local height = %d
    local content = %s
    
    -- Load content into buffer
    local bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
    vim.api.nvim_set_current_buf(bufnr)
    
    -- Force redraw
    vim.cmd("redraw!")
    
    -- Try to get UI info (this is a workaround since we can't easily attach as UI client from within)
    -- In a full implementation, we'd need an external helper that uses the Neovim client library
    local scene = {
      grids = {},
      highlights = {},
      default_bg = "#000000",
      default_fg = "#ffffff",
    }
    
    -- Output scene as JSON
    print(vim.json.encode({
      success = true,
      scene = scene,
    }))
  ]],
    width,
    height,
    vim.json.encode(content)
  )

  -- Write script to temp file
  local script_path = vim.fn.tempname() .. "_snap_ui_attach.lua"
  local script_file = io.open(script_path, "w")
  if not script_file then
    if callback then
      callback(nil, "Failed to create temporary script file")
    end
    return nil
  end
  script_file:write(script_content)
  script_file:close()

  -- Execute embedded Neovim instance
  local nvim_cmd = vim.fn.exepath("nvim")
  if nvim_cmd == "" then
    nvim_cmd = "nvim"
  end

  local cmd = { nvim_cmd, "--headless", "--embed", "-l", script_path }

  -- Note: This is a simplified approach. A full implementation would:
  -- 1. Use MessagePack-RPC to communicate with embedded instance
  -- 2. Attach as UI client using Neovim client library
  -- 3. Capture actual redraw events
  -- 4. Build complete scene from events

  -- For now, we'll use a basic approach and note the limitation
  Logger.warn("UI attach via --embed is experimental and requires additional implementation")
  Logger.warn("Full implementation needs Neovim client library for MessagePack-RPC")

  if callback then
    callback(nil, "UI attach via --embed requires Neovim client library implementation")
  end

  -- Cleanup
  pcall(function()
    os.remove(script_path)
  end)

  return nil
end

---Attach to UI and capture redraw events
---Note: This attempts to use nvim_ui_attach directly, which may not work from within a plugin.
---Falls back to embedded mode if available.
---@param opts {use_cache: boolean, timeout: number|nil} Options
---@param callback function Callback function(scene: UIScene|nil, error: string|nil)
---@return number|nil Client ID or nil on error
function M.attach(opts, callback)
  opts = opts or {}
  local use_cache = opts.use_cache ~= false -- Default to true
  local timeout = opts.timeout or 1000 -- 1 second default to capture state

  -- Get UI dimensions directly from Neovim options
  -- Use vim.o.columns and vim.o.lines which are always available
  local width = vim.o.columns
  local height = vim.o.lines

  -- Create new scene
  local scene = {
    grids = {},
    highlights = {},
    default_bg = highlights_utils.get_default_bg(),
    default_fg = highlights_utils.get_default_fg(),
  }

  -- Try direct UI attach first
  local ok, channel_id = pcall(function()
    return vim.api.nvim_ui_attach(width, height, {
      ext_linegrid = true,
      ext_multigrid = true,
      ext_hlstate = true,
      ext_termcolors = true,
      rgb = true,
    })
  end)

  if not ok or not channel_id then
    -- If direct attach fails, try embedded mode
    Logger.warn("Direct nvim_ui_attach failed, trying embedded mode")
    return M.attach_via_embed(opts, callback)
  end

  -- Store attach state
  attach_state = {
    client_id = channel_id,
    scene = scene,
    callback = callback,
    use_cache = use_cache,
  }

  -- Force a redraw to trigger events
  vim.cmd("redraw!")

  -- Set timeout to detach and return scene
  local timer = vim.fn.timer_start(timeout, function()
    M.detach(channel_id)
    if callback then
      callback(scene, nil)
    end
  end)

  return channel_id
end

---Detach from UI
---@param client_id number Client ID to detach
function M.detach(client_id)
  if client_id then
    pcall(function()
      vim.api.nvim_ui_detach(client_id)
    end)
  end

  if attach_state and attach_state.client_id == client_id then
    attach_state = nil
  end
end

---Clear highlight cache
function M.clear_cache()
  hl_cache = {}
end

---Get current scene (if attached)
---@return UIScene|nil
function M.get_scene()
  if attach_state then
    return attach_state.scene
  end
  return nil
end

return M
