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
