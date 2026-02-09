local M = {}

local config = require("diff-review.config")

-- Execute git command and return output
local function exec_cmd(cmd)
  local handle = io.popen(cmd)
  if not handle then
    return nil, "Failed to execute command"
  end

  local result = handle:read("*a")
  local success = handle:close()

  if not success or result:match("^fatal:") or result:match("^error:") then
    return nil, result
  end

  return result, nil
end

local function shell_join(args)
  local escaped = {}
  for _, arg in ipairs(args) do
    table.insert(escaped, vim.fn.shellescape(arg))
  end
  return table.concat(escaped, " ")
end

local function exec_git(args)
  local cmd = "git " .. table.concat(args, " ") .. " 2>&1"
  return exec_cmd(cmd)
end

local function run_diff_tool(tool, args, opts)
  if tool == "difftastic" then
    local cmd = "difft " .. shell_join(args) .. " --color=never 2>&1"
    return exec_cmd(cmd)
  elseif tool == "delta" then
    local git_args = vim.deepcopy(args)
    table.insert(git_args, "--color=never")
    local cmd = "git " .. shell_join(git_args) .. " | delta --color=never --paging=never 2>&1"
    return exec_cmd(cmd)
  elseif tool == "custom" and opts.diff.custom_command and opts.diff.custom_command ~= "" then
    local args_str = shell_join(args)
    local cmd = opts.diff.custom_command
    if cmd:find("{args}") then
      cmd = cmd:gsub("{args}", args_str)
    else
      cmd = cmd .. " " .. args_str
    end
    cmd = cmd .. " 2>&1"
    return exec_cmd(cmd)
  end

  return exec_git(args)
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

-- Parse git diff --name-status output
local function parse_diff_name_status(output)
  local files = {}

  for line in output:gmatch("[^\r\n]+") do
    -- Format: "M\tpath" or "R100\told_path\tnew_path"
    local parts = vim.split(line, "\t")
    if #parts >= 2 then
      local status = parts[1]:sub(1, 1)  -- Get first character (M, A, D, R, etc.)
      local path = parts[2]

      -- Handle renames (R\told_path\tnew_path)
      if status == "R" and #parts >= 3 then
        path = parts[3]
      end

      -- Map status codes
      local status_map = {
        M = "M",  -- Modified
        A = "A",  -- Added
        D = "D",  -- Deleted
        R = "R",  -- Renamed
        C = "M",  -- Copied (treat as modified)
        T = "M",  -- Type changed
      }

      table.insert(files, {
        status = status_map[status] or "M",
        path = path,
      })
    end
  end

  return files
end

local function split_diff_by_file(diff_output)
  local by_file = {}
  local current_file = nil
  local buffer = {}

  for line in diff_output:gmatch("[^\r\n]+") do
    local old_path, new_path = line:match("^diff %-%-git a/(.+) b/(.+)$")
    if old_path and new_path then
      if current_file then
        by_file[current_file] = table.concat(buffer, "\n")
      end
      current_file = new_path
      buffer = { line }
    elseif current_file then
      table.insert(buffer, line)
    end
  end

  if current_file then
    by_file[current_file] = table.concat(buffer, "\n")
  end

  return by_file
end

-- Get line stats for all changed files
function M.get_file_stats()
  local reviews = require("diff-review.reviews")
  local review = reviews.get_current()

  if review and review.type == "pr" then
    local github = require("diff-review.github")
    local files, err = github.get_pr_files(review.pr_number)
    if err then
      vim.notify("GitHub files fetch failed: " .. err, vim.log.levels.ERROR)
      return {}
    end
    local stats = {}
    for _, file in ipairs(files) do
      if file.path then
        stats[file.path] = {
          additions = file.additions or 0,
          deletions = file.deletions or 0,
        }
      end
    end
    return stats
  end

  local args = { "diff", "--numstat" }

  if review and review.type == "ref" then
    table.insert(args, review.base .. "..HEAD")
  elseif review and review.type == "range" then
    table.insert(args, review.base .. ".." .. review.head)
  end

  local output, err = exec_git(args)
  if err then
    vim.notify("Git diff stats failed: " .. err, vim.log.levels.ERROR)
    return {}
  end
  if not output or output == "" then
    return {}
  end

  local stats = {}
  for line in output:gmatch("[^\r\n]+") do
    -- Format: "additions\tdeletions\tfilepath"
    local added, deleted, filepath = line:match("^(%S+)\t(%S+)\t(.+)$")
    if added and deleted and filepath then
      -- Handle binary files (marked as -)
      local additions = tonumber(added) or 0
      local deletions = tonumber(deleted) or 0
      stats[filepath] = {
        additions = additions,
        deletions = deletions,
      }
    end
  end

  return stats
end

-- Get list of changed files
function M.get_changed_files()
  -- Get current review context
  local reviews = require("diff-review.reviews")
  local review = reviews.get_current()

  if not review or review.type == "uncommitted" then
    -- Get staged and unstaged changes
    local status_output, err = exec_git({ "status", "--porcelain" })
    if err then
      vim.notify("Git status failed: " .. err, vim.log.levels.ERROR)
      return {}
    end
    if not status_output or status_output == "" then
      return {}
    end
    return parse_status(status_output)
  end

  if review.type == "pr" then
    local github = require("diff-review.github")
    local files, err = github.get_pr_files(review.pr_number)
    if err then
      vim.notify("GitHub files fetch failed: " .. err, vim.log.levels.ERROR)
      return {}
    end
    local status_map = {
      added = "A",
      removed = "D",
      modified = "M",
      renamed = "R",
    }
    local result = {}
    for _, file in ipairs(files) do
      if file.path then
        table.insert(result, {
          status = status_map[file.status] or "M",
          path = file.path,
        })
      end
    end
    return result
  end

  -- For ref and range reviews, use git diff --name-status
  local args = { "diff", "--name-status" }

  if review.type == "ref" then
    table.insert(args, review.base .. "..HEAD")
  elseif review.type == "range" then
    table.insert(args, review.base .. ".." .. review.head)
  end

  local output, err = exec_git(args)
  if err then
    vim.notify("Git error: " .. err, vim.log.levels.ERROR)
    return {}
  end

  if not output or output == "" then
    return {}
  end

  return parse_diff_name_status(output)
end

-- Get diff for a specific file
function M.get_file_diff(file)
  local opts = config.get()
  local reviews = require("diff-review.reviews")
  local review = reviews.get_current()

  local args = { "diff" }
  local tool = opts.diff.tool or "git"

  if review and review.type == "pr" then
    local github = require("diff-review.github")
    local pr_diff, err = github.get_pr_diff(review.pr_number)
    if err then
      vim.notify("GitHub diff fetch failed: " .. err, vim.log.levels.ERROR)
      return ""
    end
    local by_file = split_diff_by_file(pr_diff or "")
    return by_file[file.path] or ""
  end

  -- Add context lines
  local context_lines = opts.diff.context_lines
  if file.status == "D" then
    context_lines = 99999
  end
  table.insert(args, "-U" .. context_lines)

  -- Ignore whitespace if configured
  if opts.diff.ignore_whitespace then
    table.insert(args, "-w")
  end

  -- Add custom args
  for _, arg in ipairs(opts.git.diff_args) do
    table.insert(args, arg)
  end

  -- Add review context
  if review and review.type == "ref" then
    table.insert(args, review.base .. "..HEAD")
  elseif review and review.type == "range" then
    table.insert(args, review.base .. ".." .. review.head)
  end

  -- Add file path
  table.insert(args, "--")
  table.insert(args, file.path)

  local diff_output, diff_err = run_diff_tool(tool, args, opts)
  if diff_err then
    vim.notify("Diff command failed: " .. diff_err, vim.log.levels.ERROR)
    if tool ~= "git" then
      diff_output = exec_git(args)
    end
  end

  -- For uncommitted changes, also try staged if no unstaged diff
  if not diff_output or diff_output == "" then
    if not review or review.type == "uncommitted" then
      args = { "diff", "--cached" }
      table.insert(args, "-U" .. context_lines)
      if opts.diff.ignore_whitespace then
        table.insert(args, "-w")
      end
      table.insert(args, "--")
      table.insert(args, file.path)

      diff_output, diff_err = run_diff_tool(tool, args, opts)
      if diff_err then
        vim.notify("Diff command failed: " .. diff_err, vim.log.levels.ERROR)
        if tool ~= "git" then
          diff_output = exec_git(args)
        end
      end
    end
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
