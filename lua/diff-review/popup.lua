local M = {}

local config = require("diff-review.config")

-- State
M.state = {
  win = nil,
  buf = nil,
  callback = nil,
  initial_text = nil,
}

-- Calculate popup dimensions
local function get_popup_config()
  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.4)

  -- Minimum dimensions
  if width < 40 then width = 40 end
  if height < 10 then height = 10 end

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  return {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = config.get().ui.border,
    title = " Add Comment ",
    title_pos = "center",
  }
end

-- Close the popup
local function close_popup(save)
  if not M.state.win or not vim.api.nvim_win_is_valid(M.state.win) then
    M.state.win = nil
    M.state.buf = nil
    return
  end

  local text = nil
  if save and M.state.buf and vim.api.nvim_buf_is_valid(M.state.buf) then
    -- Get all lines from buffer
    local lines = vim.api.nvim_buf_get_lines(M.state.buf, 0, -1, false)
    text = table.concat(lines, "\n")

    -- Trim whitespace
    text = text:match("^%s*(.-)%s*$")

    -- Don't save empty comments
    if text == "" then
      text = nil
    end
  end

  -- Close window
  vim.api.nvim_win_close(M.state.win, true)
  M.state.win = nil

  -- Delete buffer
  if M.state.buf and vim.api.nvim_buf_is_valid(M.state.buf) then
    vim.api.nvim_buf_delete(M.state.buf, { force = true })
  end
  M.state.buf = nil

  -- Call callback
  if M.state.callback and text then
    M.state.callback(text)
  end

  M.state.callback = nil
  M.state.initial_text = nil
end

-- Setup keymaps for the popup
local function setup_keymaps(buf)
  local opts = { noremap = true, silent = true, buffer = buf }

  -- Save and close (normal mode)
  vim.keymap.set("n", "ZZ", function()
    close_popup(true)
  end, opts)

  -- Save with Ctrl-S (both insert and normal mode)
  vim.keymap.set({ "n", "i" }, "<C-s>", function()
    close_popup(true)
  end, opts)

  -- Save command
  vim.api.nvim_buf_create_user_command(buf, "Write", function()
    close_popup(true)
  end, {})
  vim.api.nvim_buf_create_user_command(buf, "W", function()
    close_popup(true)
  end, {})

  -- Cancel and close
  vim.keymap.set("n", "ZQ", function()
    close_popup(false)
  end, opts)

  vim.keymap.set("n", "q", function()
    close_popup(false)
  end, opts)

  -- Escape to cancel
  vim.keymap.set("n", "<Esc>", function()
    close_popup(false)
  end, opts)

  -- Allow normal :w to save
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      close_popup(true)
      return true
    end,
  })

  -- Also handle BufWritePre in case BufWriteCmd doesn't trigger
  vim.api.nvim_create_autocmd("BufWritePre", {
    buffer = buf,
    callback = function()
      close_popup(true)
      return true
    end,
  })
end

-- Open comment input popup
-- @param initial_text string (optional) - Initial text for editing
-- @param callback function - Called with comment text when saved
function M.open(initial_text, callback)
  -- Close existing popup if any
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    close_popup(false)
  end

  M.state.callback = callback
  M.state.initial_text = initial_text

  -- Create buffer
  M.state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(M.state.buf, "DiffReviewComment://comment")
  vim.api.nvim_buf_set_option(M.state.buf, "buftype", "acwrite")
  vim.api.nvim_buf_set_option(M.state.buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(M.state.buf, "swapfile", false)
  vim.api.nvim_buf_set_option(M.state.buf, "filetype", "markdown")
  vim.api.nvim_buf_set_option(M.state.buf, "modified", false)

  -- Set initial content
  if initial_text then
    local lines = vim.split(initial_text, "\n")
    vim.api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
  else
    -- Add helpful comment
    vim.api.nvim_buf_set_lines(M.state.buf, 0, -1, false, {
      "# Add your comment here",
      "",
      "",
    })
  end

  -- Create window
  local win_config = get_popup_config()
  M.state.win = vim.api.nvim_open_win(M.state.buf, true, win_config)

  -- Set window options
  vim.api.nvim_win_set_option(M.state.win, "wrap", true)
  vim.api.nvim_win_set_option(M.state.win, "linebreak", true)

  -- Setup keymaps
  setup_keymaps(M.state.buf)

  -- Position cursor
  if initial_text then
    -- Start at the beginning
    vim.api.nvim_win_set_cursor(M.state.win, { 1, 0 })
  else
    -- Skip the header line
    vim.api.nvim_win_set_cursor(M.state.win, { 3, 0 })
  end

  -- Enter insert mode
  vim.cmd("startinsert")
end

-- Check if popup is open
function M.is_open()
  return M.state.win ~= nil and vim.api.nvim_win_is_valid(M.state.win)
end

return M
