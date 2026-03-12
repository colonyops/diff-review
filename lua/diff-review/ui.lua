local M = {}

local comments = require("diff-review.comments")
local config = require("diff-review.config")

-- Namespaces for highlights and signs
M.ns_id = vim.api.nvim_create_namespace("diff_review_comments")
M.cursor_ns_id = vim.api.nvim_create_namespace("diff_review_comment_cursor")
M.sign_group = "diff_review_comments"

-- Define sign for comments
local function define_signs()
  vim.fn.sign_define("DiffReviewComment", {
    text = "▸",
    texthl = "DiffReviewCommentGutter",
    linehl = "",
    numhl = "DiffReviewCommentGutter",
  })

  vim.fn.sign_define("DiffReviewCommentRange", {
    text = "▸",
    texthl = "DiffReviewCommentRangeGutter",
    linehl = "",
    numhl = "DiffReviewCommentRangeGutter",
  })
end

local function get_comment_fg()
  -- Get warning foreground color from the theme
  local ok_warn, warn = pcall(vim.api.nvim_get_hl, 0, { name = "DiagnosticWarn", link = false })
  local fg = ok_warn and warn and warn.fg or nil
  if not fg then
    local ok_warn_sign, warn_sign = pcall(vim.api.nvim_get_hl, 0, { name = "DiagnosticSignWarn", link = false })
    fg = ok_warn_sign and warn_sign and warn_sign.fg or nil
  end
  if not fg then
    local ok_warn_hl, warn_hl = pcall(vim.api.nvim_get_hl, 0, { name = "WarningMsg", link = false })
    fg = ok_warn_hl and warn_hl and warn_hl.fg or nil
  end

  return fg
end

local function get_comment_bg()
  local opts = config.get()
  if opts.ui.comment_line_bg then
    return opts.ui.comment_line_bg
  end
  return nil
end

local function set_comment_line_highlight()
  local opts = config.get()
  if opts.ui.comment_line_hl then
    vim.api.nvim_set_hl(0, "DiffReviewCommentLine", { link = opts.ui.comment_line_hl })
  else
    -- No background for comment lines
    vim.api.nvim_set_hl(0, "DiffReviewCommentLine", {})
  end
end

-- Blend a color toward a base color by a given factor (0.0 = full color, 1.0 = full base)
local function blend(color, base, factor)
  local r1 = math.floor(color / 0x10000)
  local g1 = math.floor((color % 0x10000) / 0x100)
  local b1 = color % 0x100
  local r2 = math.floor(base / 0x10000)
  local g2 = math.floor((base % 0x10000) / 0x100)
  local b2 = base % 0x100
  local r = math.floor(r1 + (r2 - r1) * factor)
  local g = math.floor(g1 + (g2 - g1) * factor)
  local b = math.floor(b1 + (b2 - b1) * factor)
  return r * 0x10000 + g * 0x100 + b
end

-- Get the normal background color
local function get_normal_bg()
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = "Normal", link = false })
  if ok and hl and hl.bg then
    return hl.bg
  end
  return 0x1e1e2e -- fallback dark bg
end

-- Create subtle diff highlight groups by blending theme colors with the background
local function define_diff_highlights()
  local bg = get_normal_bg()
  local opts = config.get()
  local blend_factor = opts.diff and opts.diff.highlight_blend or 0.60

  -- Get DiffAdd bg color
  local ok_add, add_hl = pcall(vim.api.nvim_get_hl, 0, { name = "DiffAdd", link = false })
  if ok_add and add_hl and add_hl.bg then
    vim.api.nvim_set_hl(0, "DiffReviewAdd", { bg = blend(add_hl.bg, bg, blend_factor) })
  else
    vim.api.nvim_set_hl(0, "DiffReviewAdd", { bg = blend(0x2e7d32, bg, blend_factor) })
  end

  -- Get DiffDelete bg color
  local ok_del, del_hl = pcall(vim.api.nvim_get_hl, 0, { name = "DiffDelete", link = false })
  if ok_del and del_hl and del_hl.bg then
    vim.api.nvim_set_hl(0, "DiffReviewDelete", { bg = blend(del_hl.bg, bg, blend_factor) })
  else
    vim.api.nvim_set_hl(0, "DiffReviewDelete", { bg = blend(0xc62828, bg, blend_factor) })
  end
end

-- Initialize UI
function M.init()
  define_signs()

  -- Define highlight groups with warning color
  local fg = get_comment_fg()
  if fg then
    vim.api.nvim_set_hl(0, "DiffReviewComment", { fg = fg })
    vim.api.nvim_set_hl(0, "DiffReviewCommentRange", { fg = fg })
  else
    vim.api.nvim_set_hl(0, "DiffReviewComment", { link = "WarningMsg" })
    vim.api.nvim_set_hl(0, "DiffReviewCommentRange", { link = "WarningMsg" })
  end
  set_comment_line_highlight()
  vim.api.nvim_set_hl(0, "DiffReviewCommentGutter", { link = "DiagnosticSignInfo" })
  vim.api.nvim_set_hl(0, "DiffReviewCommentRangeGutter", { link = "DiagnosticSignHint" })

  -- Define renamed file highlight (cyan-ish)
  vim.api.nvim_set_hl(0, "DiffReviewRenamed", { link = "Function" })

  -- Define subtle diff line highlights
  define_diff_highlights()

  -- Re-define highlights when colorscheme changes
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("DiffReviewHighlights", { clear = true }),
    callback = function()
      define_diff_highlights()
    end,
  })
end

-- Clear all comment UI for a buffer
function M.clear_comments(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  -- Clear virtual text
  vim.api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)
  vim.api.nvim_buf_clear_namespace(buf, M.cursor_ns_id, 0, -1)

  -- Clear signs
  vim.fn.sign_unplace(M.sign_group, { buffer = buf })
end

-- Wrap a line of text at the specified width, preserving indentation
local function wrap_line(line, max_width, indent)
  if #line <= max_width then
    return { line }
  end

  local wrapped = {}
  local current = line

  while #current > max_width do
    -- Find the last space before max_width
    local wrap_pos = max_width
    for i = max_width, 1, -1 do
      if current:sub(i, i):match("%s") then
        wrap_pos = i
        break
      end
    end

    -- If no space found, hard break at max_width
    if wrap_pos == max_width and not current:sub(wrap_pos, wrap_pos):match("%s") then
      wrap_pos = max_width
    end

    -- Add the wrapped line
    table.insert(wrapped, current:sub(1, wrap_pos):match("^(.-)%s*$"))

    -- Continue with remainder, adding indent
    current = indent .. current:sub(wrap_pos + 1):match("^%s*(.*)$")
  end

  -- Add remaining text
  if #current > 0 then
    table.insert(wrapped, current)
  end

  return wrapped
end

-- Resolve a buffer line to a file line number using the diff line mapping
local function resolve_file_line(buf_line)
  local diff = require("diff-review.diff")
  if not diff._line_mapping then
    return buf_line
  end
  local entry = diff._line_mapping[buf_line]
  if not entry then
    return buf_line
  end
  return entry.new_line or entry.old_line or buf_line
end

-- Format comment text for display
local function format_comment_text(comment)
  local opts = config.get()
  local max_width = opts.ui.text_wrap_width or 80
  local lines = vim.split(comment.text, "\n")
  local formatted = {}

  -- Add line range header
  local line_info
  if comment.type == "range" and comment.line_range then
    line_info = string.format("  L%d-L%d", resolve_file_line(comment.line_range.start), resolve_file_line(comment.line_range["end"]))
  else
    line_info = string.format("  L%d", resolve_file_line(comment.line))
  end
  table.insert(formatted, line_info)

  -- Add comment text lines with indentation and wrapping
  for _, line in ipairs(lines) do
    local prefixed_line = "   " .. line
    local wrapped = wrap_line(prefixed_line, max_width, "   ")
    for _, wrapped_line in ipairs(wrapped) do
      table.insert(formatted, wrapped_line)
    end
  end

  return formatted
end

-- Update comment display for a buffer
function M.update_comment_display()
  local layout = require("diff-review.layout")
  local state = layout.get_state()

  if not state.is_open or not state.diff_buf or not vim.api.nvim_buf_is_valid(state.diff_buf) then
    return
  end

  -- Check if window is still valid
  if not state.diff_win or not vim.api.nvim_win_is_valid(state.diff_win) then
    return
  end

  -- Only apply comment line highlights if user configured one,
  -- otherwise the empty highlight overrides diff add/delete colors
  local opts = config.get()
  local has_comment_line_hl = opts.ui.comment_line_hl ~= nil

  -- Clear existing comments
  local diff = require("diff-review.diff")
  diff._comment_lines = {}
  M.clear_comments(state.diff_buf)

  -- Get current file
  local file_list = require("diff-review.file_list")
  local files = file_list.state.files
  local current_index = file_list.state.current_index

  if #files == 0 or current_index < 1 or current_index > #files then
    return
  end

  local current_file = files[current_index].path
  local file_comments = comments.get_for_file(current_file)

  if #file_comments == 0 then
    return
  end

  -- Get buffer line count for validation
  local line_count = vim.api.nvim_buf_line_count(state.diff_buf)

  -- Track successfully placed comments
  local placed_count = 0
  local failed_comments = {}

  -- Collect virtual text by display line to avoid overwriting on overlaps
  local virtual_by_line = {}

  -- Place signs and line highlights for each comment
  for _, comment in ipairs(file_comments) do
    -- Validate line number
    if not comment.line or comment.line < 1 then
      table.insert(failed_comments, {
        id = comment.id,
        reason = string.format("Invalid line number: %s", tostring(comment.line))
      })
      goto continue
    end

    -- Clamp line number to buffer bounds instead of rejecting
    local display_line = math.min(comment.line, line_count)
    if display_line ~= comment.line then
      vim.notify(
        string.format("Comment #%d line %d out of bounds, clamped to %d", comment.id, comment.line, display_line),
        vim.log.levels.WARN
      )
      comment.line = display_line
    end

    local sign_name = comment.type == "range" and "DiffReviewCommentRange" or "DiffReviewComment"

    -- Place sign at the comment line (using display_line which is clamped)
    local ok, err = pcall(vim.fn.sign_place, comment.id, M.sign_group, sign_name, state.diff_buf, {
      lnum = display_line,
      priority = 10,
    })

    if not ok then
      table.insert(failed_comments, {
        id = comment.id,
        reason = string.format("Sign placement failed: %s", tostring(err))
      })
      goto continue
    end

    -- For range comments, display at the end of the range
    local virt_display_line = display_line
    if comment.type == "range" and comment.line_range then
      virt_display_line = math.min(comment.line_range["end"], line_count)
    end

    if virt_display_line >= 1 and virt_display_line <= line_count then
      virtual_by_line[virt_display_line] = virtual_by_line[virt_display_line] or {}
      table.insert(virtual_by_line[virt_display_line], comment)
    end

    -- Mark lines for statuscolumn highlighting and place range signs
    if comment.type == "range" and comment.line_range then
      local range_start = math.max(comment.line_range.start, 1)
      local range_end = math.min(comment.line_range["end"], line_count)

      for line = range_start, range_end do
        diff._comment_lines[line] = true
        pcall(vim.fn.sign_place, comment.id * 1000 + line, M.sign_group, sign_name, state.diff_buf, {
          lnum = line,
          priority = 10,
        })
        if has_comment_line_hl then
          pcall(vim.api.nvim_buf_set_extmark, state.diff_buf, M.ns_id, line - 1, 0, {
            linehl = "DiffReviewCommentLine",
            hl_mode = "combine",
            priority = 200,
          })
        end
      end
    else
      diff._comment_lines[display_line] = true
      if has_comment_line_hl then
        pcall(vim.api.nvim_buf_set_extmark, state.diff_buf, M.ns_id, display_line - 1, 0, {
          linehl = "DiffReviewCommentLine",
          hl_mode = "combine",
          priority = 200,
        })
      end
    end

    placed_count = placed_count + 1

    ::continue::
  end

  -- Render virtual text once per line to avoid overlap replacement
  for line, line_comments in pairs(virtual_by_line) do
    local virt_lines = {}
    for idx, comment in ipairs(line_comments) do
      if idx > 1 then
        table.insert(virt_lines, { { "", "DiffReviewComment" } })
      end
      local formatted_text = format_comment_text(comment)
      for _, text in ipairs(formatted_text) do
        table.insert(virt_lines, { { text, "DiffReviewComment" } })
      end
    end

    local ok, err = pcall(vim.api.nvim_buf_set_extmark, state.diff_buf, M.ns_id, line - 1, 0, {
      virt_lines = virt_lines,
      virt_lines_above = false,
      hl_mode = "combine",
    })

    if not ok then
      table.insert(failed_comments, {
        id = 0,
        reason = string.format("Virtual text failed: %s", tostring(err))
      })
    end
  end

  -- Report any failures
  if #failed_comments > 0 then
    local msg = string.format("Failed to display %d comment(s):", #failed_comments)
    for _, failed in ipairs(failed_comments) do
      msg = msg .. string.format("\n  Comment #%d: %s", failed.id, failed.reason)
    end
    vim.notify(msg, vim.log.levels.WARN)
  end
end

-- Show comment text at cursor line for visibility
function M.update_cursor_comment()
  local layout = require("diff-review.layout")
  local state = layout.get_state()

  if not state.is_open or not state.diff_buf or not vim.api.nvim_buf_is_valid(state.diff_buf) then
    return
  end
  if not state.diff_win or not vim.api.nvim_win_is_valid(state.diff_win) then
    return
  end

  vim.api.nvim_buf_clear_namespace(state.diff_buf, M.cursor_ns_id, 0, -1)

  local file_list = require("diff-review.file_list")
  local files = file_list.state.files
  local current_index = file_list.state.current_index
  if #files == 0 or current_index < 1 or current_index > #files then
    return
  end

  local current_file = files[current_index].path
  local cursor = vim.api.nvim_win_get_cursor(state.diff_win)
  local line = cursor[1]
  local line_comments = comments.get_at_line(current_file, line)
  if #line_comments == 0 then
    return
  end

  local virt_lines = {}
  for _, comment in ipairs(line_comments) do
    local formatted = format_comment_text(comment)
    for _, text in ipairs(formatted) do
      table.insert(virt_lines, { { text, "DiffReviewComment" } })
    end
  end

  pcall(vim.api.nvim_buf_set_extmark, state.diff_buf, M.cursor_ns_id, line - 1, 0, {
    virt_lines = virt_lines,
    virt_lines_above = true,
    hl_mode = "combine",
  })
end

-- Create a bordered window
function M.create_border(title)
  -- TODO: Implement custom border creation if needed
end

-- Apply color scheme
function M.apply_colors()
  local opts = config.get()
  -- Apply custom colors from config
  for name, hl_group in pairs(opts.ui.colors) do
    -- Colors are already defined, this is a placeholder for custom styling
  end
end

return M
