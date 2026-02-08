local M = {}

local comments = require("diff-review.comments")
local config = require("diff-review.config")

-- Namespaces for highlights and signs
M.ns_id = vim.api.nvim_create_namespace("diff_review_comments")
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

  if #file_comments == 0 then
    return
  end

  -- Place signs and virtual text for each comment
  for _, comment in ipairs(file_comments) do
    local sign_name = comment.type == "range" and "DiffReviewCommentRange" or "DiffReviewComment"

    -- Place sign at the comment line
    vim.fn.sign_place(
      comment.id,
      M.sign_group,
      sign_name,
      state.diff_buf,
      { lnum = comment.line, priority = 10 }
    )

    -- Add virtual text below the line
    local formatted_text = format_comment_text(comment)
    for i, line in ipairs(formatted_text) do
      vim.api.nvim_buf_set_extmark(state.diff_buf, M.ns_id, comment.line - 1 + i, 0, {
        virt_text = { { line, "DiffReviewComment" } },
        virt_text_pos = "eol",
        hl_mode = "combine",
      })
    end

    -- If it's a range comment, place signs on all lines in range
    if comment.type == "range" then
      for line = comment.line_range.start + 1, comment.line_range["end"] do
        vim.fn.sign_place(
          comment.id * 1000 + line,  -- Unique ID for each line
          M.sign_group,
          sign_name,
          state.diff_buf,
          { lnum = line, priority = 10 }
        )
      end
    end
  end
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
