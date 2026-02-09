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
  view_mode = (config.get().file_list and config.get().file_list.view_mode) or "tree",  -- "flat" or "tree"
  tree = nil,  -- Tree structure for tree view
  flat_tree = nil,  -- Flattened tree for rendering
  initial_load = true,  -- Flag for initial load to select first visual file
}

-- Status icons and colors
local function get_status_icons()
  local opts = config.get()
  local status_cfg = opts.ui.status or {}

  local symbols = status_cfg.symbols or {
    modified = "M",
    added = "A",
    deleted = "D",
    renamed = "R",
  }

  local highlights = status_cfg.highlights or {
    modified = "DiffChange",
    added = "DiffAdd",
    deleted = "DiffDelete",
    renamed = "DiffReviewRenamed",
  }

  return {
    M = { icon = symbols.modified, hl = highlights.modified },
    A = { icon = symbols.added, hl = highlights.added },
    D = { icon = symbols.deleted, hl = highlights.deleted },
    R = { icon = symbols.renamed, hl = highlights.renamed },
  }
end

local function get_repo_root_name()
  local root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
  if vim.v.shell_error ~= 0 or root == "" then
    root = vim.fn.getcwd()
  end
  return vim.fn.fnamemodify(root, ":t")
end

local function get_stats_header_lines()
  local opts = config.get()
  if not opts.ui.show_stats_header then
    return {}
  end

  -- Get review info
  local reviews = require("diff-review.reviews")
  local review = reviews.get_current()
  if not review then
    return {}
  end

  -- Get file and comment counts
  local file_count = #M.state.files
  local comments = require("diff-review.comments")
  local comment_stats = comments.stats()
  local comment_count = comment_stats.total

  -- Calculate aggregate line stats
  local total_additions = 0
  local total_deletions = 0
  local total_modified = 0
  local total_added = 0
  local total_deleted = 0

  if M.state.cached_file_stats then
    for path, stats in pairs(M.state.cached_file_stats) do
      total_additions = total_additions + (stats.additions or 0)
      total_deletions = total_deletions + (stats.deletions or 0)
    end
  end

  -- Count file statuses
  for _, file in ipairs(M.state.files) do
    if file.status == "M" then
      total_modified = total_modified + 1
    elseif file.status == "A" then
      total_added = total_added + 1
    elseif file.status == "D" then
      total_deleted = total_deleted + 1
    end
  end

  -- Format review type
  local review_type = review.type
  if review_type == "pr" then
    review_type = string.format("PR #%d", review.pr_number)
  elseif review_type == "ref" then
    review_type = string.format("%s..HEAD", review.base)
  elseif review_type == "range" then
    review_type = string.format("%s..%s", review.base, review.head)
  end

  -- Build compact single-line stats
  local file_parts = {}
  if total_modified > 0 then table.insert(file_parts, string.format("%dM", total_modified)) end
  if total_added > 0 then table.insert(file_parts, string.format("%dA", total_added)) end
  if total_deleted > 0 then table.insert(file_parts, string.format("%dD", total_deleted)) end
  local file_str = table.concat(file_parts, " ")

  local stats_line = string.format("  %s | Files: %s | Lines: +%d -%d | Comments: %d",
    review_type, file_str, total_additions, total_deletions, comment_count)

  return {
    stats_line,
    opts.ui.stats_header.separator,
  }
end

local function get_header_lines()
  local stats_lines = get_stats_header_lines()
  return stats_lines
end

local function apply_stats_header_highlights(highlights, lines)
  local opts = config.get()
  if not opts.ui.show_stats_header then
    return
  end

  -- Find lines with +/- numbers in the first few header lines
  for i = 1, math.min(5, #lines) do
    local line = lines[i]
    local line_idx = i - 1  -- 0-indexed

    -- Highlight additions (+numbers)
    for pos in line:gmatch("()%+%d+") do
      local start_col = pos - 1
      local end_col = line:match("%+(%d+)", pos) and start_col + 1 + #line:match("%+(%d+)", pos) or start_col + 2
      table.insert(highlights, {
        line = line_idx,
        col = start_col,
        end_col = end_col,
        hl_group = "DiffAdd",
      })
    end

    -- Highlight deletions (-numbers)
    for pos in line:gmatch("()%-(%d+)") do
      local start_col = pos - 1
      local num = line:match("%-(%d+)", pos)
      local end_col = num and start_col + 1 + #num or start_col + 2
      table.insert(highlights, {
        line = line_idx,
        col = start_col,
        end_col = end_col,
        hl_group = "DiffDelete",
      })
    end
  end
end

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

-- Build tree connector lines for visual hierarchy
local function build_tree_connectors(flat_tree, current_idx)
  local connectors = {}

  for i = 1, #flat_tree do
    local entry = flat_tree[i]
    local depth = entry.depth
    local connector = ""

    if depth == 0 then
      connectors[i] = ""
    else
      -- Build vertical lines for parent levels
      for d = 1, depth - 1 do
        -- Check if there are more siblings at depth d after the current position
        local has_more = false
        for j = i + 1, #flat_tree do
          if flat_tree[j].depth < d then
            break
          end
          if flat_tree[j].depth == d then
            has_more = true
            break
          end
        end
        connector = connector .. (has_more and "│  " or "   ")
      end

      -- Check if this is the last sibling at current depth
      local is_last = true
      for j = i + 1, #flat_tree do
        if flat_tree[j].depth < depth then
          break
        end
        if flat_tree[j].depth == depth then
          is_last = false
          break
        end
      end

      connector = connector .. (is_last and "└─ " or "├─ ")
      connectors[i] = connector
    end
  end

  return connectors
end

-- Render tree view
local function render_tree_view(state, lines, highlights)
  local tree_view = require("diff-review.tree_view")
  local comments = require("diff-review.comments")
  local diff = require("diff-review.diff")

  -- Build tree if not cached or files changed
  if not M.state.tree then
    M.state.tree = tree_view.build_tree(M.state.files, M.state.tree_root_name)
  end

  -- Flatten tree for rendering
  M.state.flat_tree = tree_view.flatten_tree(M.state.tree, M.state.files)

  -- Get stats once
  local comment_stats = comments.stats()
  if not M.state.cached_file_stats then
    M.state.cached_file_stats = diff.get_file_stats()
  end
  local file_stats = M.state.cached_file_stats

  -- Build tree connectors for visual hierarchy
  local connectors = build_tree_connectors(M.state.flat_tree, M.state.current_index)

  for idx, entry in ipairs(M.state.flat_tree) do
    local node = entry.node
    local depth = entry.depth
    local index = entry.index

    -- Get tree connector for this entry
    local tree_prefix = connectors[idx] or ""
    local prefix = ""

    if node.type == "directory" then
      -- Directory node
      local icon = node.expanded and "▾" or "▸"
      local line = string.format("  %s%s %s/", tree_prefix, icon, node.name)
      table.insert(lines, line)

      -- Highlight tree connectors
      local connector_hl = "NonText"
      table.insert(highlights, {
        line = #lines - 1,
        col = 2,
        end_col = 2 + #tree_prefix,
        hl_group = connector_hl,
      })

      -- Highlight directory icon and name
      local icon_col = 2 + #tree_prefix
      table.insert(highlights, {
        line = #lines - 1,
        col = icon_col,
        end_col = icon_col + #icon + 1 + #node.name + 1,  -- icon + space + name + /
        hl_group = "Directory",
      })
    else
      -- File node
      local file = node.file_data
      local status_info = get_status_icons()[file.status] or { icon = "?", hl = "Normal" }

      -- Selection indicator
      prefix = (index == M.state.current_index) and "> " or "  "

      -- Get file icon
      local file_icon, icon_color = get_file_icon(file.path)
      local icon_part = file_icon and (file_icon .. " ") or ""

      -- Get stats
      local comment_count = comment_stats.by_file[file.path] or 0
      local comment_part = comment_count > 0 and string.format(" [%d]", comment_count) or ""

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

      local line = string.format("%s%s%s %s%s%s%s", prefix, tree_prefix, status_info.icon, icon_part, node.name, stats_part, comment_part)
      table.insert(lines, line)

      local col = #prefix + #tree_prefix

      -- Highlight status icon
      table.insert(highlights, {
        line = #lines - 1,
        col = col,
        end_col = col + #status_info.icon,
        hl_group = status_info.hl,
      })

      col = col + #status_info.icon + 1

      -- Highlight file icon
      if file_icon and icon_color then
        local hl_group = "DevIcon_" .. file.path:gsub("[^%w]", "_")
        vim.api.nvim_set_hl(0, hl_group, { fg = icon_color })

        table.insert(highlights, {
          line = #lines - 1,
          col = col,
          end_col = col + #file_icon,
          hl_group = hl_group,
        })
      end

      -- Highlight stats
      if stats_part ~= "" then
        local stats_col = #line - #comment_part - #stats_part

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

      -- Highlight comment count
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
      if index == M.state.current_index then
        table.insert(highlights, {
          line = #lines - 1,
          col = 0,
          end_col = -1,
          hl_group = "Visual",
        })
      end
    end
  end
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

  local header_lines = get_header_lines()
  for _, line in ipairs(header_lines) do
    table.insert(lines, line)
  end

  M.state.tree_root_name = get_repo_root_name()

  if #M.state.files == 0 then
    table.insert(lines, "  No changes found")
  elseif M.state.view_mode == "tree" then
    render_tree_view(state, lines, highlights)

    -- On initial load, always select first file in visual tree order
    if M.state.initial_load and M.state.flat_tree and #M.state.flat_tree > 0 then
      for _, entry in ipairs(M.state.flat_tree) do
        if entry.index then
          M.state.current_index = entry.index
          M.state.initial_load = false
          break
        end
      end
    end
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
      local status_info = get_status_icons()[file.status] or { icon = "?", hl = "Normal" }
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

  -- Apply stats header highlights
  apply_stats_header_highlights(highlights, lines)

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
    if M.state.view_mode == "tree" and M.state.flat_tree then
      -- Find the line in flat_tree that matches current_index
      for i, entry in ipairs(M.state.flat_tree) do
        if entry.index == M.state.current_index then
          local cursor_line = i + #header_lines  -- +header for hint + spacer
          if cursor_line <= #lines then
            vim.api.nvim_win_set_cursor(state.file_list_win, { cursor_line, 0 })
          end
          break
        end
      end
    else
      -- Flat view: Header takes 2 lines
      local cursor_line = M.state.current_index + #header_lines
      if cursor_line <= #lines then
        vim.api.nvim_win_set_cursor(state.file_list_win, { cursor_line, 0 })
      end
    end
  end
end

-- Navigate to next file
function M.next_file()
  if #M.state.files == 0 then
    return
  end

  if M.state.view_mode == "tree" and M.state.flat_tree then
    -- Navigate through flat tree in visual order
    local current_pos = nil
    for i, entry in ipairs(M.state.flat_tree) do
      if entry.index == M.state.current_index then
        current_pos = i
        break
      end
    end

    if current_pos then
      -- Find next file entry (skip directories)
      for i = current_pos + 1, #M.state.flat_tree do
        if M.state.flat_tree[i].index then
          M.state.current_index = M.state.flat_tree[i].index
          M.render()
          M.update_diff()
          return
        end
      end
      -- Wrap to first file
      for i = 1, current_pos do
        if M.state.flat_tree[i].index then
          M.state.current_index = M.state.flat_tree[i].index
          M.render()
          M.update_diff()
          return
        end
      end
    end
  else
    -- Flat view: simple sequential navigation
    M.state.current_index = M.state.current_index + 1
    if M.state.current_index > #M.state.files then
      M.state.current_index = 1
    end
  end

  M.render()
  M.update_diff()
end

-- Navigate to previous file
function M.prev_file()
  if #M.state.files == 0 then
    return
  end

  if M.state.view_mode == "tree" and M.state.flat_tree then
    -- Navigate through flat tree in visual order
    local current_pos = nil
    for i, entry in ipairs(M.state.flat_tree) do
      if entry.index == M.state.current_index then
        current_pos = i
        break
      end
    end

    if current_pos then
      -- Find previous file entry (skip directories)
      for i = current_pos - 1, 1, -1 do
        if M.state.flat_tree[i].index then
          M.state.current_index = M.state.flat_tree[i].index
          M.render()
          M.update_diff()
          return
        end
      end
      -- Wrap to last file
      for i = #M.state.flat_tree, current_pos, -1 do
        if M.state.flat_tree[i].index then
          M.state.current_index = M.state.flat_tree[i].index
          M.render()
          M.update_diff()
          return
        end
      end
    end
  else
    -- Flat view: simple sequential navigation
    M.state.current_index = M.state.current_index - 1
    if M.state.current_index < 1 then
      M.state.current_index = #M.state.files
    end
  end

  M.render()
  M.update_diff()
end

-- Sync selection to cursor position (for manual cursor movement)
function M.sync_selection_to_cursor()
  local layout = require("diff-review.layout")
  local state = layout.get_state()

  if not state.file_list_win or not vim.api.nvim_win_is_valid(state.file_list_win) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.file_list_win)
  local line_num = cursor[1] - #get_header_lines()

  if M.state.view_mode == "tree" and M.state.flat_tree then
    if line_num >= 1 and line_num <= #M.state.flat_tree then
      local entry = M.state.flat_tree[line_num]
      if entry.index then
        -- Only update if it's a different file
        if M.state.current_index ~= entry.index then
          M.state.current_index = entry.index
          M.update_diff()
          M.render()
        end
      end
    end
  else
    -- Flat view
    if line_num >= 1 and line_num <= #M.state.files then
      if M.state.current_index ~= line_num then
        M.state.current_index = line_num
        M.update_diff()
        M.render()
      end
    end
  end
end

-- Select current file and show diff
function M.select_file()
  if #M.state.files == 0 then
    return
  end

  M.update_diff()

  -- Auto-focus diff window if configured
  local config = require("diff-review.config").get()
  if config.file_list.focus_diff_on_select then
    local layout = require("diff-review.layout")
    local state = layout.get_state()

    if state.diff_win and vim.api.nvim_win_is_valid(state.diff_win) then
      vim.api.nvim_set_current_win(state.diff_win)
    end
  end
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
  M.state.tree = nil  -- Invalidate tree cache
  M.state.flat_tree = nil
  M.render()
  if #M.state.files > 0 then
    M.update_diff()
  end
end

-- Toggle between flat and tree view modes
function M.toggle_view_mode()
  M.state.view_mode = (M.state.view_mode == "flat") and "tree" or "flat"
  M.state.tree = nil  -- Rebuild tree when switching
  M.state.flat_tree = nil
  M.render()
end

-- Toggle directory expansion in tree view
function M.toggle_fold()
  if M.state.view_mode ~= "tree" or not M.state.tree then
    return
  end

  local layout = require("diff-review.layout")
  local state = layout.get_state()

  if not state.file_list_win or not vim.api.nvim_win_is_valid(state.file_list_win) then
    return
  end

  -- Get current cursor line
  local cursor = vim.api.nvim_win_get_cursor(state.file_list_win)
  local line_num = cursor[1] - #get_header_lines()  -- Convert to 0-indexed, accounting for header

  if line_num < 1 or line_num > #M.state.flat_tree then
    return
  end

  local entry = M.state.flat_tree[line_num]
  if entry.node.type == "directory" then
    local tree_view = require("diff-review.tree_view")
    tree_view.toggle_directory(M.state.tree, entry.node.path)
    M.state.flat_tree = nil  -- Force rebuild
    M.render()
  end
end

local function set_fold_state(expanded)
  if M.state.view_mode ~= "tree" or not M.state.tree then
    return
  end

  local layout = require("diff-review.layout")
  local state = layout.get_state()

  if not state.file_list_win or not vim.api.nvim_win_is_valid(state.file_list_win) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.file_list_win)
  local line_num = cursor[1] - #get_header_lines()

  if line_num < 1 or line_num > #M.state.flat_tree then
    return
  end

  local entry = M.state.flat_tree[line_num]
  if entry.node.type == "directory" then
    local tree_view = require("diff-review.tree_view")
    if tree_view.set_directory_expanded(M.state.tree, entry.node.path, expanded) then
      M.state.flat_tree = nil
      M.render()
    end
  end
end

function M.open_fold()
  set_fold_state(true)
end

function M.close_fold()
  set_fold_state(false)
end

return M
