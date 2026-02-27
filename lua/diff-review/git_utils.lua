local M = {}

-- Get git root directory
-- Returns: (string|nil, error_string|nil)
function M.get_git_root()
  local git_dir = vim.fn.system("git rev-parse --git-dir 2>/dev/null"):gsub("\n", "")

  if vim.v.shell_error ~= 0 or git_dir == "" then
    return nil, "Not in a git repository"
  end

  return git_dir, nil
end

-- Get repository root directory
-- Returns: (string|nil, error_string|nil)
function M.get_repo_root()
  local repo_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")

  if vim.v.shell_error ~= 0 or repo_root == "" then
    return nil, "Not in a git repository"
  end

  return repo_root, nil
end

-- Normalize a file path to a stable key for note storage.
-- Uses repo-root relative paths when available; otherwise absolute path.
function M.normalize_file_key(filepath)
  if not filepath or filepath == "" then
    return filepath
  end

  local abs_path = vim.fn.fnamemodify(filepath, ":p")
  local repo_root = M.get_repo_root()
  if not repo_root then
    return abs_path
  end

  local root_prefix = repo_root .. "/"
  if abs_path:sub(1, #root_prefix) == root_prefix then
    return abs_path:sub(#root_prefix + 1)
  end

  return abs_path
end

-- Get storage directory (git root + .diff-review or fallback to cwd)
-- Returns: (string, error_string|nil)
function M.get_storage_dir()
  local git_dir, err = M.get_git_root()

  if not git_dir then
    -- Fallback to current directory
    return vim.fn.getcwd() .. "/.diff-review", nil
  end

  return git_dir .. "/diff-review", nil
end

return M
