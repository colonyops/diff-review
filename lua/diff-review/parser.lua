local M = {}

-- Parse command arguments
-- Returns: { type, base, head, pr_number }
function M.parse_args(args)
  -- No arguments → uncommitted changes
  if not args or args == "" then
    return {
      type = "uncommitted",
      base = nil,
      head = nil,
      pr_number = nil,
    }
  end

  -- Trim whitespace
  args = args:match("^%s*(.-)%s*$")

  -- Check for PR syntax: ghpr:N or pr:N
  local pr_number = args:match("^ghpr:(%d+)$") or args:match("^pr:(%d+)$")
  if pr_number then
    return {
      type = "pr",
      base = nil,
      head = nil,
      pr_number = tonumber(pr_number),
    }
  end

  -- Check for range syntax: base..head or base...head
  local base, head = args:match("^(.+)%.%.%.?(.+)$")
  if base and head then
    return {
      type = "range",
      base = base,
      head = head,
      pr_number = nil,
    }
  end

  -- Single ref → diff from ref to HEAD
  return {
    type = "ref",
    base = args,
    head = "HEAD",
    pr_number = nil,
  }
end

-- Validate parsed arguments
function M.validate(parsed)
  if parsed.type == "pr" and not parsed.pr_number then
    return false, "Invalid PR number"
  end

  if parsed.type == "range" and (not parsed.base or not parsed.head) then
    return false, "Invalid range syntax"
  end

  if parsed.type == "ref" and not parsed.base then
    return false, "Invalid ref"
  end

  return true
end

-- Format parsed args for display
function M.format(parsed)
  if parsed.type == "uncommitted" then
    return "Uncommitted Changes"
  elseif parsed.type == "pr" then
    return string.format("PR #%d", parsed.pr_number)
  elseif parsed.type == "ref" then
    return string.format("%s..HEAD", parsed.base)
  elseif parsed.type == "range" then
    return string.format("%s..%s", parsed.base, parsed.head)
  end

  return "Unknown"
end

-- Get git diff args for parsed context
function M.get_diff_args(parsed)
  if parsed.type == "uncommitted" then
    -- Diff for uncommitted changes (both staged and unstaged)
    return {}
  elseif parsed.type == "ref" then
    -- Diff from ref to HEAD
    return { parsed.base .. "..HEAD" }
  elseif parsed.type == "range" then
    -- Diff between two refs
    return { parsed.base .. ".." .. parsed.head }
  elseif parsed.type == "pr" then
    -- For PR, we'll need to fetch the PR and get the base/head
    -- This is a placeholder - actual implementation would fetch PR details
    return { string.format("pr-%d", parsed.pr_number) }
  end

  return {}
end

return M
