local M = {}

-- Copy content to clipboard
-- Returns: (boolean, error_string|nil)
function M.copy_to_clipboard(content)
  if not content then
    return false, "No content to copy"
  end

  -- Try Neovim's built-in clipboard provider first
  if vim.fn.has("clipboard") == 1 then
    local ok, err = pcall(vim.fn.setreg, "+", content)
    if not ok then
      return false, string.format("Failed to use clipboard provider: %s", tostring(err))
    end
    return true, nil
  end

  -- Fall back to external clipboard commands
  local clip_cmd
  if vim.fn.executable("pbcopy") == 1 then
    -- macOS
    clip_cmd = "pbcopy"
  elseif vim.fn.executable("xclip") == 1 then
    -- Linux (X11)
    clip_cmd = "xclip -selection clipboard"
  elseif vim.fn.executable("wl-copy") == 1 then
    -- Linux (Wayland)
    clip_cmd = "wl-copy"
  else
    return false, "No clipboard utility available (clipboard, pbcopy, xclip, or wl-copy)"
  end

  -- Write to clipboard using external command
  local handle = io.popen(clip_cmd, "w")
  if not handle then
    return false, string.format("Failed to open clipboard command: %s", clip_cmd)
  end

  local write_ok, write_err = pcall(function()
    handle:write(content)
  end)

  handle:close()

  if not write_ok then
    return false, string.format("Failed to write to %s: %s", clip_cmd, tostring(write_err))
  end

  return true, nil
end

return M
