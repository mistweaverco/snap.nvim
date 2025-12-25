local types = require("snap.types")
local Logger = require("snap.logger")
local Config = require("snap.config")
local Backend = require("snap.backend")
local payload = require("snap.payload")

local M = {}

local BACKEND_BIN_PATH = Backend.get_bin_path()

---Check if Playwright browser is available by calling the backend health endpoint
---@param callback function|nil Callback function called with result: {isInstalled: boolean, executablePath: string|nil}
local function check_backend_health(callback)
  local conf = Config.get()
  local system_args = { BACKEND_BIN_PATH, "health" }
  local cwd = nil

  if conf.development_mode ~= nil then
    if conf.development_mode.backend then
      local backend_bin_path = vim.fn.exepath(conf.development_mode.backend)
      if backend_bin_path == "" then
        error(conf.development_mode.backend .. " executable not found in PATH")
      end
      cwd = payload.get_absolute_plugin_path("backend", conf.development_mode.backend)
      if not vim.fn.isdirectory(cwd) then
        error("Backend directory not found: " .. cwd)
      end
      system_args = { backend_bin_path, "run", "src/index.ts", "health" }
    end
  end

  vim.system(
    system_args,
    {
      timeout = 5000, -- 5 second timeout for health check
      stdin = true,
      cwd = cwd,
      env = vim.fn.environ(),
      text = true,
    },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        Logger.error("Health check failed with exit code: " .. tostring(result.code))
        if callback then
          callback({ isInstalled = false, executablePath = nil })
        end
        return
      end

      if result.stdout and result.stdout ~= "" then
        local ok, res = pcall(vim.fn.json_decode, result.stdout)
        if not ok or not res.success then
          Logger.warn("Failed to decode health check response: " .. tostring(res))
          if callback then
            callback({ isInstalled = false, executablePath = nil })
          end
          return
        end

        if callback then
          callback({
            isInstalled = res.data.isInstalled or false,
            executablePath = res.data.executablePath,
          })
        end
      else
        if callback then
          callback({ isInstalled = false, executablePath = nil })
        end
      end
    end)
  )
end

---Install/verify Playwright browser by calling the backend install endpoint
---@param progress_callback function|nil Callback function called with progress updates: {status: string, message: string, progress: number|nil}
---@param completion_callback function|nil Callback function called when installation completes: {success: boolean, executablePath: string|nil}
local function install_backend(progress_callback, completion_callback)
  local conf = Config.get()
  local system_args = { BACKEND_BIN_PATH, "install" }
  local cwd = nil

  if conf.development_mode ~= nil then
    if conf.development_mode.backend then
      local backend_bin_path = vim.fn.exepath(conf.development_mode.backend)
      if backend_bin_path == "" then
        error(conf.development_mode.backend .. " executable not found in PATH")
      end
      cwd = payload.get_absolute_plugin_path("backend", conf.development_mode.backend)
      if not vim.fn.isdirectory(cwd) then
        error("Backend directory not found: " .. cwd)
      end
      -- Use src/index.ts explicitly to ensure command line arguments are passed correctly
      system_args = { backend_bin_path, "run", "src/index.ts", "install" }
    end
  end

  -- Use jobstart for real-time output streaming
  local final_result = nil
  local stdout_buffer = ""

  local job_id = vim.fn.jobstart(system_args, {
    cwd = cwd,
    env = vim.fn.environ(),
    on_stdout = vim.schedule_wrap(function(_, data, _)
      -- Accumulate stdout data
      for _, line in ipairs(data) do
        if line ~= "" then
          stdout_buffer = stdout_buffer .. line .. "\n"
        end
      end

      -- Try to parse complete lines
      local lines = vim.split(stdout_buffer, "\n", { trimempty = false })
      -- Keep the last incomplete line in buffer
      stdout_buffer = lines[#lines] or ""

      -- Process complete lines
      for i = 1, #lines - 1 do
        local line = lines[i]
        if line ~= "" then
          local ok, res = pcall(vim.fn.json_decode, line)
          if ok and res.success then
            if res.data and res.data.type == "install" then
              if res.data.status == "completed" then
                final_result = res
              elseif progress_callback then
                progress_callback({
                  status = res.data.status,
                  message = res.data.message,
                  progress = res.data.progress,
                })
              end
            else
              -- Final result without type
              final_result = res
            end
          end
        end
      end
    end),
    on_stderr = vim.schedule_wrap(function(_, data, _)
      if data and #data > 0 then
        Logger.error("Install error: " .. table.concat(data, "\n"))
      end
    end),
    on_exit = vim.schedule_wrap(function(_, exit_code, _)
      if exit_code ~= 0 then
        Logger.error("Install failed with exit code: " .. tostring(exit_code))
        if completion_callback then
          completion_callback({ success = false, executablePath = nil })
        end
        return
      end

      -- Process any remaining buffer
      if stdout_buffer ~= "" then
        local ok, res = pcall(vim.fn.json_decode, stdout_buffer)
        if ok and res.success then
          if res.data and res.data.type == "install" then
            if res.data.status == "completed" then
              final_result = res
            end
          else
            final_result = res
          end
        end
      end

      if final_result and completion_callback then
        completion_callback({
          success = final_result.success,
          executablePath = final_result.data and final_result.data.executablePath,
        })
      elseif completion_callback then
        completion_callback({ success = false, executablePath = nil })
      end
    end),
    stdout_buffered = false, -- Don't buffer stdout - process line by line
    stderr_buffered = false, -- Don't buffer stderr
  })

  if job_id <= 0 then
    Logger.error("Failed to start install process")
    if completion_callback then
      completion_callback({ success = false, executablePath = nil })
    end
  end
end

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

  -- Inner function to proceed with the actual export
  local function proceed_with_export()
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

      local system_args = { BACKEND_BIN_PATH }
      local cwd = nil

      if conf.development_mode ~= nil then
        if conf.development_mode.backend then
          local backend_bin_path = vim.fn.exepath(conf.development_mode.backend)
          if backend_bin_path == "" then
            error(conf.development_mode.backend .. " executable not found in PATH")
          end
          cwd = payload.get_absolute_plugin_path("backend", conf.development_mode.backend)
          if not vim.fn.isdirectory(cwd) then
            error("Backend directory not found: " .. cwd)
          end
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
              Logger.notify(string.format(success_message, tostring(res.data.filepath)), Logger.LoggerLogLevels.info)
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

  -- First, check if Playwright browser is available
  check_backend_health(function(health_result)
    if not health_result.isInstalled then
      -- Browser is not available, resolve it first
      Logger.notify("Browser not found. Resolving...", Logger.LoggerLogLevels.info)
      install_backend(function(progress)
        -- Show progress updates
        if progress.status == "resolving" or progress.status == "installing" then
          Logger.notify(progress.message, Logger.LoggerLogLevels.info)
        elseif progress.status == "completed" then
          Logger.notify(progress.message, Logger.LoggerLogLevels.info)
        elseif progress.status == "error" then
          Logger.error("Installation error: " .. progress.message)
        end
      end, function(install_result)
        if install_result.success then
          Logger.notify("Browser installation completed successfully", Logger.LoggerLogLevels.info)
          -- Proceed with normal export flow
          proceed_with_export()
        else
          Logger.error("Failed to install browser. Cannot proceed with export.")
        end
      end)
    else
      -- Browser is available, proceed with normal export flow
      proceed_with_export()
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
  local save_path = M.get_default_save_path()
  if not save_path then
    Logger.error("No valid save path found for screenshots. Please set 'output_dir' in config")
    return
  end
  run_backend_export({ range = opts.range }, types.SnapPayloadType.image, "Exported image to: %s")
end

return M
