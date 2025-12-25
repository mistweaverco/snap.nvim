local M = {}
local types = require("snap.types")
local Logger = require("snap.logger")
local Backend = require("snap.backend")
local export = require("snap.export")

---Run the screenshot process
---@param opts SnapRunOptions|nil Options for running the screenshot
function M.run(opts)
  opts = opts or {}
  -- Default to image type if not specified
  opts.type = opts.type or types.SnapPayloadType.image

  Backend.ensure_installed(function()
    -- Prepare export options
    local export_opts = {
      range = opts.range,
      use_cache = opts.use_cache,
      use_ui_attach = opts.use_ui_attach,
    }

    -- If range is provided from command (visual mode), use it
    if opts.range then
      if opts.type == types.SnapPayloadType.image then
        export.image_to_clipboard(export_opts)
      elseif opts.type == types.SnapPayloadType.html then
        export.html_to_clipboard(export_opts)
      elseif opts.type == types.SnapPayloadType.rtf then
        export.rtf_to_clipboard(export_opts)
      else
        Logger.error("Unsupported export type: " .. tostring(opts.type))
      end
      return
    end
    if opts.type == types.SnapPayloadType.image then
      export.image_to_clipboard(export_opts)
    elseif opts.type == types.SnapPayloadType.html then
      export.html_to_clipboard(export_opts)
    elseif opts.type == types.SnapPayloadType.rtf then
      export.rtf_to_clipboard(export_opts)
    else
      Logger.error("Unsupported export type: " .. tostring(opts.type))
    end
  end)
end

-- Re-export export functions for backward compatibility
M.image_to_clipboard = export.image_to_clipboard
M.html_to_clipboard = export.html_to_clipboard
M.rtf_to_clipboard = export.rtf_to_clipboard
M.get_default_save_path = export.get_default_save_path

return M
