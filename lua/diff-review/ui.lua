local M = {}

local comments = require("diff-review.comments")
local config = require("diff-review.config")

-- Namespaces for highlights and signs
M.ns_id = vim.api.nvim_create_namespace("diff_review_comments")
M.cursor_ns_id = vim.api.nvim_create_namespace("diff_review_comment_cursor")
M.sign_group = "diff_review_comments"

-- Define sign for comments
local function define_signs()
  vim.fn.sign_define("DiffReviewComment", {
    text = "▸",
    texthl = "DiagnosticSignInfo",
    linehl = "",
    numhl = "",
  })

  vim.fn.sign_define("DiffReviewCommentRange", {
    text = "▸",
    texthl = "DiagnosticSignHint",
    linehl = "",
    numhl = "",
  })
end

-- Initialize UI
function M.init()
  define_signs()

  -- Define highlight groups
  vim.api.nvim_set_hl(0, "DiffReviewComment", { link = "Comment" })
  vim.api.nvim_set_hl(0, "DiffReviewCommentRange", { link = "Comment" })
end

-- Clear all comment UI for a buffer
function M.clear_comments(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  -- Clear virtual text
  vim.api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)
  vim.api.nvim_buf_clear_namespace(buf, M.cursor_ns_id, 0, -1)

  -- Clear signs
  vim.fn.sign_unplace(M.sign_group, { buffer = buf })
end

-- Format comment text for display
local function format_comment_text(comment)
  local lines = vim.split(comment.text, "\n")
  local formatted = {}

  -- Add prefix to each line
  for i, line in ipairs(lines) do
    if i == 1 then
      table.insert(formatted, "💬 " .. line)
    else
      table.insert(formatted, "   " .. line)
    end
  end

  return formatted
end

-- Update comment display for a buffer
function M.update_comment_display()
  local layout = require("diff-review.layout")
  local state = layout.get_state()

  if not state.is_open or not state.diff_buf or not vim.api.nvim_buf_is_valid(state.diff_buf) then
    return
  end

  -- Check if window is still valid
  if not state.diff_win or not vim.api.nvim_win_is_valid(state.diff_win) then
    return
  end

  -- Clear existing comments
  M.clear_comments(state.diff_buf)

  -- Get current file
  local file_list = require("diff-review.file_list")
  local files = file_list.state.files
  local current_index = file_list.state.current_index

  if #files == 0 or current_index < 1 or current_index > #files then
    return
  end

  local current_file = files[current_index].path
  local file_comments = comments.get_for_file(current_file)

  -- Debug: check if comments exist but aren't matching
  local all_comments = comments.get_all()
  if #all_comments > 0 and #file_comments == 0 then
    local comment_files = {}
    for _, c in ipairs(all_comments) do
      comment_files[c.file] = (comment_files[c.file] or 0) + 1
    end
    local msg = string.format("No comments match current file '%s'. Comments exist for:", current_file)
    for file, count in pairs(comment_files) do
      msg = msg .. string.format("\n  '%s' (%d)", file, count)
    end
    vim.notify(msg, vim.log.levels.WARN)
  end

  if #file_comments == 0 then
    return
  end

  -- Get buffer line count for validation
  local line_count = vim.api.nvim_buf_line_count(state.diff_buf)

  -- Track successfully placed comments
  local placed_count = 0
  local failed_comments = {}

  -- Place signs and virtual text for each comment
  for _, comment in ipairs(file_comments) do
    -- Validate line number
    if not comment.line or comment.line < 1 then
      table.insert(failed_comments, {
        id = comment.id,
        reason = string.format("Invalid line number: %s", tostring(comment.line))
      })
      goto continue
    end

    -- Clamp line number to buffer bounds instead of rejecting
    local display_line = math.min(comment.line, line_count)
    if display_line ~= comment.line then
      vim.notify(
        string.format("Comment #%d line %d out of bounds, clamped to %d", comment.id, comment.line, display_line),
        vim.log.levels.WARN
      )
      comment.line = display_line
    end

    local sign_name = comment.type == "range" and "DiffReviewCommentRange" or "DiffReviewComment"

    -- Place sign at the comment line (using display_line which is clamped)
    local ok, err = pcall(vim.fn.sign_place, comment.id, M.sign_group, sign_name, state.diff_buf, {
      lnum = display_line,
      priority = 10,
    })

    if not ok then
      table.insert(failed_comments, {
        id = comment.id,
        reason = string.format("Sign placement failed: %s", tostring(err))
      })
      goto continue
    end

    -- Add virtual text below the line (or end of range for range comments)
    local formatted_text = format_comment_text(comment)
    local virt_lines = {}
    for _, line in ipairs(formatted_text) do
      table.insert(virt_lines, { { line, "DiffReviewComment" } })
    end

    -- For range comments, display at the end of the range
    local virt_display_line = display_line
    if comment.type == "range" and comment.line_range then
      virt_display_line = math.min(comment.line_range["end"], line_count)
    end

    -- Virtual text uses 0-indexed line numbers
    ok, err = pcall(vim.api.nvim_buf_set_extmark, state.diff_buf, M.ns_id, virt_display_line - 1, 0, {
      virt_lines = virt_lines,
      virt_lines_above = false,
      hl_mode = "combine",
    })

    if not ok then
      table.insert(failed_comments, {
        id = comment.id,
        reason = string.format("Virtual text failed: %s", tostring(err))
      })
      goto continue
    end

    -- If it's a range comment, place signs on all lines in range
    if comment.type == "range" and comment.line_range then
      local range_start = math.max(comment.line_range.start + 1, 1)
      local range_end = math.min(comment.line_range["end"], line_count)

      for line = range_start, range_end do
        pcall(vim.fn.sign_place, comment.id * 1000 + line, M.sign_group, sign_name, state.diff_buf, {
          lnum = line,
          priority = 10,
        })
      end
    end

    placed_count = placed_count + 1

    ::continue::
  end

  -- Report any failures
  if #failed_comments > 0 then
    local msg = string.format("Failed to display %d comment(s):", #failed_comments)
    for _, failed in ipairs(failed_comments) do
      msg = msg .. string.format("\n  Comment #%d: %s", failed.id, failed.reason)
    end
    vim.notify(msg, vim.log.levels.WARN)
  end

  M.update_cursor_comment()
end

-- Show comment text at cursor line for visibility
function M.update_cursor_comment()
  local layout = require("diff-review.layout")
  local state = layout.get_state()

  if not state.is_open or not state.diff_buf or not vim.api.nvim_buf_is_valid(state.diff_buf) then
    return
  end
  if not state.diff_win or not vim.api.nvim_win_is_valid(state.diff_win) then
    return
  end

  vim.api.nvim_buf_clear_namespace(state.diff_buf, M.cursor_ns_id, 0, -1)

  local file_list = require("diff-review.file_list")
  local files = file_list.state.files
  local current_index = file_list.state.current_index
  if #files == 0 or current_index < 1 or current_index > #files then
    return
  end

  local current_file = files[current_index].path
  local cursor = vim.api.nvim_win_get_cursor(state.diff_win)
  local line = cursor[1]
  local line_comments = comments.get_at_line(current_file, line)
  if #line_comments == 0 then
    return
  end

  local virt_lines = {}
  for _, comment in ipairs(line_comments) do
    local formatted = format_comment_text(comment)
    for _, text in ipairs(formatted) do
      table.insert(virt_lines, { { text, "DiffReviewComment" } })
    end
  end

  pcall(vim.api.nvim_buf_set_extmark, state.diff_buf, M.cursor_ns_id, line - 1, 0, {
    virt_lines = virt_lines,
    virt_lines_above = true,
    hl_mode = "combine",
  })
end

-- Create a bordered window
function M.create_border(title)
  -- TODO: Implement custom border creation if needed
end

-- Apply color scheme
function M.apply_colors()
  local opts = config.get()
  -- Apply custom colors from config
  for name, hl_group in pairs(opts.ui.colors) do
    -- Colors are already defined, this is a placeholder for custom styling
  end
end

return M
