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
  cached_file_stats = nil,  -- Cache for file stats to avoid repeated git calls
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
    -- Get comment counts for all files
    local comments = require("diff-review.comments")
    local comment_stats = comments.stats()

    -- Get file stats (additions/deletions) - use cache if available
    if not M.state.cached_file_stats then
      M.state.cached_file_stats = diff.get_file_stats()
    end
    local file_stats = M.state.cached_file_stats

    for i, file in ipairs(M.state.files) do
      local status_info = status_icons[file.status] or { icon = "?", hl = "Normal" }
      local prefix = (i == M.state.current_index) and "> " or "  "

      -- Get file icon if available
      local file_icon, icon_color = get_file_icon(file.path)
      local icon_part = file_icon and (file_icon .. " ") or ""

      -- Get comment count for this file
      local comment_count = comment_stats.by_file[file.path] or 0
      local comment_part = comment_count > 0 and string.format(" [%d]", comment_count) or ""

      -- Get line changes for this file
      local stats = file_stats[file.path]
      local stats_part = ""
      if stats then
        local parts = {}
        if stats.additions > 0 then
          table.insert(parts, string.format("+%d", stats.additions))
        end
        if stats.deletions > 0 then
          table.insert(parts, string.format("-%d", stats.deletions))
        end
        if #parts > 0 then
          stats_part = " (" .. table.concat(parts, " ") .. ")"
        end
      end

      local line = string.format("%s%s %s%s%s%s", prefix, status_info.icon, icon_part, file.path, stats_part, comment_part)
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

      -- Highlight stats if present
      if stats_part ~= "" then
        -- Find position of stats in the line (before comment part)
        local stats_col = #line - #comment_part - #stats_part

        -- Highlight additions
        if stats and stats.additions > 0 then
          local add_str = "+" .. tostring(stats.additions)
          local add_pos = line:find("%+" .. tostring(stats.additions), stats_col, true)
          if add_pos then
            table.insert(highlights, {
              line = #lines - 1,
              col = add_pos - 1,
              end_col = add_pos - 1 + #add_str,
              hl_group = "DiffAdd",
            })
          end
        end

        -- Highlight deletions
        if stats and stats.deletions > 0 then
          local del_str = "-" .. tostring(stats.deletions)
          local del_pos = line:find("%-" .. tostring(stats.deletions), stats_col, true)
          if del_pos then
            table.insert(highlights, {
              line = #lines - 1,
              col = del_pos - 1,
              end_col = del_pos - 1 + #del_str,
              hl_group = "DiffDelete",
            })
          end
        end
      end

      -- Highlight comment count if present
      if comment_count > 0 then
        local comment_col = #line - #comment_part
        table.insert(highlights, {
          line = #lines - 1,
          col = comment_col,
          end_col = comment_col + #comment_part,
          hl_group = "Comment",
        })
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

  -- Update cursor position to track selection
  if state.file_list_win and vim.api.nvim_win_is_valid(state.file_list_win) then
    -- Line number is 0-indexed for API but 1-indexed for cursor
    -- Header takes 2 lines, so current file is at line (current_index + 2)
    local cursor_line = M.state.current_index + 2
    if cursor_line <= #lines then
      vim.api.nvim_win_set_cursor(state.file_list_win, { cursor_line, 0 })
    end
  end
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
  M.state.cached_file_stats = nil  -- Invalidate cache on refresh
  M.render()
  if #M.state.files > 0 then
    M.update_diff()
  end
end

return M
