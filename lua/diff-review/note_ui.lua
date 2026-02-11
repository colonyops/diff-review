local M = {}

local notes = require("diff-review.notes")
local config = require("diff-review.config")

-- Priority constants for signs and extmarks
local SIGN_PRIORITY = 10
local VIRT_TEXT_PRIORITY = 100
local LINE_HIGHLIGHT_PRIORITY = 200

-- Separate namespace for notes (different from diff review comments)
M.ns_id = vim.api.nvim_create_namespace("diff_review_notes")
M.cursor_ns_id = vim.api.nvim_create_namespace("diff_review_note_cursor")
M.sign_group = "diff_review_notes"

-- Track which buffers have notes displayed
M.active_buffers = {}

-- Define signs for notes (reuse comment signs)
local function define_signs()
  vim.fn.sign_define("DiffReviewNote", {
    text = "▸",
    texthl = "DiffReviewCommentGutter",
    linehl = "",
    numhl = "DiffReviewCommentGutter",
  })

  vim.fn.sign_define("DiffReviewNoteRange", {
    text = "▸",
    texthl = "DiffReviewCommentRangeGutter",
    linehl = "",
    numhl = "DiffReviewCommentRangeGutter",
  })
end

-- Initialize UI (called on setup)
function M.init()
  define_signs()
end

-- Clear all note UI for a buffer
function M.clear_display(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Clear virtual text
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, M.cursor_ns_id, 0, -1)

  -- Clear signs
  vim.fn.sign_unplace(M.sign_group, { buffer = bufnr })

  -- Remove from active buffers
  M.active_buffers[bufnr] = nil
end

-- Clear all note displays across all buffers
function M.clear_all()
  for bufnr, _ in pairs(M.active_buffers) do
    M.clear_display(bufnr)
  end
  M.active_buffers = {}
end

-- Wrap a line of text at the specified width, preserving indentation
local function wrap_line(line, max_width, indent)
  if #line <= max_width then
    return { line }
  end

  local wrapped = {}
  local current = line

  while #current > max_width do
    -- Find the last space before max_width
    local wrap_pos = max_width
    for i = max_width, 1, -1 do
      if current:sub(i, i):match("%s") then
        wrap_pos = i
        break
      end
    end

    -- If no space found, hard break at max_width
    if wrap_pos == max_width and not current:sub(wrap_pos, wrap_pos):match("%s") then
      wrap_pos = max_width
    end

    -- Add the wrapped line
    table.insert(wrapped, current:sub(1, wrap_pos):match("^(.-)%s*$"))

    -- Continue with remainder, adding indent
    current = indent .. current:sub(wrap_pos + 1):match("^%s*(.*)$")
  end

  -- Add remaining text
  if #current > 0 then
    table.insert(wrapped, current)
  end

  return wrapped
end

-- Format note text for display
local function format_note_text(note)
  local opts = config.get()
  local max_width = opts.ui.text_wrap_width or 80
  local lines = vim.split(note.text, "\n")
  local formatted = {}

  -- Add line range header
  local line_info
  if note.type == "range" and note.line_range then
    line_info = string.format("  L%d-L%d", note.line_range.start, note.line_range["end"])
  else
    line_info = string.format("  L%d", note.line)
  end
  table.insert(formatted, line_info)

  -- Add note text lines with indentation and wrapping
  for _, line in ipairs(lines) do
    local prefixed_line = "   " .. line
    local wrapped = wrap_line(prefixed_line, max_width, "   ")
    for _, wrapped_line in ipairs(wrapped) do
      table.insert(formatted, wrapped_line)
    end
  end

  return formatted
end

-- Update note display for a buffer
function M.update_display(bufnr, filepath, set_name)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Clear existing notes
  M.clear_display(bufnr)

  -- Get notes for this file in this set
  local file_notes = notes.get_for_file_in_set(filepath, set_name)

  if #file_notes == 0 then
    return
  end

  -- Track that this buffer has notes
  M.active_buffers[bufnr] = true

  -- Get buffer line count for validation
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  -- Collect virtual text by display line to avoid overwriting on overlaps
  local virtual_by_line = {}

  -- Place signs and line highlights for each note
  for _, note in ipairs(file_notes) do
    -- Validate line number
    if not note.line or note.line < 1 then
      goto continue
    end

    -- Clamp line number to buffer bounds
    local display_line = math.min(note.line, line_count)
    if display_line ~= note.line then
      vim.notify(
        string.format("Note #%d line %d out of bounds, clamped to %d", note.id, note.line, display_line),
        vim.log.levels.WARN
      )
      note.line = display_line
    end

    local sign_name = note.type == "range" and "DiffReviewNoteRange" or "DiffReviewNote"

    -- Place sign at the note line
    local ok, err = pcall(vim.fn.sign_place, note.id, M.sign_group, sign_name, bufnr, {
      lnum = display_line,
      priority = SIGN_PRIORITY,
    })
    if not ok then
      vim.notify(string.format("Failed to place sign: %s", tostring(err)), vim.log.levels.WARN)
    end

    -- For range notes, display at the end of the range
    local virt_display_line = display_line
    if note.type == "range" and note.line_range then
      virt_display_line = math.min(note.line_range["end"], line_count)
    end

    if virt_display_line >= 1 and virt_display_line <= line_count then
      virtual_by_line[virt_display_line] = virtual_by_line[virt_display_line] or {}
      table.insert(virtual_by_line[virt_display_line], note)
    end

    -- If it's a range note, place signs on all lines in range
    if note.type == "range" and note.line_range then
      local range_start = math.max(note.line_range.start, 1)
      local range_end = math.min(note.line_range["end"], line_count)

      for line = range_start, range_end do
        local ok, err = pcall(vim.fn.sign_place, note.id * 1000 + line, M.sign_group, sign_name, bufnr, {
          lnum = line,
          priority = SIGN_PRIORITY,
        })
        if not ok then
          vim.notify(string.format("Failed to place range sign: %s", tostring(err)), vim.log.levels.WARN)
        end
        ok, err = pcall(vim.api.nvim_buf_set_extmark, bufnr, M.ns_id, line - 1, 0, {
          linehl = "DiffReviewCommentLine",
          hl_mode = "combine",
          priority = LINE_HIGHLIGHT_PRIORITY,
        })
        if not ok then
          vim.notify(string.format("Failed to set range extmark: %s", tostring(err)), vim.log.levels.WARN)
        end
      end
    else
      local ok, err = pcall(vim.api.nvim_buf_set_extmark, bufnr, M.ns_id, display_line - 1, 0, {
        linehl = "DiffReviewCommentLine",
        hl_mode = "combine",
        priority = 200,
      })
      if not ok then
        vim.notify(string.format("Failed to set line extmark: %s", tostring(err)), vim.log.levels.WARN)
      end
    end

    ::continue::
  end

  -- Render virtual text once per line to avoid overlap replacement
  for line, line_notes in pairs(virtual_by_line) do
    local virt_lines = {}
    for idx, note in ipairs(line_notes) do
      if idx > 1 then
        table.insert(virt_lines, { { "", "DiffReviewComment" } })
      end
      local formatted_text = format_note_text(note)
      for _, text in ipairs(formatted_text) do
        table.insert(virt_lines, { { text, "DiffReviewComment" } })
      end
    end

    local ok, err = pcall(vim.api.nvim_buf_set_extmark, bufnr, M.ns_id, line - 1, 0, {
      virt_lines = virt_lines,
      virt_lines_above = false,
      priority = VIRT_TEXT_PRIORITY,
    })
    if not ok then
      vim.notify(string.format("Failed to set virtual text: %s", tostring(err)), vim.log.levels.WARN)
    end
  end
end

return M
