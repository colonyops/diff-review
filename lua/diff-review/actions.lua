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

  -- Get visual selection range
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")

  -- Ensure proper order
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  -- Open popup for comment input
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

return M
