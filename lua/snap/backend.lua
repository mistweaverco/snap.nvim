local Logger = require("snap.logger")
local Config = require("snap.config")
local M = {}

local DOWNLOAD_BASE_URL = "https://github.com/mistweaverco/snap.nvim/releases/download/%s/%s"

local Globals = require("snap.globals")

local function platform()
  local system = vim.uv.os_uname().sysname
  local arch = vim.uv.os_uname().machine

  local os_name
  if system == "Darwin" then
    os_name = "macos"
  elseif system == "Windows_NT" then
    os_name = "windows"
  else
    os_name = "linux"
  end

  -- Normalize architecture names to match release binary names
  local arch_name = arch
  if arch == "x86_64" or arch == "AMD64" then
    arch_name = "x86_64"
  elseif arch == "aarch64" or arch == "ARM64" then
    -- macOS uses "arm64" while Linux uses "aarch64"
    arch_name = os_name == "macos" and "arm64" or "aarch64"
  end

  return os_name .. "-" .. arch_name
end

local PATH_SEP = package.config:sub(1, 1)
local IS_WINDOWS = platform():match("windows")

local join_paths = function(...)
  return table.concat({ ... }, PATH_SEP)
end

M.get_bin_dir = function()
  local data = vim.fn.stdpath("data")
  return join_paths(data, "snap.nvim", "bin")
end

M.get_bin_name = function()
  local bin_name = "snap-nvim"
  if IS_WINDOWS then
    bin_name = bin_name .. ".exe"
  end
  return bin_name
end

M.get_bin_path = function()
  local bin_path = join_paths(M.get_bin_dir(), "snap-nvim")
  if platform():match("windows") then
    bin_path = bin_path .. ".exe"
  end
  return bin_path
end

local function make_executable(path)
  if not IS_WINDOWS then
    vim.fn.system({ "chmod", "+x", path })
  end
end

local get_version_path = function()
  return join_paths(M.get_bin_dir(), "version.txt")
end

M.get_installed_version = function()
  local version_file = get_version_path()
  local f = io.open(version_file, "r")
  if not f then
    return nil
  end
  local v = f:read("*l")
  f:close()
  return v
end

local set_installed_version = function(version)
  local version_file = get_version_path()
  local f = io.open(version_file, "w")
  if not f then
    error("Could not open version file for writing: " .. version_file)
  end
  f:write(version)
  f:close()
end

---Download a file asynchronously with progress display
---@param url string URL to download from
---@param output_path string Path to save the file to
---@param progress_callback function|nil Optional callback for progress updates: {progress: number, message: string}
---@param callback function|nil Optional callback to run after download completes
local function download_file_async(url, output_path, progress_callback, callback)
  -- Use curl with progress bar that outputs to stderr
  -- Format: %{url_effective}\n%{size_download}\n%{size_total}\n%{speed_download}\n%{time_total}
  -- We'll parse this to show percentage
  local cmd = {
    "curl",
    "-fL",
    "--progress-bar",
    "--write-out",
    "%{url_effective}\n%{size_download}\n%{size_total}\n%{speed_download}\n%{time_total}\n",
    "-o",
    output_path,
    url,
  }

  local stderr_buffer = ""
  local last_progress = 0

  local job_id = vim.fn.jobstart(cmd, {
    env = vim.fn.environ(),
    on_stdout = vim.schedule_wrap(function(_, data, _)
      -- Parse the write-out data from stdout
      if data and #data > 0 then
        local lines = {}
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(lines, line)
          end
        end
        if #lines >= 5 then
          local size_download = tonumber(lines[2]) or 0
          local size_total = tonumber(lines[3]) or 0
          local speed = tonumber(lines[4]) or 0
          local time_total = tonumber(lines[5]) or 0

          if size_total > 0 then
            local progress = math.floor((size_download / size_total) * 100)
            if progress ~= last_progress and progress_callback then
              local speed_mb = speed / 1024 / 1024
              local message = string.format("Downloading backend... %d%% (%.2f MB/s)", progress, speed_mb)
              progress_callback({ progress = progress, message = message })
              last_progress = progress
            end
          elseif size_download > 0 and progress_callback then
            -- Total size unknown, show downloaded size
            local downloaded_mb = size_download / 1024 / 1024
            local message = string.format("Downloading backend... %.2f MB", downloaded_mb)
            progress_callback({ progress = nil, message = message })
          end
        end
      end
    end),
    on_stderr = vim.schedule_wrap(function(_, data, _)
      -- curl progress bar goes to stderr, parse it for visual feedback
      if data and #data > 0 then
        for _, line in ipairs(data) do
          if line ~= "" then
            stderr_buffer = stderr_buffer .. line
            -- Parse curl progress: # characters indicate progress
            local hash_count = 0
            for char in line:gmatch("#") do
              hash_count = hash_count + 1
            end
            -- curl progress bar is 50 characters wide, so we can estimate progress
            if hash_count > 0 and progress_callback then
              local estimated_progress = math.min(100, math.floor((hash_count / 50) * 100))
              if estimated_progress ~= last_progress then
                progress_callback({
                  progress = estimated_progress,
                  message = string.format("Downloading backend... %d%%", estimated_progress),
                })
                last_progress = estimated_progress
              end
            end
          end
        end
      end
    end),
    on_exit = vim.schedule_wrap(function(_, exit_code, _)
      if exit_code ~= 0 then
        Logger.error("Download failed with exit code: " .. tostring(exit_code))
        if callback then
          callback()
        end
        return
      end

      -- Verify the file was actually downloaded
      local f = io.open(output_path, "r")
      if not f then
        Logger.error("Downloaded file not found at: " .. output_path)
        if callback then
          callback()
        end
        return
      end
      f:close()
      make_executable(output_path)
      if progress_callback then
        progress_callback({ progress = 100, message = "Download completed!" })
      end
      Logger.notify("Snap.nvim backend downloaded successfully!", Logger.LoggerLogLevels.info)
      if callback then
        callback()
      end
    end),
    stdout_buffered = false,
    stderr_buffered = false,
  })

  if job_id <= 0 then
    Logger.error("Failed to start download process")
    if callback then
      callback()
    end
  end
end

---Check if binary exists
---@return boolean exists Whether the binary file exists
local function binary_exists()
  local bin_path = M.get_bin_path()
  local f = io.open(bin_path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

---Get the required backend version tag (without "v" prefix)
---@return string version_tag Version tag like "1.0.0"
local function get_required_version()
  return Globals.BACKEND_VERSION
end

---Get the required backend version tag (with "v" prefix for GitHub releases)
---@return string version_tag Version tag like "v1.0.0"
local function get_required_version_tag()
  return "v" .. Globals.BACKEND_VERSION
end

---Check if the installed version matches the required version
---@return boolean matches True if versions match, false otherwise
local function version_matches()
  local installed = M.get_installed_version()
  if not installed then
    return false
  end
  local required = get_required_version()
  return installed == required
end

---Extract zip archive asynchronously with progress
---@param archive_path string Path to the zip file
---@param extract_dir string Directory to extract to
---@param progress_callback function|nil Optional callback for progress updates
---@param callback function|nil Optional callback to run after extraction completes
local function extract_zip_async(archive_path, extract_dir, progress_callback, callback)
  -- Use unzip with verbose output to show progress
  -- -v: verbose, -o: overwrite, -d: extract to directory
  local cmd = { "unzip", "-o", "-v", archive_path, "-d", extract_dir }

  local total_files = 0
  local extracted_files = 0
  local last_progress = 0

  local job_id = vim.fn.jobstart(cmd, {
    env = vim.fn.environ(),
    on_stdout = vim.schedule_wrap(function(_, data, _)
      if data and #data > 0 then
        for _, line in ipairs(data) do
          if line ~= "" then
            -- Parse unzip verbose output
            -- Look for "Archive:" line to get total files
            if line:match("^Archive:") then
              -- Next lines will show file count
            elseif line:match("^%s+%d+ files") then
              -- Extract total file count: "  1234 files"
              local count = line:match("(%d+) files")
              if count then
                total_files = tonumber(count) or 0
              end
            elseif line:match("^%s+inflating:") or line:match("^%s+extracting:") then
              -- Count extracted files
              extracted_files = extracted_files + 1
              if total_files > 0 and progress_callback then
                local progress = math.floor((extracted_files / total_files) * 100)
                if progress ~= last_progress then
                  progress_callback({
                    progress = progress,
                    message = string.format(
                      "Extracting backend... %d%% (%d/%d files)",
                      progress,
                      extracted_files,
                      total_files
                    ),
                  })
                  last_progress = progress
                end
              end
            end
          end
        end
      end
    end),
    on_stderr = vim.schedule_wrap(function(_, data, _)
      -- unzip sends some info to stderr, we can parse it too
      if data and #data > 0 then
        for _, line in ipairs(data) do
          if line ~= "" and progress_callback then
            -- Show generic progress if we can't parse specific progress
            if not line:match("^Archive:") and not line:match("^%s+%d+ files") then
              progress_callback({
                progress = nil,
                message = "Extracting backend...",
              })
            end
          end
        end
      end
    end),
    on_exit = vim.schedule_wrap(function(_, exit_code, _)
      if exit_code ~= 0 then
        Logger.error("Failed to extract zip archive with exit code: " .. tostring(exit_code))
        if callback then
          callback(false)
        end
        return
      end

      if progress_callback then
        progress_callback({ progress = 100, message = "Extraction completed!" })
      end
      if callback then
        callback(true)
      end
    end),
    stdout_buffered = false,
    stderr_buffered = false,
  })

  if job_id <= 0 then
    Logger.error("Failed to start extraction process")
    if callback then
      callback(false)
    end
  end
end

---Extract tar.gz archive asynchronously with progress
---@param archive_path string Path to the tar.gz file
---@param extract_dir string Directory to extract to
---@param progress_callback function|nil Optional callback for progress updates
---@param callback function|nil Optional callback to run after extraction completes
local function extract_tar_gz_async(archive_path, extract_dir, progress_callback, callback)
  -- Try to use pv (pipe viewer) if available for better progress
  -- Otherwise fallback to tar with verbose output
  local use_pv = vim.fn.executable("pv") == 1
  local tar_cmd

  if use_pv then
    -- Get archive size for pv
    local archive_size = vim.fn.getfsize(archive_path)
    if archive_size > 0 then
      -- Use pv with percentage output (-n for numeric, -p for percentage)
      tar_cmd = {
        "sh",
        "-c",
        string.format("pv -p %s | tar -xzf - -C %s", vim.fn.shellescape(archive_path), vim.fn.shellescape(extract_dir)),
      }
    else
      use_pv = false
    end
  end

  if not use_pv then
    -- Fallback to tar with verbose output (shows file names as they're extracted)
    tar_cmd = { "tar", "-xzvf", archive_path, "-C", extract_dir }
  end

  local last_progress = 0

  local job_id = vim.fn.jobstart(tar_cmd, {
    env = vim.fn.environ(),
    on_stdout = vim.schedule_wrap(function(_, data, _)
      if data and #data > 0 then
        for _, line in ipairs(data) do
          if line ~= "" then
            if use_pv then
              -- Parse pv output: percentage (format: "100%")
              local percent = line:match("(%d+)%%")
              if percent and progress_callback then
                local progress = tonumber(percent) or 0
                if progress ~= last_progress then
                  progress_callback({
                    progress = progress,
                    message = string.format("Extracting backend... %d%%", progress),
                  })
                  last_progress = progress
                end
              end
            else
              -- Parse tar verbose output - show file being extracted
              if line:match("^x ") and progress_callback then
                -- Extract filename from "x path/to/file"
                local filename = line:match("^x (.+)$")
                if filename then
                  -- Show progress with current file
                  local short_name = filename:match("([^/]+)$") or filename
                  progress_callback({
                    progress = nil,
                    message = string.format("Extracting backend... %s", short_name),
                  })
                end
              end
            end
          end
        end
      end
    end),
    on_stderr = vim.schedule_wrap(function(_, data, _)
      -- tar sends verbose output to stderr
      if data and #data > 0 and not use_pv then
        for _, line in ipairs(data) do
          if line ~= "" and progress_callback then
            -- Show generic progress
            progress_callback({
              progress = nil,
              message = "Extracting backend...",
            })
          end
        end
      end
    end),
    on_exit = vim.schedule_wrap(function(_, exit_code, _)
      if exit_code ~= 0 then
        Logger.error("Failed to extract tar.gz archive with exit code: " .. tostring(exit_code))
        if callback then
          callback(false)
        end
        return
      end

      if progress_callback then
        progress_callback({ progress = 100, message = "Extraction completed!" })
      end
      if callback then
        callback(true)
      end
    end),
    stdout_buffered = false,
    stderr_buffered = false,
  })

  if job_id <= 0 then
    Logger.error("Failed to start extraction process")
    if callback then
      callback(false)
    end
  end
end

---Move extracted files to correct locations
---@param temp_dir string Temporary extraction directory
---@param bin_dir string Directory where binary should be installed
---@return boolean success Whether setup was successful
local function move_extracted_files(temp_dir, bin_dir)
  -- Find the binary and playwright directory in extracted files
  -- Archive structure: snap-nvim-{platform}{ext} and playwright/ at root level
  local plat = platform()
  local ext = IS_WINDOWS and ".exe" or ""
  local release_bin_name = "snap-nvim-" .. plat .. ext
  local bin_path = M.get_bin_path()
  local playwright_dir = join_paths(bin_dir, "playwright")

  local found_binary = false
  local found_playwright = false

  -- Look for binary at root of temp directory (archive extracts to root)
  local temp_binary = join_paths(temp_dir, release_bin_name)
  if vim.fn.filereadable(temp_binary) == 1 then
    -- Move binary to final location
    vim.fn.rename(temp_binary, bin_path)
    make_executable(bin_path)
    found_binary = true
  end

  -- Look for playwright directory at root of temp directory
  local temp_playwright = join_paths(temp_dir, "playwright")
  if vim.fn.isdirectory(temp_playwright) == 1 then
    -- Remove old playwright directory if it exists
    if vim.fn.isdirectory(playwright_dir) == 1 then
      vim.fn.delete(playwright_dir, "rf")
    end
    -- Move playwright directory to final location
    vim.fn.rename(temp_playwright, playwright_dir)
    found_playwright = true
  end

  -- Clean up temp directory
  vim.fn.delete(temp_dir, "rf")

  if not found_binary then
    Logger.error("Binary not found in extracted archive")
    return false
  end

  -- Playwright directory is optional (for backwards compatibility)
  if found_playwright then
    Logger.notify("Playwright bundled with backend", Logger.LoggerLogLevels.info)
  end

  return true
end

---Extract downloaded archive and move files to correct locations asynchronously
---@param archive_path string Path to the downloaded archive
---@param bin_dir string Directory where binary should be installed
---@param progress_callback function|nil Optional callback for progress updates
---@param callback function|nil Optional callback to run after extraction and setup completes
local function extract_and_setup_async(archive_path, bin_dir, progress_callback, callback)
  -- Create temporary extraction directory
  local temp_dir = join_paths(bin_dir, "temp_extract")
  vim.fn.mkdir(temp_dir, "p")

  -- Extract based on archive type
  local extract_callback = function(success)
    if not success then
      -- Clean up temp directory
      vim.fn.delete(temp_dir, "rf")
      if callback then
        callback(false)
      end
      return
    end

    -- Move files to correct locations
    local setup_success = move_extracted_files(temp_dir, bin_dir)
    if callback then
      callback(setup_success)
    end
  end

  if archive_path:match("%.zip$") then
    extract_zip_async(archive_path, temp_dir, progress_callback, extract_callback)
  elseif archive_path:match("%.tar%.gz$") then
    extract_tar_gz_async(archive_path, temp_dir, progress_callback, extract_callback)
  else
    Logger.error("Unknown archive format: " .. archive_path)
    vim.fn.delete(temp_dir, "rf")
    if callback then
      callback(false)
    end
  end
end

---Manually install the backend binary
---@param version string|nil Version tag to install (e.g., "v1.0.0"), defaults to "latest"
---@param callback function|nil Optional callback to run after installation
M.install = function(version, callback)
  version = version or "latest"
  local plat = platform()
  local version_tag = version:match("^v") and version ~= "latest" and version or "v" .. version
  version = version:match("^v") and version:sub(2) or version

  -- Archive name format: snap-nvim-{platform}.{ext}
  -- Windows: snap-nvim-windows-x86_64.zip
  -- Linux/Mac: snap-nvim-linux-x86_64.tar.gz
  local archive_ext = IS_WINDOWS and ".zip" or ".tar.gz"
  local release_archive_name = "snap-nvim-" .. plat .. archive_ext

  -- Handle "latest" specially - use the /latest/download/ URL redirect
  local url
  if version == "latest" then
    url = string.format(DOWNLOAD_BASE_URL, "latest", release_archive_name)
  else
    url = string.format(DOWNLOAD_BASE_URL, version_tag, release_archive_name)
  end

  local bin_dir = M.get_bin_dir()
  vim.fn.mkdir(bin_dir, "p")

  -- Download to temporary archive file
  local archive_path = join_paths(bin_dir, release_archive_name)

  download_file_async(url, archive_path, function(progress)
    -- Show progress updates for download
    if progress.progress then
      Logger.notify(progress.message, Logger.LoggerLogLevels.info)
    else
      Logger.notify(progress.message, Logger.LoggerLogLevels.info)
    end
  end, function()
    -- Extract archive after download with progress
    extract_and_setup_async(archive_path, bin_dir, function(progress)
      -- Show progress updates for extraction
      if progress.progress then
        Logger.notify(progress.message, Logger.LoggerLogLevels.info)
      else
        Logger.notify(progress.message, Logger.LoggerLogLevels.info)
      end
    end, function(success)
      -- Clean up archive file
      if vim.fn.filereadable(archive_path) == 1 then
        vim.fn.delete(archive_path)
      end

      if success then
        set_installed_version(version)
        Logger.notify("Backend installed successfully!", Logger.LoggerLogLevels.info)
        if callback then
          callback()
        end
      else
        Logger.error("Failed to extract backend archive")
        if callback then
          callback()
        end
      end
    end)
  end)
end

---Ensure the backend binary is installed and up-to-date
---If development mode is enabled, skip the check (assumes running from source)
---If binary is not found or version doesn't match, download the required version
---@param callback function|nil Optional callback to run after installation
M.ensure_installed = function(callback)
  local user_config = Config.get()
  -- Development mode and a backend specified - skip installation
  if user_config.development_mode ~= nil and user_config.development_mode.backend ~= nil then
    if callback then
      callback()
    end
    return
  end

  local required_version = get_required_version()
  local required_version_tag = get_required_version_tag()

  -- Check if binary exists and version matches
  if binary_exists() and version_matches() then
    if callback then
      callback()
    end
    return
  end

  -- Determine reason for download
  local reason
  if not binary_exists() then
    reason = "Backend not found"
  else
    local installed = M.get_installed_version() or "unknown"
    reason = string.format("Version mismatch (installed: %s, required: %s)", installed, required_version)
  end

  Logger.notify(string.format("%s. Downloading %s...", reason, required_version), Logger.LoggerLogLevels.info)
  M.install(required_version_tag, function()
    -- Verify the binary was successfully installed before calling the callback
    if binary_exists() and version_matches() then
      if callback then
        callback()
      end
    else
      Logger.error("Backend installation failed or binary is not accessible")
      if callback then
        callback()
      end
    end
  end)
end

return M
