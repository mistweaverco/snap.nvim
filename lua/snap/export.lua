local types = require("snap.types")
local Logger = require("snap.logger")
local Config = require("snap.config")
local Backend = require("snap.backend")
local payload = require("snap.payload")

local M = {}

local BACKEND_BIN_PATH = Backend.get_bin_path()

---Get default save path for screenshots
---@return string|nil Default save path or nil
function M.get_default_save_path()
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

---Run backend export with given options
---@param opts table Export options
---@param export_type SnapPayloadType Export type
---@param success_message string Success message format string (with %s for filepath)
local function run_backend_export(opts, export_type, success_message)
  opts = opts or {}
  local conf = Config.get()

  -- Use async callback to avoid blocking UI
  payload.get_backend_payload_from_buf({
    range = opts.range,
    filepath = opts.filepath,
    type = export_type,
  }, function(jsonPayload)
    -- Validate payload structure
    if not jsonPayload or not jsonPayload.data or not jsonPayload.data.type then
      Logger.error("Invalid payload structure received: " .. vim.inspect(jsonPayload))
      return
    end

    -- Debug: Log that callback was invoked
    if conf.debug then
      Logger.debug("Payload callback invoked with " .. #(jsonPayload.data.code or {}) .. " lines")
    end

    local system_args = { BACKEND_BIN_PATH }
    local cwd = nil

    if conf.debug ~= nil then
      if conf.debug.backend then
        local backend_bin_path = vim.fn.exepath(conf.debug.backend)
        if backend_bin_path == "" then
          error(conf.debug.backend .. " executable not found in PATH")
        end
        cwd = payload.get_absolute_plugin_path("backend", conf.debug.backend)
        if not vim.fn.isdirectory(cwd) then
          error("Backend directory not found: " .. cwd)
        end
        Logger.debug("Using debug backend at: " .. backend_bin_path .. " with cwd: " .. cwd)
        system_args = { backend_bin_path, "run", "." }
      end
    end

    local jsonPayloadStr = vim.fn.json_encode(jsonPayload)

    -- Validate payload has content
    if not jsonPayload.data.code or #jsonPayload.data.code == 0 then
      Logger.warn("Payload has no code content - buffer might be empty")
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
            Logger.info(string.format(success_message, tostring(res.data.filepath)))
          else
            print("Backend error when exporting failed: " .. vim.inspect(res))
          end
        end
        if result.stderr and result.stderr ~= "" then
          print("Error exporting: " .. vim.inspect(result.stderr))
        end
        if result.code ~= 0 then
          print("Process exited with non-zero code: " .. tostring(result.code))
        end
      end)
    )

    -- Write JSON payload to stdin immediately after system starts
    if system_obj then
      system_obj:write(jsonPayloadStr)
      -- Close stdin to signal end of input
      system_obj:write(nil)
    else
      Logger.error("Failed to create system process")
    end
  end)
end

---Export current buffer to RTF
---@param opts SnapExportOptions|nil Export options
function M.rtf_to_clipboard(opts)
  run_backend_export(opts, types.SnapPayloadType.rtf, "Exported RTF to: %s")
end

---Export current buffer to HTML
---@param opts SnapExportOptions|nil Export options
function M.html_to_clipboard(opts)
  run_backend_export(opts, types.SnapPayloadType.html, "Exported HTML to: %s")
end

---Export current buffer to image
---@param opts SnapExportOptions|nil Export options
function M.image_to_clipboard(opts)
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
  run_backend_export({ range = opts.range, filepath = filepath }, types.SnapPayloadType.image, "Exported image to: %s")
end

return M
