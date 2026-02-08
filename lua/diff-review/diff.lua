local M = {}

local config = require("diff-review.config")

-- Execute git command and return output
local function exec_git(args)
  local cmd = "git " .. table.concat(args, " ")
  local handle = io.popen(cmd)
  if not handle then
    return nil, "Failed to execute git command"
  end

  local result = handle:read("*a")
  handle:close()
  return result
end

-- Parse git status to get changed files
local function parse_status(status_output)
  local files = {}

  for line in status_output:gmatch("[^\r\n]+") do
    -- Parse status format: "XY path" or "XY path -> newpath"
    local status, path = line:match("^(..) (.+)$")
    if status and path then
      local file_status = status:sub(1, 1)
      if file_status == " " then
        file_status = status:sub(2, 2)
      end

      -- Handle renames
      local old_path, new_path = path:match("(.+) %-> (.+)")
      if old_path then
        path = new_path
        file_status = "R"
      end

      -- Map status codes
      local status_map = {
        M = "M",  -- Modified
        A = "A",  -- Added
        D = "D",  -- Deleted
        R = "R",  -- Renamed
        C = "M",  -- Copied (treat as modified)
        U = "M",  -- Updated but unmerged
      }

      table.insert(files, {
        status = status_map[file_status] or "M",
        path = path,
      })
    end
  end

  return files
end

-- Get list of changed files
function M.get_changed_files()
  -- Get staged and unstaged changes
  local status_output = exec_git({ "status", "--porcelain" })
  if not status_output or status_output == "" then
    return {}
  end

  return parse_status(status_output)
end

-- Get diff for a specific file
function M.get_file_diff(file)
  local opts = config.get()
  local args = { "diff" }

  -- Add context lines
  table.insert(args, "-U" .. opts.diff.context_lines)

  -- Ignore whitespace if configured
  if opts.diff.ignore_whitespace then
    table.insert(args, "-w")
  end

  -- Add custom args
  for _, arg in ipairs(opts.git.diff_args) do
    table.insert(args, arg)
  end

  -- Add file path
  table.insert(args, "--")
  table.insert(args, file.path)

  local diff_output = exec_git(args)
  if not diff_output or diff_output == "" then
    -- Try staged changes
    args = { "diff", "--cached" }
    table.insert(args, "-U" .. opts.diff.context_lines)
    if opts.diff.ignore_whitespace then
      table.insert(args, "-w")
    end
    table.insert(args, "--")
    table.insert(args, file.path)

    diff_output = exec_git(args)
  end

  return diff_output or ""
end

-- Parse diff output into structured format
function M.parse_diff(diff_output)
  local hunks = {}
  local current_hunk = nil

  for line in diff_output:gmatch("[^\r\n]+") do
    -- Match hunk header: @@ -start,count +start,count @@
    local old_start, old_count, new_start, new_count = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
    if old_start then
      if current_hunk then
        table.insert(hunks, current_hunk)
      end

      current_hunk = {
        old_start = tonumber(old_start),
        old_count = tonumber(old_count) or 1,
        new_start = tonumber(new_start),
        new_count = tonumber(new_count) or 1,
        lines = { line },
      }
    elseif current_hunk then
      table.insert(current_hunk.lines, line)
    end
  end

  if current_hunk then
    table.insert(hunks, current_hunk)
  end

  return hunks
end

-- Show diff for a file in the diff panel
function M.show_file_diff(file)
  local layout = require("diff-review.layout")
  local state = layout.get_state()

  if not state.diff_buf or not vim.api.nvim_buf_is_valid(state.diff_buf) then
    return
  end

  -- Get diff content
  local diff_output = M.get_file_diff(file)

  -- Split into lines
  local lines = {}
  for line in diff_output:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  -- If no diff output, show message
  if #lines == 0 then
    lines = {
      "No diff available for: " .. file.path,
      "",
      "This file may be:",
      "  - Untracked",
      "  - Binary",
      "  - Empty",
    }
  end

  -- Make buffer modifiable
  vim.api.nvim_buf_set_option(state.diff_buf, "modifiable", true)

  -- Set content
  vim.api.nvim_buf_set_lines(state.diff_buf, 0, -1, false, lines)

  -- Apply syntax highlighting
  local opts = config.get()
  if opts.diff.syntax_highlighting then
    vim.api.nvim_buf_set_option(state.diff_buf, "filetype", "diff")
  end

  -- Make buffer read-only
  vim.api.nvim_buf_set_option(state.diff_buf, "modifiable", false)

  -- Scroll to top
  if state.diff_win and vim.api.nvim_win_is_valid(state.diff_win) then
    vim.api.nvim_win_set_cursor(state.diff_win, { 1, 0 })
  end
end

return M
