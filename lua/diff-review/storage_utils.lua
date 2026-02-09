local M = {}

-- Ensure directory exists
-- Returns: (boolean, error_string|nil)
function M.ensure_dir(path)
  if vim.fn.isdirectory(path) == 1 then
    return true, nil
  end

  local ok, err = pcall(vim.fn.mkdir, path, "p")
  if not ok then
    return false, string.format("Failed to create directory %s: %s", path, tostring(err))
  end

  return true, nil
end

-- Write data as JSON to file
-- Returns: (boolean, error_string|nil)
function M.write_json(path, data)
  -- Encode JSON
  local ok, json = pcall(vim.fn.json_encode, data)
  if not ok then
    return false, string.format("Failed to encode JSON: %s", tostring(json))
  end

  -- Open file for writing
  local file, err = io.open(path, "w")
  if not file then
    return false, string.format("Failed to open %s: %s", path, err or "unknown error")
  end

  -- Write and close
  file:write(json)
  file:close()

  return true, nil
end

-- Read JSON from file
-- Returns: (data|nil, error_string|nil)
function M.read_json(path)
  -- Check if file exists
  if vim.fn.filereadable(path) == 0 then
    return nil, string.format("File not found: %s", path)
  end

  -- Open and read file
  local file, err = io.open(path, "r")
  if not file then
    return nil, string.format("Failed to open %s: %s", path, err or "unknown error")
  end

  local content = file:read("*a")
  file:close()

  -- Handle empty file
  if not content or content == "" then
    return nil, string.format("Empty file: %s", path)
  end

  -- Parse JSON
  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or not data then
    return nil, string.format("Failed to parse JSON from %s: %s", path, tostring(data))
  end

  return data, nil
end

-- Check if file exists
-- Returns: boolean
function M.file_exists(path)
  return vim.fn.filereadable(path) == 1
end

return M
