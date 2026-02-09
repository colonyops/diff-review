local M = {}

-- Get notes storage directory
local function get_notes_dir()
  -- Try to find git root
  local git_dir = vim.fn.system("git rev-parse --git-dir 2>/dev/null"):gsub("\n", "")

  local base_dir
  if vim.v.shell_error ~= 0 or git_dir == "" then
    -- Fallback to current directory
    base_dir = vim.fn.getcwd() .. "/.diff-review"
  else
    base_dir = git_dir .. "/diff-review"
  end

  return base_dir .. "/notes"
end

-- Ensure notes storage directory exists
local function ensure_notes_dir()
  local dir = get_notes_dir()

  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
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

  local json = vim.fn.json_encode(data)

  -- Write to file
  local file = io.open(path, "w")
  if not file then
    vim.notify("Failed to save notes: " .. path, vim.log.levels.ERROR)
    return false
  end

  file:write(json)
  file:close()

  return true
end

-- Load notes from JSON
function M.load(set_name)
  local path = get_storage_path(set_name)

  -- Check if file exists
  if vim.fn.filereadable(path) == 0 then
    return nil
  end

  -- Read file
  local file = io.open(path, "r")
  if not file then
    vim.notify("Failed to load notes: " .. path, vim.log.levels.ERROR)
    return nil
  end

  local content = file:read("*a")
  file:close()

  -- Parse JSON
  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or not data then
    vim.notify("Failed to parse notes file: " .. path, vim.log.levels.ERROR)
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
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
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

  local json = vim.fn.json_encode(data)

  -- Write to file with error handling
  local file, err = io.open(path, "w")
  if not file then
    vim.notify("Failed to save note session: " .. (err or "unknown error"), vim.log.levels.ERROR)
    return false
  end

  file:write(json)
  file:close()

  return true
end

-- Load global note session state
function M.load_global_session()
  local path = get_global_note_session_path()

  -- Check if file exists
  if vim.fn.filereadable(path) == 0 then
    return nil
  end

  -- Read file
  local file, err = io.open(path, "r")
  if not file then
    vim.notify("Failed to load note session: " .. (err or "unknown error"), vim.log.levels.WARN)
    return nil
  end

  local content = file:read("*a")
  file:close()

  -- Handle empty file
  if not content or content == "" then
    return nil
  end

  -- Parse JSON with error handling
  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or not data or type(data) ~= "table" then
    vim.notify("Corrupted note session file, ignoring", vim.log.levels.WARN)
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
