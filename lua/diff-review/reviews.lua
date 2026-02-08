local M = {}

local comments = require("diff-review.comments")
local persistence = require("diff-review.persistence")

-- Active reviews
M.reviews = {}
M.current_review = nil

-- Review context structure:
-- {
--   id = string (unique identifier),
--   type = "uncommitted" | "ref" | "range" | "pr",
--   base = string (base ref for range),
--   head = string (head ref for range),
--   pr_number = number (for PR reviews),
--   files = table (list of changed files),
--   created_at = number (timestamp),
--   last_accessed = number (timestamp),
-- }

-- Generate unique review ID
local function generate_id(type, base, head, pr_number)
  if type == "uncommitted" then
    return "uncommitted"
  elseif type == "pr" and pr_number then
    return string.format("pr-%d", pr_number)
  elseif type == "ref" and head then
    -- Sanitize ref name for use as filename
    local sanitized = head:gsub("[^%w%-_]", "_")
    return string.format("ref-%s", sanitized)
  elseif type == "range" and base and head then
    local sanitized_base = base:gsub("[^%w%-_]", "_")
    local sanitized_head = head:gsub("[^%w%-_]", "_")
    return string.format("range-%s..%s", sanitized_base, sanitized_head)
  end

  -- Fallback
  return string.format("review-%d", os.time())
end

-- Create a new review context
function M.create(type, base, head, pr_number)
  local id = generate_id(type, base, head, pr_number)

  local review = {
    id = id,
    type = type,
    base = base,
    head = head,
    pr_number = pr_number,
    files = {},
    created_at = os.time(),
    last_accessed = os.time(),
  }

  M.reviews[id] = review
  return review
end

-- Get or create a review context
function M.get_or_create(type, base, head, pr_number)
  local id = generate_id(type, base, head, pr_number)

  if M.reviews[id] then
    M.reviews[id].last_accessed = os.time()
    return M.reviews[id]
  end

  return M.create(type, base, head, pr_number)
end

-- Get a review by ID
function M.get(id)
  return M.reviews[id]
end

-- Set current review
function M.set_current(review)
  M.current_review = review

  -- Load comments for this review
  local loaded_comments = persistence.auto_load(review.id)
  if loaded_comments and #loaded_comments > 0 then
    comments.comments = loaded_comments
    comments.next_id = 1
    for _, comment in ipairs(loaded_comments) do
      if comment.id >= comments.next_id then
        comments.next_id = comment.id + 1
      end
    end
    vim.notify(string.format("Loaded %d comment(s) for review: %s", #loaded_comments, review.id), vim.log.levels.INFO)
  else
    comments.clear()
  end
end

-- Get current review
function M.get_current()
  return M.current_review
end

-- Save current review comments
function M.save_current()
  if not M.current_review then
    return false
  end

  return persistence.auto_save(comments.get_all(), M.current_review.id)
end

-- List all reviews
function M.list()
  local review_list = {}
  for _, review in pairs(M.reviews) do
    table.insert(review_list, review)
  end

  -- Sort by last accessed
  table.sort(review_list, function(a, b)
    return a.last_accessed > b.last_accessed
  end)

  return review_list
end

-- Delete a review
function M.delete(id)
  if M.current_review and M.current_review.id == id then
    M.current_review = nil
    comments.clear()
  end

  M.reviews[id] = nil
  persistence.delete(id)
end

-- Get review display name
function M.get_display_name(review)
  if review.type == "uncommitted" then
    return "Uncommitted Changes"
  elseif review.type == "pr" then
    return string.format("PR #%d", review.pr_number)
  elseif review.type == "ref" then
    return string.format("Ref: %s", review.head)
  elseif review.type == "range" then
    return string.format("%s..%s", review.base, review.head)
  end

  return review.id
end

-- Auto-save on comment changes
function M.setup_auto_save()
  -- Save comments when they change
  -- This would be called after any comment operation
end

return M
