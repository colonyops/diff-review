local M = {}

-- In-memory comment storage
M.comments = {}
M.next_id = 1

-- Comment structure:
-- {
--   id = number,
--   file = string (file path),
--   line = number (line number in diff),
--   line_range = { start = number, end = number } (for range comments),
--   text = string (comment text),
--   created_at = number (timestamp),
--   updated_at = number (timestamp),
--   type = "single" | "range"
-- }

-- Generate unique comment ID
local function generate_id()
  local id = M.next_id
  M.next_id = M.next_id + 1
  return id
end

-- Add a new comment
function M.add(file, line, text, line_range)
  local timestamp = os.time()
  local comment = {
    id = generate_id(),
    file = file,
    line = line,
    text = text,
    created_at = timestamp,
    updated_at = timestamp,
    type = line_range and "range" or "single",
  }

  if line_range then
    comment.line_range = line_range
  end

  table.insert(M.comments, comment)
  return comment
end

-- Get comment by ID
function M.get(id)
  for _, comment in ipairs(M.comments) do
    if comment.id == id then
      return comment
    end
  end
  return nil
end

-- Get all comments for a file
function M.get_for_file(file)
  local file_comments = {}
  for _, comment in ipairs(M.comments) do
    if comment.file == file then
      table.insert(file_comments, comment)
    end
  end
  return file_comments
end

-- Get comments at a specific line
function M.get_at_line(file, line)
  local line_comments = {}
  for _, comment in ipairs(M.comments) do
    if comment.file == file then
      if comment.type == "single" and comment.line == line then
        table.insert(line_comments, comment)
      elseif comment.type == "range" and line >= comment.line_range.start and line <= comment.line_range.end then
        table.insert(line_comments, comment)
      end
    end
  end
  return line_comments
end

-- Update a comment
function M.update(id, new_text)
  local comment = M.get(id)
  if not comment then
    return false
  end

  comment.text = new_text
  comment.updated_at = os.time()
  return true
end

-- Delete a comment
function M.delete(id)
  for i, comment in ipairs(M.comments) do
    if comment.id == id then
      table.remove(M.comments, i)
      return true
    end
  end
  return false
end

-- Delete all comments for a file
function M.delete_for_file(file)
  local i = 1
  local count = 0
  while i <= #M.comments do
    if M.comments[i].file == file then
      table.remove(M.comments, i)
      count = count + 1
    else
      i = i + 1
    end
  end
  return count
end

-- Get all comments
function M.get_all()
  return M.comments
end

-- Clear all comments
function M.clear()
  M.comments = {}
  M.next_id = 1
end

-- Get statistics
function M.stats()
  local stats = {
    total = #M.comments,
    by_file = {},
    by_type = { single = 0, range = 0 },
  }

  for _, comment in ipairs(M.comments) do
    -- Count by file
    if not stats.by_file[comment.file] then
      stats.by_file[comment.file] = 0
    end
    stats.by_file[comment.file] = stats.by_file[comment.file] + 1

    -- Count by type
    stats.by_type[comment.type] = stats.by_type[comment.type] + 1
  end

  return stats
end

return M
