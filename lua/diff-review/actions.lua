local M = {}

local comments = require("diff-review.comments")
local popup = require("diff-review.popup")

-- Get current file path from the diff view
local function get_current_file()
  local layout = require("diff-review.layout")
  local state = layout.get_state()

  if not state.is_open then
    return nil
  end

  -- Get current file from file list
  local file_list = require("diff-review.file_list")
  local files = file_list.state.files
  local current_index = file_list.state.current_index

  if #files == 0 or current_index < 1 or current_index > #files then
    return nil
  end

  return files[current_index].path
end

-- Add comment at cursor line
function M.add_comment_at_cursor()
  local file = get_current_file()
  if not file then
    vim.notify("No file selected", vim.log.levels.WARN)
    return
  end

  -- Get current line number
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  -- Open popup for comment input
  popup.open(nil, function(text)
    local comment = comments.add(file, line, text)
    vim.notify(string.format("Comment added at line %d", line), vim.log.levels.INFO)

    -- Update UI to show the comment
    M.refresh_comments()
  end)
end

-- Add comment for visual range
function M.add_comment_for_range()
  local file = get_current_file()
  if not file then
    vim.notify("No file selected", vim.log.levels.WARN)
    return
  end

  -- Capture the visual selection immediately before exiting visual mode
  -- Use vim.fn.getpos to get the actual current visual selection
  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")

  local start_line = start_pos[2]
  local end_line = end_pos[2]

  -- Validate selection
  if start_line == 0 or end_line == 0 then
    vim.notify("Invalid selection", vim.log.levels.WARN)
    return
  end

  -- Ensure proper order
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  -- Exit visual mode
  vim.cmd('normal! \\<Esc>')

  -- For single line, use single comment instead of range
  if start_line == end_line then
    popup.open(nil, function(text)
      comments.add(file, start_line, text, nil)
      vim.notify(
        string.format("Comment added at line %d", start_line),
        vim.log.levels.INFO
      )
      M.refresh_comments()
    end)
    return
  end

  -- Open popup for range comment input
  popup.open(nil, function(text)
    local line_range = { start = start_line, ["end"] = end_line }
    local comment = comments.add(file, start_line, text, line_range)
    vim.notify(
      string.format("Range comment added for lines %d-%d", start_line, end_line),
      vim.log.levels.INFO
    )

    -- Update UI to show the comment
    M.refresh_comments()
  end)
end

-- Edit comment at cursor
function M.edit_comment_at_cursor()
  local file = get_current_file()
  if not file then
    vim.notify("No file selected", vim.log.levels.WARN)
    return
  end

  -- Get current line number
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  -- Find comment at this line
  local line_comments = comments.get_at_line(file, line)
  if #line_comments == 0 then
    vim.notify("No comment at this line", vim.log.levels.WARN)
    return
  end

  -- If multiple comments, use the first one
  local comment = line_comments[1]

  -- Open popup with existing text
  popup.open(comment.text, function(text)
    comments.update(comment.id, text)
    vim.notify("Comment updated", vim.log.levels.INFO)

    -- Update UI
    M.refresh_comments()
  end)
end

-- Delete comment at cursor
function M.delete_comment_at_cursor()
  local file = get_current_file()
  if not file then
    vim.notify("No file selected", vim.log.levels.WARN)
    return
  end

  -- Get current line number
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  -- Find comment at this line
  local line_comments = comments.get_at_line(file, line)
  if #line_comments == 0 then
    vim.notify("No comment at this line", vim.log.levels.WARN)
    return
  end

  -- If multiple comments, show selection
  if #line_comments > 1 then
    vim.notify(string.format("Multiple comments found (%d), deleting first", #line_comments), vim.log.levels.INFO)
  end

  local comment = line_comments[1]
  comments.delete(comment.id)
  vim.notify("Comment deleted", vim.log.levels.INFO)

  -- Update UI
  M.refresh_comments()
end

-- Refresh comment display in UI
function M.refresh_comments()
  local ui = require("diff-review.ui")
  ui.update_comment_display()

  -- Auto-save comments
  local reviews = require("diff-review.reviews")
  reviews.save_current()
end

-- List all comments for current file
function M.list_comments()
  local file = get_current_file()
  if not file then
    vim.notify("No file selected", vim.log.levels.WARN)
    return
  end

  local file_comments = comments.get_for_file(file)
  if #file_comments == 0 then
    vim.notify("No comments for this file", vim.log.levels.INFO)
    return
  end

  -- Display comments
  local lines = { "Comments for " .. file .. ":", "" }
  for _, comment in ipairs(file_comments) do
    local line_info
    if comment.type == "range" then
      line_info = string.format("Lines %d-%d", comment.line_range.start, comment.line_range["end"])
    else
      line_info = string.format("Line %d", comment.line)
    end

    table.insert(lines, string.format("[%d] %s:", comment.id, line_info))
    table.insert(lines, "  " .. comment.text)
    table.insert(lines, "")
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

-- View all comments in quickfix list
function M.view_all_comments()
  local all_comments = comments.get_all()

  if #all_comments == 0 then
    vim.notify("No comments found", vim.log.levels.INFO)
    return
  end

  -- Build quickfix list items
  local qf_items = {}
  for _, comment in ipairs(all_comments) do
    local text = comment.text:gsub("\n", " ")  -- Replace newlines with spaces

    local lnum = comment.line
    local col = 1

    -- For range comments, note the range in the text
    if comment.type == "range" then
      text = string.format("[Lines %d-%d] %s", comment.line_range.start, comment.line_range["end"], text)
    end

    table.insert(qf_items, {
      filename = comment.file,
      lnum = lnum,
      col = col,
      text = text,
      type = "I",  -- Info type
    })
  end

  -- Set quickfix list
  vim.fn.setqflist(qf_items, "r")
  vim.fn.setqflist({}, "a", { title = "Diff Review Comments" })

  -- Open quickfix window
  vim.cmd("copen")

  vim.notify(string.format("Found %d comment(s)", #all_comments), vim.log.levels.INFO)
end

-- Open file at cursor with optional split mode
function M.open_file_at_cursor(split_mode)
  local diff = require("diff-review.diff")
  local file_list = require("diff-review.file_list")
  local layout = require("diff-review.layout")
  local state = layout.get_state()

  -- Get current file
  local files = file_list.state.files
  local current_index = file_list.state.current_index

  if #files == 0 or current_index < 1 or current_index > #files then
    vim.notify("No file selected", vim.log.levels.WARN)
    return
  end

  local file = files[current_index]

  -- Get line mapping at cursor
  local line_info = diff.get_file_line_at_cursor()

  if not line_info then
    vim.notify("Cannot determine file line at this position", vim.log.levels.WARN)
    return
  end

  -- Handle deleted lines
  if line_info.type == "delete" then
    vim.notify("Cannot navigate to deleted line", vim.log.levels.INFO)
    return
  end

  -- Handle header lines - use hunk start
  if line_info.type == "header" then
    if line_info.new_line then
      line_info.file_line = line_info.new_line
    else
      vim.notify("Cannot navigate from metadata line", vim.log.levels.WARN)
      return
    end
  end

  -- Handle deleted files
  if file.status == "D" then
    vim.notify("Cannot open deleted file: " .. file.path, vim.log.levels.INFO)
    return
  end

  -- Check if file exists
  local filepath = file.path
  if not vim.loop.fs_stat(filepath) then
    if file.status == "A" then
      vim.notify("New file not yet created: " .. filepath, vim.log.levels.ERROR)
    else
      vim.notify("File not found: " .. filepath, vim.log.levels.ERROR)
    end
    return
  end

  -- Store the original window to return to
  local original_win = state.original_win

  -- Close review UI
  local ui = require("diff-review.ui")
  ui.close()

  -- Return to original window if valid
  if original_win and vim.api.nvim_win_is_valid(original_win) then
    vim.api.nvim_set_current_win(original_win)
  end

  -- Open file with appropriate split mode
  if split_mode == "split" then
    vim.cmd("split " .. vim.fn.fnameescape(filepath))
  elseif split_mode == "vsplit" then
    vim.cmd("vsplit " .. vim.fn.fnameescape(filepath))
  else
    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
  end

  -- Jump to the mapped line and center
  if line_info.file_line and line_info.file_line > 0 then
    vim.api.nvim_win_set_cursor(0, { line_info.file_line, 0 })
    vim.cmd("normal! zz")
  end
end

-- Convenience function: open file in current window
function M.open_file()
  M.open_file_at_cursor(nil)
end

-- Convenience function: open file in horizontal split
function M.open_file_split()
  M.open_file_at_cursor("split")
end

-- Convenience function: open file in vertical split
function M.open_file_vsplit()
  M.open_file_at_cursor("vsplit")
end

return M
