local M = {}

local Globals = require("snap.globals")

local function platform()
  local system = vim.loop.os_uname().sysname
  local arch = vim.loop.os_uname().machine

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

---Download a file asynchronously
---@param url string URL to download from
---@param output_path string Path to save the file to
---@param callback function|nil Optional callback to run after download completes
local function download_file_async(url, output_path, callback)
  local cmd = { "curl", "-L", "-o", output_path, url }
  vim.system(
    cmd,
    {
      timeout = 60000,
      stdin = true,
      env = vim.fn.environ(),
      text = true,
    },
    vim.schedule_wrap(function(result)
      if result.stderr and result.stderr ~= "" then
        vim.notify("Error downloading snap.nvim backend: " .. vim.inspect(result.stderr), vim.log.levels.ERROR)
        return
      end
      if result.code ~= 0 then
        vim.notify("Download failed with exit code: " .. tostring(result.code), vim.log.levels.ERROR)
        return
      end
      make_executable(output_path)
      vim.notify("Snap.nvim backend installed to " .. output_path, vim.log.levels.INFO)
      if callback then
        callback()
      end
    end)
  )
end

---Download a file synchronously (blocking)
---@param url string URL to download from
---@param output_path string Path to save the file to
---@return boolean success Whether the download succeeded
local function download_file_sync(url, output_path)
  local cmd = { "curl", "-L", "-o", output_path, "--silent", "--show-error", url }
  local result = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error
  if exit_code ~= 0 then
    vim.notify("Failed to download snap.nvim backend: " .. result, vim.log.levels.ERROR)
    return false
  end
  make_executable(output_path)
  return true
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
  local required = get_required_version_tag()
  return installed == required
end

---Ensure the backend binary is installed and up-to-date
---If debug mode is enabled, skip the check (assumes running from source)
---If binary is not found or version doesn't match, download the required version
---@param debug table|nil Debug configuration (if set, skip auto-install)
M.ensure_installed = function(debug)
  -- In debug mode, we run from source, so skip binary check
  if debug ~= nil then
    return
  end

  local required_version = get_required_version_tag()

  -- Check if binary exists and version matches
  if binary_exists() and version_matches() then
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

  vim.notify(string.format("Snap.nvim: %s. Downloading %s...", reason, required_version), vim.log.levels.INFO)

  local plat = platform()
  local ext = IS_WINDOWS and ".exe" or ""
  local release_bin_name = "snap-nvim-" .. plat .. ext
  local url = string.format(
    "https://github.com/mistweaverco/snap.nvim/releases/download/%s/%s",
    required_version,
    release_bin_name
  )

  local bin_dir = M.get_bin_dir()
  vim.fn.mkdir(bin_dir, "p")

  local bin_name = M.get_bin_name()
  local bin_path = join_paths(bin_dir, bin_name)

  -- Use synchronous download for ensure_installed so the binary is ready immediately
  local success = download_file_sync(url, bin_path)
  if success then
    set_installed_version(required_version)
    vim.notify(string.format("Snap.nvim backend %s installed successfully!", required_version), vim.log.levels.INFO)
  end
end

---Manually install the backend binary
---@param version string|nil Version tag to install (e.g., "v1.0.0"), defaults to "latest"
---@param sync boolean|nil If true, download synchronously (blocking)
M.install = function(version, sync)
  version = version or "latest"
  local plat = platform()
  local ext = IS_WINDOWS and ".exe" or ""
  -- Binary name format: snap-nvim-{platform}{ext}
  -- e.g., snap-nvim-linux-x86_64, snap-nvim-windows-x86_64.exe
  local release_bin_name = "snap-nvim-" .. plat .. ext

  -- Handle "latest" specially - use the /latest/download/ URL redirect
  local url
  if version == "latest" then
    url = string.format("https://github.com/mistweaverco/snap.nvim/releases/latest/download/%s", release_bin_name)
  else
    url = string.format("https://github.com/mistweaverco/snap.nvim/releases/download/%s/%s", version, release_bin_name)
  end

  local bin_dir = M.get_bin_dir()
  vim.fn.mkdir(bin_dir, "p")

  local bin_name = M.get_bin_name()
  local bin_path = join_paths(bin_dir, bin_name)

  if sync then
    vim.notify("Downloading snap.nvim backend...", vim.log.levels.INFO)
    local success = download_file_sync(url, bin_path)
    if success then
      set_installed_version(version)
      vim.notify("Snap.nvim backend installed successfully!", vim.log.levels.INFO)
    end
  else
    vim.notify("Downloading snap.nvim backend...", vim.log.levels.INFO)
    download_file_async(url, bin_path, function()
      set_installed_version(version)
    end)
  end
end

return M
