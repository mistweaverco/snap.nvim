local M = {}
local IS_WINDOWS = vim.uv.os_uname().version:match("Windows")

M.join_paths = function(...)
  local paths = { ... }
  return table.concat(paths, IS_WINDOWS and "\\" or "/")
end

---Write content to a file
---@param file_path string full path to the file
---@param content string content to write
---@return boolean success
M.write_file = function(file_path, content)
  local filehandle = io.open(file_path, "w")
  if not filehandle then
    return false
  end
  filehandle:write(content)
  filehandle:close()
  return true
end

---Append content to a file
---@param file_path string full path to the file
---@param content string content to append
---@return boolean success
M.append_contents_to_file = function(file_path, content)
  local filehandle = io.open(file_path, "a")
  if not filehandle then
    return false
  end
  filehandle:write(content)
  filehandle:close()
  return true
end

return M
