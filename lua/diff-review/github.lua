local M = {}

local function exec_gh(args)
  local escaped = {}
  for _, arg in ipairs(args) do
    table.insert(escaped, vim.fn.shellescape(arg))
  end
  local cmd = "gh " .. table.concat(escaped, " ") .. " 2>&1"
  local handle = io.popen(cmd)
  if not handle then
    return nil, "Failed to execute gh command"
  end

  local result = handle:read("*a")
  local success = handle:close()
  if not success or result:match("^fatal:") or result:match("^error:") then
    return nil, result
  end

  return result, nil
end

local function exec_gh_with_input(args, input)
  local escaped = {}
  for _, arg in ipairs(args) do
    table.insert(escaped, vim.fn.shellescape(arg))
  end
  local cmd = "gh " .. table.concat(escaped, " ")
  local output = vim.fn.system(cmd, input)
  if vim.v.shell_error ~= 0 then
    return nil, output
  end
  return output, nil
end

function M.exec(args)
  return exec_gh(args)
end

function M.exec_json(args)
  local output, err = exec_gh(args)
  if err then
    return nil, err
  end

  local ok, data = pcall(vim.json.decode, output)
  if not ok then
    return nil, "Failed to parse gh JSON output"
  end

  return data, nil
end

function M.is_authenticated()
  local _, err = exec_gh({ "auth", "status", "--hostname", "github.com" })
  if err then
    return false, err
  end
  return true, nil
end

function M.get_repo()
  local data, err = M.exec_json({ "repo", "view", "--json", "name,owner" })
  if err then
    return nil, err
  end
  if not data or not data.name or not data.owner or not data.owner.login then
    return nil, "Failed to read repository info"
  end
  return { name = data.name, owner = data.owner.login }, nil
end

function M.get_pr_diff(pr_number)
  return exec_gh({ "pr", "diff", tostring(pr_number), "--color=never" })
end

function M.get_pr_files(pr_number)
  local data, err = M.exec_json({ "pr", "view", tostring(pr_number), "--json", "files" })
  if err then
    return nil, err
  end
  if not data or not data.files then
    return {}, nil
  end
  return data.files, nil
end

function M.get_diff_position(file_diff, buffer_line)
  if not file_diff or buffer_line < 1 then
    return nil
  end

  local idx = 0
  local patch_start = nil
  for line in file_diff:gmatch("[^\r\n]+") do
    idx = idx + 1
    if not patch_start and line:match("^@@") then
      patch_start = idx
    end
  end

  if not patch_start or buffer_line < patch_start then
    return nil
  end

  return buffer_line - patch_start + 1
end

function M.format_single_comment(comment, file_diff)
  local position = M.get_diff_position(file_diff, comment.line)
  if not position then
    return nil, "Unable to map comment line to diff position"
  end

  return {
    path = comment.file,
    position = position,
    body = comment.text,
  }, nil
end

local function get_line_info(file_diff, buffer_line)
  local idx = 0
  local old_line = nil
  local new_line = nil

  for line in file_diff:gmatch("[^\r\n]+") do
    idx = idx + 1

    local old_start, new_start = line:match("^@@ %-(%d+),?%d* %+(%d+),?%d* @@")
    if old_start and new_start then
      old_line = tonumber(old_start)
      new_line = tonumber(new_start)
    elseif old_line and new_line then
      if idx == buffer_line then
        local prefix = line:sub(1, 1)
        if prefix == "+" then
          return { side = "RIGHT", line = new_line }
        elseif prefix == "-" then
          return { side = "LEFT", line = old_line }
        else
          return { side = "RIGHT", line = new_line }
        end
      end

      local prefix = line:sub(1, 1)
      if prefix == "+" then
        new_line = new_line + 1
      elseif prefix == "-" then
        old_line = old_line + 1
      else
        old_line = old_line + 1
        new_line = new_line + 1
      end
    end
  end

  return nil
end

function M.format_range_comment(comment, file_diff)
  if not comment.line_range then
    return nil, "Missing line range for range comment"
  end

  local start_info = get_line_info(file_diff, comment.line_range.start)
  local end_info = get_line_info(file_diff, comment.line_range["end"])

  if not start_info or not end_info then
    return nil, "Unable to map range comment to diff lines"
  end

  if start_info.side ~= end_info.side then
    return nil, "Range spans both sides of the diff"
  end

  return {
    path = comment.file,
    start_line = start_info.line,
    line = end_info.line,
    side = start_info.side,
    start_side = start_info.side,
    body = comment.text,
  }, nil
end

function M.submit_review(pr_number, payload)
  local repo, err = M.get_repo()
  if err then
    return nil, err
  end

  local json = vim.json.encode(payload)
  local endpoint = string.format("repos/%s/%s/pulls/%s/reviews", repo.owner, repo.name, pr_number)
  return exec_gh_with_input({ "api", "-X", "POST", endpoint, "--input", "-" }, json)
end

return M
