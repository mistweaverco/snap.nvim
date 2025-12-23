local types = require("snap.types")
local Config = require("snap.config")
local highlights_map = require("snap.highlights.map")
local highlights_collection = require("snap.highlights.collection")
local highlights_utils = require("snap.highlights.utils")
local UIBlock = require("snap.ui.block")

local M = {}

---Convert highlight definition table to CSS style string
---@param t table|nil Highlight definition table
---@param text string Text content (for future use)
---@return SnapPayloadDataCodeItem|nil Highlight style or nil
local function get_snap_payload_data_code_item(t, text)
  local default_bg = highlights_utils.get_default_bg()
  local default_fg = highlights_utils.get_default_fg()

  if not t then
    return nil
  end
  return {
    fg = t.fg or default_fg,
    bg = t.bg or default_bg,
    text = text,
    bold = t.bold or false,
    italic = t.italic or false,
    underline = t.underline or false,
    hl_table = t,
  }
end

---Get default output path for buffer
---@param bufnr number Buffer number
---@return string Output file path
function M.default_output_path(bufnr)
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
---@param callback function|nil Optional callback function(payload) - if provided, processing is async
---@return SnapPayload|nil JSON payload for backend (nil if callback is provided)
function M.get_backend_payload_from_buf(opts, callback)
  opts = opts or {}

  local default_bg = highlights_utils.get_default_bg()
  local default_fg = highlights_utils.get_default_fg()

  local user_config = Config.get()
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = opts.filepath or M.default_output_path(bufnr)
  -- Save current view and cursor to restore later
  local view = vim.fn.winsaveview()
  local original_cursor = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local hl_map = highlights_map.build_hl_map(bufnr)

  --- @type SnapPayload
  local snap_payload = {
    success = true,
    debug = user_config.debug and true or false,
    data = {
      additional_template_data = user_config.additional_template_data or {},
      code = {},
      theme = {
        bgColor = default_bg,
        fgColor = default_fg,
      },
      template = user_config.template or "default",
      toClipboard = true,
      filepath = filepath,
      fontSettings = user_config.font_settings or Config.defaults.font_settings,
      outputImageFormat = types.SnapImageOutputFormat.png,
      templateFilepath = user_config.templateFilepath or nil,
      transparent = true,
      minWidth = 0,
      type = (opts and opts.type) or types.SnapPayloadType.image,
    },
  }

  -- Ensure type is always set (defensive check)
  if not snap_payload.data.type then
    snap_payload.data.type = types.SnapPayloadType.image
  end

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

  -- Process highlights asynchronously in batches to avoid blocking UI
  local BATCH_SIZE = 50 -- Process 50 characters before yielding

  -- Process a single line asynchronously
  local function process_line_async(row, line, on_complete)
    ---@type table<SnapPayloadDataCodeItem|nil>
    local line_items = {}
    local col = 0
    local current_hl_key = nil
    local current_hl_attrs = nil
    local current_segment = ""

    local function process_batch()
      local batch_count = 0
      while col < #line and batch_count < BATCH_SIZE do
        local ch = line:sub(col + 1, col + 1)
        local hl_attrs = highlights_collection.get_hl_at(win, hl_map, bufnr, row - 1, col, view, opts.range)
        -- If no highlight attributes, create a default one with "Normal"
        if not hl_attrs then
          hl_attrs = {
            hl_group = "Normal",
            fg = default_fg,
            bg = default_bg,
            bold = false,
            italic = false,
            underline = false,
          }
        end
        local hl_key = highlights_utils.hl_attrs_to_key(hl_attrs)
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
                fg = default_fg,
                bg = default_bg,
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
        batch_count = batch_count + 1
      end

      if col < #line then
        -- More characters to process, yield to event loop
        vim.schedule(function()
          process_batch()
        end)
      else
        -- Line complete, finalize segment
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
              fg = default_fg,
              bg = default_bg,
              text = current_segment,
              bold = false,
              italic = false,
              underline = false,
              hl_name = hl_name,
            })
          end
        end
        on_complete(line_items)
      end
    end

    -- Start processing
    process_batch()
  end

  -- If callback is provided, use async processing
  if callback then
    -- Handle empty buffer case
    if #lines == 0 then
      ui_block_releaser()
      -- Restore original view and cursor position
      vim.fn.winrestview(view)
      vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), original_cursor)
      vim.schedule(function()
        callback(snap_payload)
      end)
      return nil
    end

    -- Process all lines asynchronously
    local current_line_idx = 1
    local function process_next_line()
      if current_line_idx > #lines then
        -- All lines processed
        ui_block_releaser()
        -- Restore original view and cursor position
        vim.fn.winrestview(view)
        vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), original_cursor)
        -- Ensure payload is complete and has all required fields
        if not snap_payload then
          error("Payload is nil")
        elseif not snap_payload.data then
          error("Payload.data is nil")
        elseif not snap_payload.data.type then
          -- Ensure type is set if it's missing
          snap_payload.data.type = opts.type or types.SnapPayloadType.image
        end
        -- Call callback in next event loop tick to ensure all async operations are complete
        vim.schedule(function()
          callback(snap_payload)
        end)
        return
      end

      local row = current_line_idx
      local line = lines[row]
      process_line_async(row, line, function(line_items)
        if opts.range then
          if row >= opts.range.start_line and row <= opts.range.end_line then
            table.insert(snap_payload.data.code, line_items)
          end
        else
          table.insert(snap_payload.data.code, line_items)
        end

        -- Process next line
        current_line_idx = current_line_idx + 1
        vim.schedule(function()
          process_next_line()
        end)
      end)
    end

    -- Start async processing
    process_next_line()
    return nil
  else
    -- Synchronous processing (blocks UI, but maintains backward compatibility)
    for row, line in ipairs(lines) do
      ---@type table<SnapPayloadDataCodeItem|nil>
      local line_items = {}
      local col = 0
      local current_hl_key = nil
      local current_hl_attrs = nil
      local current_segment = ""
      while col < #line do
        local ch = line:sub(col + 1, col + 1)
        local hl_attrs = highlights_collection.get_hl_at(win, hl_map, bufnr, row - 1, col, view, opts.range)
        -- If no highlight attributes, create a default one with "Normal"
        if not hl_attrs then
          hl_attrs = {
            hl_group = "Normal",
            fg = default_fg,
            bg = default_bg,
            bold = false,
            italic = false,
            underline = false,
          }
        end
        local hl_key = highlights_utils.hl_attrs_to_key(hl_attrs)
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
                fg = default_fg,
                bg = default_bg,
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
            fg = default_fg,
            bg = default_bg,
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
    -- Restore original view and cursor position
    vim.fn.winrestview(view)
    vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), original_cursor)
    return snap_payload
  end
end

M.get_absolute_plugin_path = get_absolute_plugin_path

return M
