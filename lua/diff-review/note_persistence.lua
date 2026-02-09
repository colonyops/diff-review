local M = {}

local git_utils = require("diff-review.git_utils")
local storage_utils = require("diff-review.storage_utils")

-- Get notes storage directory
local function get_notes_dir()
  local storage_dir = git_utils.get_storage_dir()
  return storage_dir .. "/notes"
end

-- Ensure notes storage directory exists
local function ensure_notes_dir()
  local dir = get_notes_dir()

  local ok, err = storage_utils.ensure_dir(dir)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
    return nil
  end

  return dir
end

-- Get storage file path for a note set
local function get_storage_path(set_name)
  local dir = ensure_notes_dir()
  return string.format("%s/%s.json", dir, set_name or "default")
end

-- Save notes to JSON
function M.save(notes, set_name)
  local path = get_storage_path(set_name)

  -- Convert notes to JSON-serializable format
  local data = {
    version = 1,
    set_name = set_name or "default",
    saved_at = os.time(),
    notes = notes,
  }

  local ok, err = storage_utils.write_json(path, data)
  if not ok then
    vim.notify(string.format("Failed to save notes: %s", err), vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Load notes from JSON
function M.load(set_name)
  local path = get_storage_path(set_name)

  -- Check if file exists
  if not storage_utils.file_exists(path) then
    return nil
  end

  -- Read and parse JSON
  local data, err = storage_utils.read_json(path)
  if not data then
    vim.notify(string.format("Failed to load notes: %s", err), vim.log.levels.ERROR)
    return nil
  end

  return data.notes
end

-- Delete saved notes for a set
function M.delete_set(set_name)
  local path = get_storage_path(set_name)

  if vim.fn.filereadable(path) == 1 then
    vim.fn.delete(path)
    return true
  end

  return false
end

-- List all saved note sets
function M.list_sets()
  local dir = get_notes_dir()

  if vim.fn.isdirectory(dir) == 0 then
    return {}
  end

  local files = vim.fn.glob(dir .. "/*.json", false, true)
  local sets = {}

  for _, file in ipairs(files) do
    local name = vim.fn.fnamemodify(file, ":t:r")
    table.insert(sets, name)
  end

  return sets
end

-- Auto-save notes for a set
function M.auto_save(notes, set_name)
  -- Only auto-save if there are notes
  if #notes == 0 then
    -- If no notes but file exists, delete it
    M.delete_set(set_name)
    return
  end

  M.save(notes, set_name)
end

-- Auto-load notes for a set
function M.auto_load(set_name)
  return M.load(set_name) or {}
end

-- Get notes directory path
function M.get_notes_dir()
  return get_notes_dir()
end

-- Get global storage directory (per-user, not per-repo)
local function get_global_storage_dir()
  local data_home = os.getenv("XDG_DATA_HOME")
  if not data_home or data_home == "" then
    data_home = vim.fn.expand("~/.local/share")
  end
  return data_home .. "/nvim/diff-review"
end

-- Ensure global storage directory exists
local function ensure_global_storage_dir()
  local dir = get_global_storage_dir()
  local ok, err = storage_utils.ensure_dir(dir)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
    return nil
  end
  return dir
end

-- Get global note session file path
local function get_global_note_session_path()
  local dir = ensure_global_storage_dir()
  return dir .. "/note_session.json"
end

-- Save global note session state
function M.save_global_session(state)
  local path = get_global_note_session_path()

  -- Prepare data with version and timestamp
  local data = {
    version = 1,
    saved_at = os.time(),
    state = state,
  }

  local ok, err = storage_utils.write_json(path, data)
  if not ok then
    vim.notify(string.format("Failed to save note session: %s", err), vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Load global note session state
function M.load_global_session()
  local path = get_global_note_session_path()

  -- Check if file exists
  if not storage_utils.file_exists(path) then
    return nil
  end

  -- Read and parse JSON
  local data, err = storage_utils.read_json(path)
  if not data then
    -- Empty file or parse error - warn but don't error
    if string.match(err, "Empty file") then
      return nil
    end
    vim.notify("Corrupted note session file, ignoring", vim.log.levels.WARN)
    return nil
  end

  if type(data) ~= "table" then
    vim.notify("Invalid note session data, ignoring", vim.log.levels.WARN)
    return nil
  end

  return data.state
end

-- Clear global note session state
function M.clear_global_session()
  local path = get_global_note_session_path()

  if vim.fn.filereadable(path) == 1 then
    vim.fn.delete(path)
    return true
  end

  return false
end

return M
