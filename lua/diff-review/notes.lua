local M = {}

-- In-memory note storage
M.notes = {}
M.next_id = 1

-- Auto-save hook (set by note_mode module)
local auto_save_hook = nil

-- Note structure:
-- {
--   id = number,
--   file = string (file path),
--   line = number,
--   line_range = { start = number, end = number } (for range notes),
--   text = string (note text),
--   created_at = number (timestamp),
--   updated_at = number (timestamp),
--   type = "single" | "range",
--   set_name = string (note set name)
-- }

-- Generate unique note ID
local function generate_id()
  local id = M.next_id
  M.next_id = M.next_id + 1
  return id
end

-- Add a new note
function M.add(file, line, text, line_range, set_name)
  local new_id = generate_id()

  -- Safety check: ensure ID is unique
  local max_attempts = 1000
  local attempts = 0
  while M.get(new_id) and attempts < max_attempts do
    M.next_id = M.next_id + 1
    new_id = generate_id()
    attempts = attempts + 1
  end

  if attempts >= max_attempts then
    vim.notify("Failed to generate unique note ID", vim.log.levels.ERROR)
    return nil
  end

  local timestamp = os.time()
  local note = {
    id = new_id,
    file = file,
    line = line,
    text = text,
    created_at = timestamp,
    updated_at = timestamp,
    type = line_range and "range" or "single",
    set_name = set_name or "default",
  }

  if line_range then
    note.line_range = line_range
  end

  table.insert(M.notes, note)

  -- Trigger auto-save if enabled
  if auto_save_hook then
    auto_save_hook()
  end

  return note
end

-- Get note by ID
function M.get(id)
  for _, note in ipairs(M.notes) do
    if note.id == id then
      return note
    end
  end
  return nil
end

-- Get all notes for a file
function M.get_for_file(file)
  local file_notes = {}
  for _, note in ipairs(M.notes) do
    if note.file == file then
      table.insert(file_notes, note)
    end
  end
  return file_notes
end

-- Get notes for a file in a specific set
function M.get_for_file_in_set(file, set_name)
  local file_notes = {}
  for _, note in ipairs(M.notes) do
    if note.file == file and note.set_name == set_name then
      table.insert(file_notes, note)
    end
  end
  return file_notes
end

-- Get notes at a specific line
function M.get_at_line(file, line)
  local line_notes = {}
  for _, note in ipairs(M.notes) do
    if note.file == file then
      if note.type == "single" and note.line == line then
        table.insert(line_notes, note)
      elseif note.type == "range" and line >= note.line_range.start and line <= note.line_range["end"] then
        table.insert(line_notes, note)
      end
    end
  end
  return line_notes
end

-- Get notes at a specific line in a specific set
function M.get_at_line_in_set(file, line, set_name)
  local line_notes = {}
  for _, note in ipairs(M.notes) do
    if note.file == file and note.set_name == set_name then
      if note.type == "single" and note.line == line then
        table.insert(line_notes, note)
      elseif note.type == "range" and line >= note.line_range.start and line <= note.line_range["end"] then
        table.insert(line_notes, note)
      end
    end
  end
  return line_notes
end

-- Update a note
function M.update(id, new_text)
  local note = M.get(id)
  if not note then
    return false
  end

  note.text = new_text
  note.updated_at = os.time()

  -- Trigger auto-save if enabled
  if auto_save_hook then
    auto_save_hook()
  end

  return true
end

-- Delete a note
function M.delete(id)
  for i, note in ipairs(M.notes) do
    if note.id == id then
      table.remove(M.notes, i)

      -- Trigger auto-save if enabled
      if auto_save_hook then
        auto_save_hook()
      end

      return true
    end
  end
  return false
end

-- Delete all notes for a file
function M.delete_for_file(file)
  local i = 1
  local count = 0
  while i <= #M.notes do
    if M.notes[i].file == file then
      table.remove(M.notes, i)
      count = count + 1
    else
      i = i + 1
    end
  end
  return count
end

-- Get all notes
function M.get_all()
  return M.notes
end

-- Get all notes for a specific set
function M.get_for_set(set_name)
  local set_notes = {}
  for _, note in ipairs(M.notes) do
    if note.set_name == set_name then
      table.insert(set_notes, note)
    end
  end
  return set_notes
end

-- Clear all notes
function M.clear()
  M.notes = {}
  M.next_id = 1
end

-- Clear notes for a specific set
function M.clear_set(set_name)
  local i = 1
  local count = 0
  while i <= #M.notes do
    if M.notes[i].set_name == set_name then
      table.remove(M.notes, i)
      count = count + 1
    else
      i = i + 1
    end
  end

  -- Trigger auto-save if enabled
  if auto_save_hook then
    auto_save_hook()
  end

  return count
end

-- Load notes for a specific set
function M.load_set(set_name, notes_data)
  -- Clear existing notes for this set
  M.clear_set(set_name)

  -- Add new notes
  for _, note_data in ipairs(notes_data) do
    table.insert(M.notes, note_data)

    -- Update next_id to prevent collisions
    if note_data.id >= M.next_id then
      M.next_id = note_data.id + 1
    end
  end
end

-- Get statistics
function M.stats()
  local stats = {
    total = #M.notes,
    by_file = {},
    by_type = { single = 0, range = 0 },
    by_set = {},
  }

  for _, note in ipairs(M.notes) do
    -- Count by file
    if not stats.by_file[note.file] then
      stats.by_file[note.file] = 0
    end
    stats.by_file[note.file] = stats.by_file[note.file] + 1

    -- Count by type
    stats.by_type[note.type] = stats.by_type[note.type] + 1

    -- Count by set
    if not stats.by_set[note.set_name] then
      stats.by_set[note.set_name] = 0
    end
    stats.by_set[note.set_name] = stats.by_set[note.set_name] + 1
  end

  return stats
end

-- Set auto-save hook
function M.set_auto_save_hook(hook)
  auto_save_hook = hook
end

return M
