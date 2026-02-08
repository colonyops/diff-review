local M = {}

local config = require("diff-review.config")

-- Try to load devicons, fallback to nil if not available
local has_devicons, devicons = pcall(require, "nvim-web-devicons")
if not has_devicons then
  devicons = nil
end

-- State
M.state = {
  files = {},
  current_index = 1,
}

-- Status icons and colors
local status_icons = {
  M = { icon = "●", hl = "DiffChange" },  -- Modified
  A = { icon = "+", hl = "DiffAdd" },     -- Added
  D = { icon = "-", hl = "DiffDelete" },  -- Deleted
  R = { icon = "→", hl = "DiffChange" },  -- Renamed
}

-- Get file icon and color from devicons
local function get_file_icon(filepath)
  if not devicons then
    return nil, nil
  end

  local filename = vim.fn.fnamemodify(filepath, ":t")
  local extension = vim.fn.fnamemodify(filepath, ":e")

  local icon, color = devicons.get_icon_color(filename, extension, { default = true })
  return icon, color
end

-- Render the file list
function M.render()
  local layout = require("diff-review.layout")
  local state = layout.get_state()

  if not state.file_list_buf or not vim.api.nvim_buf_is_valid(state.file_list_buf) then
    return
  end

  -- Get files from diff module
  local diff = require("diff-review.diff")
  M.state.files = diff.get_changed_files()

  -- Make buffer modifiable
  vim.api.nvim_buf_set_option(state.file_list_buf, "modifiable", true)

  -- Build lines
  local lines = {}
  local highlights = {}

  table.insert(lines, "═══ Diff Review ═══")
  table.insert(lines, "")

  if #M.state.files == 0 then
    table.insert(lines, "  No changes found")
  else
    for i, file in ipairs(M.state.files) do
      local status_info = status_icons[file.status] or { icon = "?", hl = "Normal" }
      local prefix = (i == M.state.current_index) and "> " or "  "

      -- Get file icon if available
      local file_icon, icon_color = get_file_icon(file.path)
      local icon_part = file_icon and (file_icon .. " ") or ""

      local line = string.format("%s%s %s%s", prefix, status_info.icon, icon_part, file.path)
      table.insert(lines, line)

      local col = #prefix

      -- Highlight status icon
      table.insert(highlights, {
        line = #lines - 1,  -- 0-indexed
        col = col,
        end_col = col + #status_info.icon,
        hl_group = status_info.hl,
      })

      col = col + #status_info.icon + 1  -- Move past status icon and space

      -- Highlight file icon if present
      if file_icon then
        -- Create a dynamic highlight group for the icon color
        if icon_color then
          local hl_group = "DevIcon_" .. file.path:gsub("[^%w]", "_")
          vim.api.nvim_set_hl(0, hl_group, { fg = icon_color })

          table.insert(highlights, {
            line = #lines - 1,
            col = col,
            end_col = col + #file_icon,
            hl_group = hl_group,
          })
        end
      end

      -- Highlight selected line
      if i == M.state.current_index then
        table.insert(highlights, {
          line = #lines - 1,
          col = 0,
          end_col = -1,
          hl_group = "Visual",
        })
      end
    end
  end

  -- Set lines
  vim.api.nvim_buf_set_lines(state.file_list_buf, 0, -1, false, lines)

  -- Apply highlights
  local ns_id = vim.api.nvim_create_namespace("diff_review_file_list")
  vim.api.nvim_buf_clear_namespace(state.file_list_buf, ns_id, 0, -1)

  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(
      state.file_list_buf,
      ns_id,
      hl.hl_group,
      hl.line,
      hl.col,
      hl.end_col
    )
  end

  -- Make buffer read-only again
  vim.api.nvim_buf_set_option(state.file_list_buf, "modifiable", false)
end

-- Navigate to next file
function M.next_file()
  if #M.state.files == 0 then
    return
  end

  M.state.current_index = M.state.current_index + 1
  if M.state.current_index > #M.state.files then
    M.state.current_index = 1
  end

  M.render()
  M.update_diff()
end

-- Navigate to previous file
function M.prev_file()
  if #M.state.files == 0 then
    return
  end

  M.state.current_index = M.state.current_index - 1
  if M.state.current_index < 1 then
    M.state.current_index = #M.state.files
  end

  M.render()
  M.update_diff()
end

-- Select current file and show diff
function M.select_file()
  if #M.state.files == 0 then
    return
  end

  M.update_diff()
end

-- Update diff panel with current file
function M.update_diff()
  if #M.state.files == 0 or M.state.current_index < 1 or M.state.current_index > #M.state.files then
    return
  end

  local current_file = M.state.files[M.state.current_index]
  local diff = require("diff-review.diff")
  diff.show_file_diff(current_file)

  -- Update comment display
  local ui = require("diff-review.ui")
  ui.update_comment_display()
end

-- Refresh the file list
function M.refresh()
  M.state.current_index = 1
  M.render()
  if #M.state.files > 0 then
    M.update_diff()
  end
end

return M
