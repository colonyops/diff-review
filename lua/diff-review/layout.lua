local M = {}

local config = require("diff-review.config")

-- State
M.state = {
  is_open = false,
  file_list_win = nil,
  file_list_buf = nil,
  diff_win = nil,
  diff_buf = nil,
  original_win = nil,
}

-- Create a new scratch buffer
local function create_scratch_buffer(name)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  return buf
end

-- Calculate window dimensions
local function get_window_config()
  local opts = config.get()
  local width = vim.o.columns
  local height = vim.o.lines - vim.o.cmdheight - 2

  -- Ensure minimum dimensions
  if width < opts.layout.min_width then
    width = opts.layout.min_width
  end
  if height < opts.layout.min_height then
    height = opts.layout.min_height
  end

  return {
    width = width,
    height = height,
    file_list_width = opts.layout.file_list_width,
    diff_width = width - opts.layout.file_list_width - 1,
  }
end

-- Open the diff review layout
function M.open(review_type, base, head, pr_number)
  if M.state.is_open then
    return
  end

  -- Initialize review context
  local reviews = require("diff-review.reviews")
  local review = reviews.get_or_create(
    review_type or "uncommitted",
    base,
    head,
    pr_number
  )
  reviews.set_current(review)

  -- Save current window
  M.state.original_win = vim.api.nvim_get_current_win()

  -- Create buffers
  M.state.file_list_buf = create_scratch_buffer("DiffReview://file_list")
  M.state.diff_buf = create_scratch_buffer("DiffReview://diff")

  local win_config = get_window_config()
  local opts = config.get()

  -- Create a new tab
  vim.cmd("tabnew")
  local main_win = vim.api.nvim_get_current_win()

  -- Create file list window (left)
  vim.api.nvim_win_set_buf(main_win, M.state.file_list_buf)
  vim.api.nvim_win_set_width(main_win, win_config.file_list_width)
  M.state.file_list_win = main_win

  -- Set window options for file list
  vim.api.nvim_win_set_option(M.state.file_list_win, "number", false)
  vim.api.nvim_win_set_option(M.state.file_list_win, "relativenumber", false)
  vim.api.nvim_win_set_option(M.state.file_list_win, "signcolumn", "no")
  vim.api.nvim_win_set_option(M.state.file_list_win, "wrap", false)

  -- Create diff window (right)
  vim.cmd("vsplit")
  M.state.diff_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(M.state.diff_win, M.state.diff_buf)
  vim.api.nvim_win_set_width(M.state.diff_win, win_config.diff_width)

  -- Set window options for diff
  vim.api.nvim_win_set_option(M.state.diff_win, "wrap", false)
  vim.api.nvim_win_set_option(M.state.diff_win, "number", true)
  vim.api.nvim_win_set_option(M.state.diff_win, "relativenumber", false)

  -- Setup keymaps
  M.setup_keymaps()

  -- Focus file list
  vim.api.nvim_set_current_win(M.state.file_list_win)

  M.state.is_open = true

  -- Load file list
  require("diff-review.file_list").render()
end

-- Close the diff review layout
function M.close()
  if not M.state.is_open then
    return
  end

  -- Close the tab
  vim.cmd("tabclose")

  -- Clean up state
  M.state.is_open = false
  M.state.file_list_win = nil
  M.state.file_list_buf = nil
  M.state.diff_win = nil
  M.state.diff_buf = nil

  -- Return to original window if it still exists
  if M.state.original_win and vim.api.nvim_win_is_valid(M.state.original_win) then
    vim.api.nvim_set_current_win(M.state.original_win)
  end
  M.state.original_win = nil
end

-- Toggle the layout
function M.toggle()
  if M.state.is_open then
    M.close()
  else
    M.open()
  end
end

-- Setup keymaps for the windows
function M.setup_keymaps()
  local opts = config.get()
  local keymap_opts = { noremap = true, silent = true, buffer = M.state.file_list_buf }

  -- File list keymaps
  vim.keymap.set("n", opts.keymaps.close, M.close, keymap_opts)
  vim.keymap.set("n", opts.keymaps.next_file, require("diff-review.file_list").next_file, keymap_opts)
  vim.keymap.set("n", opts.keymaps.prev_file, require("diff-review.file_list").prev_file, keymap_opts)
  vim.keymap.set("n", opts.keymaps.select_file, require("diff-review.file_list").select_file, keymap_opts)
  vim.keymap.set("n", opts.keymaps.refresh, require("diff-review.file_list").refresh, keymap_opts)
  vim.keymap.set("n", opts.keymaps.toggle_fold, require("diff-review.file_list").toggle_fold, keymap_opts)
  vim.keymap.set("n", "<leader>t", require("diff-review.file_list").toggle_view_mode, keymap_opts)

  -- Diff window keymaps
  keymap_opts.buffer = M.state.diff_buf
  vim.keymap.set("n", opts.keymaps.close, M.close, keymap_opts)

  -- Comment actions (normal mode)
  local actions = require("diff-review.actions")
  vim.keymap.set("n", opts.keymaps.add_comment, actions.add_comment_at_cursor, keymap_opts)
  vim.keymap.set("n", opts.keymaps.edit_comment, actions.edit_comment_at_cursor, keymap_opts)
  vim.keymap.set("n", opts.keymaps.delete_comment, actions.delete_comment_at_cursor, keymap_opts)
  vim.keymap.set("n", opts.keymaps.list_comments, actions.list_comments, keymap_opts)
  vim.keymap.set("n", opts.keymaps.view_all_comments, actions.view_all_comments, keymap_opts)

  -- Comment actions (visual mode)
  vim.keymap.set("v", opts.keymaps.add_comment, actions.add_comment_for_range, keymap_opts)
end

-- Get current state
function M.get_state()
  return M.state
end

return M
