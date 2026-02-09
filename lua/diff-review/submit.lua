local M = {}

local comments = require("diff-review.comments")
local reviews = require("diff-review.reviews")
local github = require("diff-review.github")

local function split_diff_by_file(diff_output)
  local by_file = {}
  local current_file = nil
  local buffer = {}

  for line in diff_output:gmatch("[^\r\n]+") do
    local _, new_path = line:match("^diff %-%-git a/(.+) b/(.+)$")
    if new_path then
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

function M.submit_current_review()
  local review = reviews.get_current()
  if not review or review.type ~= "pr" then
    vim.notify("DiffReviewSubmit only works for PR reviews", vim.log.levels.ERROR)
    return
  end

  local ok, auth_err = github.is_authenticated()
  if not ok then
    vim.notify("GitHub auth required: " .. auth_err, vim.log.levels.ERROR)
    return
  end

  local pr_diff, diff_err = github.get_pr_diff(review.pr_number)
  if diff_err then
    vim.notify("Failed to fetch PR diff: " .. diff_err, vim.log.levels.ERROR)
    return
  end

  local diffs_by_file = split_diff_by_file(pr_diff or "")
  local all_comments = comments.get_all()
  if #all_comments == 0 then
    vim.notify("No comments to submit", vim.log.levels.INFO)
    return
  end

  local payload_comments = {}
  for _, comment in ipairs(all_comments) do
    local file_diff = diffs_by_file[comment.file]
    if not file_diff then
      vim.notify("No diff found for comment file: " .. comment.file, vim.log.levels.WARN)
    else
      local formatted, err
      if comment.type == "range" then
        formatted, err = github.format_range_comment(comment, file_diff)
      else
        formatted, err = github.format_single_comment(comment, file_diff)
      end

      if formatted then
        table.insert(payload_comments, formatted)
      else
        vim.notify("Skipping comment: " .. (err or "formatting failed"), vim.log.levels.WARN)
      end
    end
  end

  if #payload_comments == 0 then
    vim.notify("No valid comments to submit", vim.log.levels.WARN)
    return
  end

  local _, submit_err = github.submit_review(review.pr_number, {
    event = "COMMENT",
    comments = payload_comments,
  })

  if submit_err then
    vim.notify("Review submission failed: " .. submit_err, vim.log.levels.ERROR)
    return
  end

  vim.notify(string.format("Submitted %d comment(s) to PR #%d", #payload_comments, review.pr_number), vim.log.levels.INFO)
end

return M
