-- Export module for generating markdown output from notes
local M = {}

local notes = require("diff-review.notes")
local note_mode = require("diff-review.note_mode")
local clipboard_utils = require("diff-review.clipboard_utils")

-- Format note with line information
local function format_note_line(note)
  if note.type == "range" then
    return string.format("- Lines %d-%d: %s", note.line_range.start, note.line_range["end"], note.text)
  else
    return string.format("- Line %d: %s", note.line, note.text)
  end
end

-- Format metadata header
local function format_metadata_header(set_name)
  local lines = {}

  table.insert(lines, "## Notes")
  table.insert(lines, "")
  table.insert(lines, string.format("**Note Set:** %s", set_name))

  -- Add timestamp
  local date = os.date("%Y-%m-%d %H:%M")
  table.insert(lines, string.format("**Date:** %s", date))

  table.insert(lines, "")
  table.insert(lines, "---")
  table.insert(lines, "")

  return table.concat(lines, "\n")
end

-- Export notes for the current set
function M.export_notes(set_name)
  if not set_name then
    local state = note_mode.get_state()
    if state.is_active then
      set_name = state.current_set
    else
      return nil, "Note mode not active and no set specified"
    end
  end

  local all_notes = notes.get_for_set(set_name)
  if #all_notes == 0 then
    return nil, "No notes to export"
  end

  -- Group notes by file
  local by_file = {}
  for _, note in ipairs(all_notes) do
    if not by_file[note.file] then
      by_file[note.file] = {}
    end
    table.insert(by_file[note.file], note)
  end

  -- Sort files alphabetically
  local files = {}
  for file, _ in pairs(by_file) do
    table.insert(files, file)
  end
  table.sort(files)

  -- Build markdown output with metadata header
  local lines = {}
  local header = format_metadata_header(set_name)
  for line in header:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  for _, file in ipairs(files) do
    table.insert(lines, string.format("### %s", file))
    table.insert(lines, "")

    -- Sort notes by line number
    table.sort(by_file[file], function(a, b)
      return a.line < b.line
    end)

    for _, note in ipairs(by_file[file]) do
      table.insert(lines, format_note_line(note))
    end
    table.insert(lines, "")
  end

  -- Add summary
  local total_notes = #all_notes
  local total_files = #files
  table.insert(lines, "---")
  table.insert(
    lines,
    string.format("**Total:** %d note%s across %d file%s",
      total_notes, total_notes == 1 and "" or "s",
      total_files, total_files == 1 and "" or "s")
  )

  return table.concat(lines, "\n")
end

-- Export notes with file content context
function M.export_notes_with_context(set_name)
  if not set_name then
    local state = note_mode.get_state()
    if state.is_active then
      set_name = state.current_set
    else
      return nil, "Note mode not active and no set specified"
    end
  end

  local all_notes = notes.get_for_set(set_name)
  if #all_notes == 0 then
    return nil, "No notes to export"
  end

  -- Group notes by file
  local by_file = {}
  for _, note in ipairs(all_notes) do
    if not by_file[note.file] then
      by_file[note.file] = {}
    end
    table.insert(by_file[note.file], note)
  end

  -- Sort files alphabetically
  local files = {}
  for file, _ in pairs(by_file) do
    table.insert(files, file)
  end
  table.sort(files)

  -- Build markdown output with metadata header
  local lines = {}
  local header = format_metadata_header(set_name)
  for line in header:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  for _, file in ipairs(files) do
    table.insert(lines, string.format("### %s", file))
    table.insert(lines, "")

    -- Try to read file content for context
    local file_content = {}
    local ok, result = pcall(function()
      local f, err = io.open(file, "r")
      if not f then
        error(string.format("Cannot open file: %s", err or "unknown error"))
      end
      for line in f:lines() do
        table.insert(file_content, line)
      end
      f:close()
      return true
    end)

    if not ok then
      vim.notify(string.format("Failed to read %s for code context: %s", file, tostring(result)), vim.log.levels.WARN)
    end

    -- Sort notes by line number
    table.sort(by_file[file], function(a, b)
      return a.line < b.line
    end)

    for _, note in ipairs(by_file[file]) do
      -- Add line reference
      if note.type == "range" then
        table.insert(lines, string.format("**Lines %d-%d:**", note.line_range.start, note.line_range["end"]))
      else
        table.insert(lines, string.format("**Line %d:**", note.line))
      end
      table.insert(lines, "")

      -- Add code context if file was readable
      if ok and result and #file_content > 0 then
        local start_line, end_line
        if note.type == "range" then
          start_line = note.line_range.start
          end_line = note.line_range["end"]
        else
          start_line = note.line
          end_line = note.line
        end

        -- Extract context (2 lines before and after)
        local context_start = math.max(1, start_line - 2)
        local context_end = math.min(#file_content, end_line + 2)

        -- Determine file extension for syntax highlighting
        local ext = file:match("%.([^%.]+)$") or ""
        table.insert(lines, "```" .. ext)

        for i = context_start, context_end do
          local prefix = ""
          if i >= start_line and i <= end_line then
            prefix = "> " -- Highlight the note lines
          else
            prefix = "  "
          end
          table.insert(lines, string.format("%s%d: %s", prefix, i, file_content[i]))
        end

        table.insert(lines, "```")
      else
        table.insert(lines, "```")
        table.insert(lines, "// Code context unavailable")
        table.insert(lines, "```")
      end
      table.insert(lines, "")

      -- Add note text
      table.insert(lines, string.format("> %s", note.text))
      table.insert(lines, "")
      table.insert(lines, "---")
      table.insert(lines, "")
    end
  end

  -- Add summary
  local total_notes = #all_notes
  local total_files = #files
  table.insert(lines, "")
  table.insert(
    lines,
    string.format("**Total:** %d note%s across %d file%s",
      total_notes, total_notes == 1 and "" or "s",
      total_files, total_files == 1 and "" or "s")
  )

  return table.concat(lines, "\n")
end

-- Copy to clipboard
function M.copy_to_clipboard(content)
  return clipboard_utils.copy_to_clipboard(content)
end

return M
