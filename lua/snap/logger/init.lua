local Globals = require("snap.globals")
local Config = require("snap.config")
local M = {}

---@enum SnapLoggerLogLevelNames
M.LoggerLogLevelNames = {
  trace = "trace",
  debug = "debug",
  info = "info",
  warn = "warn",
  error = "error",
  off = "off",
}

---@enum SnapLoggerLogLevels
M.LoggerLogLevels = {
  trace = vim.log.levels.TRACE,
  debug = vim.log.levels.DEBUG,
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
  error = vim.log.levels.ERROR,
  off = vim.log.levels.OFF,
}

local is_table = function(value)
  return type(value) == "table"
end

--- Format log message from multiple arguments
--- @param ... any Multiple arguments to format into a log message
--- @return string Formatted log message
local get_log_message = function(...)
  local args = { ... }
  local message = table.concat(
    vim.tbl_map(function(arg)
      if is_table(arg) then
        return vim.inspect(arg)
      else
        return tostring(arg)
      end
    end, args),
    " "
  )
  return message
end

local LOG_LEVEL = nil

--- Determine if a message should be logged based on its level
--- @param level SnapLoggerLogLevels The log level of the message
local function should_log(level)
  if level == nil then
    M.error("Invalid log level: " .. tostring(level))
    return false
  end
  local conf = Config.get()
  if LOG_LEVEL == nil and conf.debug and conf.debug.log_level ~= nil then
    LOG_LEVEL = conf.debug.log_level
  end
  return LOG_LEVEL ~= nil and level >= M.LoggerLogLevels[LOG_LEVEL]
end

--- Print log message to console
--- @param ... any Multiple arguments to log
--- @return nil
local logger_print = function(level, ...)
  vim.notify(get_log_message(...), level, { title = Globals.NAME })
end

--- Log a message at info level
--- @param ... any Multiple arguments to log
--- @deprecated Use M.info instead
--- @return nil
M.log = function(...)
  if not should_log(M.LoggerLogLevels.info) then
    return
  end
  logger_print(M.LoggerLogLevelNames.info, ...)
end

--- Log a message at info level
--- @param ... any Multiple arguments to log
--- @return nil
M.info = function(...)
  if not should_log(M.LoggerLogLevels.info) then
    return
  end
  logger_print(M.LoggerLogLevelNames.info, ...)
end

--- Log a message at warn level
--- @param ... any Multiple arguments to log
--- @return nil
M.warn = function(...)
  if not should_log(M.LoggerLogLevels.warn) then
    return
  end
  logger_print(M.LoggerLogLevelNames.warn, ...)
end

--- Log a message at error level
--- @param ... any Multiple arguments to log
--- @return nil
M.error = function(...)
  if not should_log(M.LoggerLogLevels.error) then
    return
  end
  logger_print(M.LoggerLogLevelNames.error, ...)
end

--- Log a message at debug level
--- @param ... any Multiple arguments to log
--- @return nil
M.debug = function(...)
  if not should_log(M.LoggerLogLevels.debug) then
    return
  end
  logger_print(M.LoggerLogLevelNames.debug, ...)
end

--- Generic notification function
--- @param message string The notification message
--- @param level SnapLoggerLogLevels The log level ("error", "warn", "info", "debug")
M.notify = function(message, level)
  local conf = Config.get()
  if conf.notify.enabled == false then
    return
  end
  if conf.notify.provider == "print" then
    print("[" .. Globals.NAME .. "] [" .. level .. "] " .. message)
    return
  end
  vim.notify(message, M.LoggerLogLevels[level] or M.LoggerLogLevels.info, { title = Globals.NAME })
end

return M
