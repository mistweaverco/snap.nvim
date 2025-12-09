local M = {}

local function platform()
  local system = vim.loop.os_uname().sysname
  local arch = vim.loop.os_uname().machine

  local os
  if system == "Darwin" then
    os = "macos"
  elseif system == "Windows_NT" then
    os = "windows"
  else
    os = "linux"
  end

  return os .. "-" .. arch
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

local function download_file(url, output_path)
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
        error("Error downloading file: " .. vim.inspect(result.stderr))
      end
      if result.code ~= 0 then
        error("Process exited with code: " .. tostring(result.code))
      end
      make_executable(output_path)
      print("Snap.nvim installed to " .. output_path)
    end)
  )
end

M.ensure_installed = function(debug)
  if debug ~= nil then
    return
  end
  local bin_path = M.get_bin_path()
  local f = io.open(bin_path, "r")
  if f then
    f:close()
    return
  end
  M.get_installed_version()
end

M.install = function(version)
  version = version or "latest"
  local bin_name = M.get_bin_name()
  local url =
    string.format("https://github.com/mistweaverco/snap.nvim/releases/download/%s/%s-%s", version, bin_name, platform())

  local bin_dir = M.get_bin_dir()
  vim.fn.mkdir(bin_dir, "p")

  local bin_path = join_paths(bin_dir, bin_name)
  download_file(url, bin_path)
  set_installed_version(url:match("/download/([^/]+)/"))
end

return M
