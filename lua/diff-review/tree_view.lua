local M = {}

-- Tree node structure:
-- {
--   name = string,
--   path = string,
--   type = "file" | "directory",
--   children = { [name] = node },
--   file_data = file object (for file nodes),
--   expanded = boolean (for directory nodes),
-- }

-- Build a tree structure from a flat list of files
function M.build_tree(files)
  local root = {
    name = "",
    path = "",
    type = "directory",
    children = {},
    expanded = true,
  }

  for _, file in ipairs(files) do
    local parts = vim.split(file.path, "/", { plain = true })
    local current = root

    -- Navigate/create directory nodes
    for i = 1, #parts - 1 do
      local dir_name = parts[i]
      local dir_path = table.concat(vim.list_slice(parts, 1, i), "/")

      if not current.children[dir_name] then
        current.children[dir_name] = {
          name = dir_name,
          path = dir_path,
          type = "directory",
          children = {},
          expanded = true,  -- Expand all by default
        }
      end

      current = current.children[dir_name]
    end

    -- Add file node
    local file_name = parts[#parts]
    current.children[file_name] = {
      name = file_name,
      path = file.path,
      type = "file",
      file_data = file,
    }
  end

  return root
end

-- Flatten tree into a renderable list with metadata
-- Returns: { { node, depth, index } }
function M.flatten_tree(root, current_index)
  local result = {}
  local file_index = 1

  local function traverse(node, depth)
    if node.type == "directory" and node.name ~= "" then
      -- Add directory entry
      table.insert(result, {
        node = node,
        depth = depth,
        index = nil,  -- Directories don't have file indices
      })

      if not node.expanded then
        return  -- Skip children if collapsed
      end
    end

    -- Process children in sorted order
    local names = vim.tbl_keys(node.children)
    table.sort(names, function(a, b)
      local node_a = node.children[a]
      local node_b = node.children[b]

      -- Directories first, then files
      if node_a.type ~= node_b.type then
        return node_a.type == "directory"
      end

      return a < b
    end)

    for _, name in ipairs(names) do
      local child = node.children[name]

      if child.type == "file" then
        table.insert(result, {
          node = child,
          depth = depth,
          index = file_index,
        })
        file_index = file_index + 1
      else
        traverse(child, depth + 1)
      end
    end
  end

  traverse(root, 0)

  return result
end

-- Toggle directory expansion
function M.toggle_directory(tree, path)
  local parts = vim.split(path, "/", { plain = true })
  local current = tree

  for _, part in ipairs(parts) do
    if current.children[part] then
      current = current.children[part]
    else
      return false
    end
  end

  if current.type == "directory" then
    current.expanded = not current.expanded
    return true
  end

  return false
end

-- Set directory expansion state
function M.set_directory_expanded(tree, path, expanded)
  local parts = vim.split(path, "/", { plain = true })
  local current = tree

  for _, part in ipairs(parts) do
    if current.children[part] then
      current = current.children[part]
    else
      return false
    end
  end

  if current.type == "directory" then
    if current.expanded == expanded then
      return false
    end
    current.expanded = expanded
    return true
  end

  return false
end

-- Find the file index for a given path in the flat file list
function M.find_file_index(files, path)
  for i, file in ipairs(files) do
    if file.path == path then
      return i
    end
  end
  return nil
end

return M
