local M = {}

local notes = require("diff-review.notes")
local note_mode = require("diff-review.note_mode")
local note_ui = require("diff-review.note_ui")
local popup = require("diff-review.popup")
local git_utils = require("diff-review.git_utils")

-- Get current file path and buffer
local function get_current_file()
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  -- Only work with normal files
  if filepath == "" or vim.bo[bufnr].buftype ~= "" then
    return nil, nil
  end

  filepath = git_utils.normalize_file_key(filepath)

  return filepath, bufnr
end

-- Refresh display for current buffer
local function refresh_display()
  local filepath, bufnr = get_current_file()
  if not filepath then
    return
  end

  local state = note_mode.get_state()
  if state.is_active and state.visible then
    note_ui.update_display(bufnr, filepath, state.current_set)
  end
end

-- Add comment at cursor line
function M.add_comment()
  local state = note_mode.get_state()
  if not state.is_active then
    vim.notify("Note mode not active", vim.log.levels.WARN)
    return
  end

  local filepath, bufnr = get_current_file()
  if not filepath then
    vim.notify("Not in a valid file buffer", vim.log.levels.WARN)
    return
  end

  -- Get current line number
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  -- Open popup for comment input
  popup.open(nil, function(text)
    notes.add(filepath, line, text, nil, state.current_set)
    vim.notify(string.format("Comment added at line %d", line), vim.log.levels.INFO)

    -- Refresh display
    refresh_display()
  end)
end

-- Add comment for visual range
function M.add_range_comment()
  local state = note_mode.get_state()
  if not state.is_active then
    vim.notify("Note mode not active", vim.log.levels.WARN)
    return
  end

  local filepath, bufnr = get_current_file()
  if not filepath then
    vim.notify("Not in a valid file buffer", vim.log.levels.WARN)
    return
  end

  -- Capture the visual selection immediately before exiting visual mode
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
      notes.add(filepath, start_line, text, nil, state.current_set)
      vim.notify(string.format("Comment added at line %d", start_line), vim.log.levels.INFO)
      refresh_display()
    end)
    return
  end

  -- Open popup for range comment input
  popup.open(nil, function(text)
    local line_range = { start = start_line, ["end"] = end_line }
    notes.add(filepath, start_line, text, line_range, state.current_set)
    vim.notify(
      string.format("Range comment added for lines %d-%d", start_line, end_line),
      vim.log.levels.INFO
    )
    refresh_display()
  end)
end

-- Edit comment at cursor
function M.edit_comment()
  local state = note_mode.get_state()
  if not state.is_active then
    vim.notify("Note mode not active", vim.log.levels.WARN)
    return
  end

  local filepath, bufnr = get_current_file()
  if not filepath then
    vim.notify("Not in a valid file buffer", vim.log.levels.WARN)
    return
  end

  -- Get current line number
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  -- Find comment at this line
  local line_notes = notes.get_at_line_in_set(filepath, line, state.current_set)
  if #line_notes == 0 then
    vim.notify("No comment at this line", vim.log.levels.WARN)
    return
  end

  -- If multiple comments, use the first one
  local note = line_notes[1]

  -- Open popup with existing text
  popup.open(note.text, function(text)
    notes.update(note.id, text)
    vim.notify("Comment updated", vim.log.levels.INFO)
    refresh_display()
  end)
end

-- Delete comment at cursor
function M.delete_comment()
  local state = note_mode.get_state()
  if not state.is_active then
    vim.notify("Note mode not active", vim.log.levels.WARN)
    return
  end

  local filepath, bufnr = get_current_file()
  if not filepath then
    vim.notify("Not in a valid file buffer", vim.log.levels.WARN)
    return
  end

  -- Get current line number
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  -- Find comment at this line
  local line_notes = notes.get_at_line_in_set(filepath, line, state.current_set)
  if #line_notes == 0 then
    vim.notify("No comment at this line", vim.log.levels.WARN)
    return
  end

  -- If multiple comments, delete the first one
  local note = line_notes[1]

  -- Delete the comment
  notes.delete(note.id)
  vim.notify("Comment deleted", vim.log.levels.INFO)
  refresh_display()
end

-- List comments for current file
function M.list_file_comments()
  local state = note_mode.get_state()
  if not state.is_active then
    vim.notify("Note mode not active", vim.log.levels.WARN)
    return
  end

  local filepath, bufnr = get_current_file()
  if not filepath then
    vim.notify("Not in a valid file buffer", vim.log.levels.WARN)
    return
  end

  local file_notes = notes.get_for_file_in_set(filepath, state.current_set)
  if #file_notes == 0 then
    vim.notify("No comments for this file", vim.log.levels.INFO)
    return
  end

  -- Sort by line number
  table.sort(file_notes, function(a, b)
    return a.line < b.line
  end)

  -- Format as quickfix list
  local qf_items = {}
  for _, note in ipairs(file_notes) do
    local text
    if note.type == "range" then
      text = string.format("[L%d-L%d] %s", note.line_range.start, note.line_range["end"], note.text)
    else
      text = string.format("[L%d] %s", note.line, note.text)
    end

    table.insert(qf_items, {
      bufnr = bufnr,
      lnum = note.line,
      text = text,
      type = "I",
    })
  end

  vim.fn.setqflist(qf_items, "r")
  vim.cmd("copen")
  vim.notify(string.format("Found %d comments in %s", #file_notes, vim.fn.fnamemodify(filepath, ":t")), vim.log.levels.INFO)
end

-- View all comments in current set
function M.view_all_comments()
  local state = note_mode.get_state()
  if not state.is_active then
    vim.notify("Note mode not active", vim.log.levels.WARN)
    return
  end

  local all_notes = notes.get_for_set(state.current_set)
  if #all_notes == 0 then
    vim.notify(string.format("No comments in set '%s'", state.current_set), vim.log.levels.INFO)
    return
  end

  -- Sort by file and then line number
  table.sort(all_notes, function(a, b)
    if a.file ~= b.file then
      return a.file < b.file
    end
    return a.line < b.line
  end)

  -- Format as quickfix list
  local qf_items = {}
  for _, note in ipairs(all_notes) do
    local text
    if note.type == "range" then
      text = string.format("[L%d-L%d] %s", note.line_range.start, note.line_range["end"], note.text)
    else
      text = string.format("[L%d] %s", note.line, note.text)
    end

    table.insert(qf_items, {
      filename = note.file,
      lnum = note.line,
      text = text,
      type = "I",
    })
  end

  vim.fn.setqflist(qf_items, "r")
  vim.cmd("copen")

  -- Count files
  local files = {}
  for _, note in ipairs(all_notes) do
    files[note.file] = true
  end
  local file_count = 0
  for _ in pairs(files) do
    file_count = file_count + 1
  end

  vim.notify(
    string.format("Found %d comments in %d files (set: %s)", #all_notes, file_count, state.current_set),
    vim.log.levels.INFO
  )
end

return M
