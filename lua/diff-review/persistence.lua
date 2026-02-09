local M = {}

local config = require("diff-review.config")

-- Get storage directory
local function get_storage_dir()
  -- Try to find git root
  local git_dir = vim.fn.system("git rev-parse --git-dir 2>/dev/null"):gsub("\n", "")

  if vim.v.shell_error ~= 0 or git_dir == "" then
    -- Fallback to current directory
    return vim.fn.getcwd() .. "/.diff-review"
  end

  return git_dir .. "/diff-review"
end

-- Ensure storage directory exists
local function ensure_storage_dir()
  local dir = get_storage_dir()

  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  return dir
end

-- Get storage file path for a review context
local function get_storage_path(context_id)
  local dir = ensure_storage_dir()
  return string.format("%s/%s.json", dir, context_id or "default")
end

-- Save comments to JSON
function M.save(comments, context_id)
  local path = get_storage_path(context_id)

  -- Convert comments to JSON-serializable format
  local data = {
    version = 1,
    context_id = context_id or "default",
    saved_at = os.time(),
    comments = comments,
  }

  local json = vim.fn.json_encode(data)

  -- Write to file
  local file = io.open(path, "w")
  if not file then
    vim.notify("Failed to save comments: " .. path, vim.log.levels.ERROR)
    return false
  end

  file:write(json)
  file:close()

  return true
end

-- Load comments from JSON
function M.load(context_id)
  local path = get_storage_path(context_id)

  -- Check if file exists
  if vim.fn.filereadable(path) == 0 then
    return nil
  end

  -- Read file
  local file = io.open(path, "r")
  if not file then
    vim.notify("Failed to load comments: " .. path, vim.log.levels.ERROR)
    return nil
  end

  local content = file:read("*a")
  file:close()

  -- Parse JSON
  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or not data then
    vim.notify("Failed to parse comments file: " .. path, vim.log.levels.ERROR)
    return nil
  end

  return data.comments
end

-- Delete saved comments
function M.delete(context_id)
  local path = get_storage_path(context_id)

  if vim.fn.filereadable(path) == 1 then
    vim.fn.delete(path)
    return true
  end

  return false
end

-- List all saved review contexts
function M.list_contexts()
  local dir = get_storage_dir()

  if vim.fn.isdirectory(dir) == 0 then
    return {}
  end

  local files = vim.fn.glob(dir .. "/*.json", false, true)
  local contexts = {}

  for _, file in ipairs(files) do
    local name = vim.fn.fnamemodify(file, ":t:r")
    table.insert(contexts, name)
  end

  return contexts
end

-- Auto-save comments
function M.auto_save(comments, context_id)
  -- Only auto-save if there are comments
  if #comments == 0 then
    return
  end

  M.save(comments, context_id)
end

-- Auto-load comments
function M.auto_load(context_id)
  return M.load(context_id) or {}
end

-- Get storage directory path
function M.get_storage_dir()
  return get_storage_dir()
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

-- Get global session file path
local function get_global_session_path()
  local dir = ensure_global_storage_dir()
  return dir .. "/session_state.json"
end

-- Save global session state
function M.save_global_session(state)
  local path = get_global_session_path()

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
    vim.notify("Failed to save session: " .. (err or "unknown error"), vim.log.levels.ERROR)
    return false
  end

  file:write(json)
  file:close()

  return true
end

-- Load global session state
function M.load_global_session()
  local path = get_global_session_path()

  -- Check if file exists
  if vim.fn.filereadable(path) == 0 then
    return nil
  end

  -- Read file
  local file, err = io.open(path, "r")
  if not file then
    vim.notify("Failed to load session: " .. (err or "unknown error"), vim.log.levels.WARN)
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
    vim.notify("Corrupted session file, ignoring", vim.log.levels.WARN)
    return nil
  end

  return data.state
end

-- Clear global session state
function M.clear_global_session()
  local path = get_global_session_path()

  if vim.fn.filereadable(path) == 1 then
    vim.fn.delete(path)
    return true
  end

  return false
end

return M
