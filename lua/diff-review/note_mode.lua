local M = {}

local config = require("diff-review.config")
local notes = require("diff-review.notes")
local note_persistence = require("diff-review.note_persistence")
local note_ui = require("diff-review.note_ui")
local git_utils = require("diff-review.git_utils")

-- State
M.state = {
  is_active = false,
  current_set = "default",
  visible = true,
}

-- Autocmd group for note mode
local augroup = vim.api.nvim_create_augroup("DiffReviewNoteMode", { clear = true })
local mapped_buffers = {}

local function clear_buffer_keymaps(bufnr)
  local opts = config.get()
  if not opts or not opts.keymaps then
    return
  end
  local keymaps = opts.keymaps

  pcall(vim.keymap.del, "n", keymaps.add_comment, { buffer = bufnr })
  pcall(vim.keymap.del, "v", keymaps.add_comment, { buffer = bufnr })
  pcall(vim.keymap.del, "n", keymaps.edit_comment, { buffer = bufnr })
  pcall(vim.keymap.del, "n", keymaps.delete_comment, { buffer = bufnr })
  pcall(vim.keymap.del, "n", keymaps.list_comments, { buffer = bufnr })
  pcall(vim.keymap.del, "n", keymaps.view_all_comments, { buffer = bufnr })
end

-- Auto-save notes for current set
local function auto_save()
  if not M.state.is_active then
    return
  end

  local set_notes = notes.get_for_set(M.state.current_set)
  note_persistence.auto_save(set_notes, M.state.current_set)
end

-- Set up auto-save hook
notes.set_auto_save_hook(auto_save)

-- Save session state to global file
local function save_session()
  -- Save notes for current set before saving session state
  if M.state.is_active and M.state.current_set then
    local set_notes = notes.get_for_set(M.state.current_set)
    note_persistence.save(set_notes, M.state.current_set)
  end

  note_persistence.save_global_session({
    is_active = M.state.is_active,
    current_set = M.state.current_set,
    visible = M.state.visible,
  })
end

-- Load session state from global file
local function load_session()
  local state = note_persistence.load_global_session()
  if state then
    M.state.is_active = state.is_active
    M.state.current_set = state.current_set or "default"
    M.state.visible = state.visible ~= false -- Default to true if not set
  end
end

-- Set up buffer-local keymaps
local function setup_buffer_keymaps(bufnr)
  local opts = config.get()
  if not opts or not opts.keymaps then
    return -- Config not initialized, skip keymap setup
  end
  if mapped_buffers[bufnr] then
    return
  end
  local keymaps = opts.keymaps

  -- Add comment
  vim.keymap.set("n", keymaps.add_comment, function()
    require("diff-review.note_actions").add_comment()
  end, { buffer = bufnr, desc = "Add comment" })

  vim.keymap.set("v", keymaps.add_comment, function()
    require("diff-review.note_actions").add_range_comment()
  end, { buffer = bufnr, desc = "Add range comment" })

  -- Edit comment
  vim.keymap.set("n", keymaps.edit_comment, function()
    require("diff-review.note_actions").edit_comment()
  end, { buffer = bufnr, desc = "Edit comment" })

  -- Delete comment
  vim.keymap.set("n", keymaps.delete_comment, function()
    require("diff-review.note_actions").delete_comment()
  end, { buffer = bufnr, desc = "Delete comment" })

  -- List comments for current file
  vim.keymap.set("n", keymaps.list_comments, function()
    require("diff-review.note_actions").list_file_comments()
  end, { buffer = bufnr, desc = "List file comments" })

  -- View all comments
  vim.keymap.set("n", keymaps.view_all_comments, function()
    require("diff-review.note_actions").view_all_comments()
  end, { buffer = bufnr, desc = "View all comments" })

  mapped_buffers[bufnr] = true
end

-- Render notes for current buffer
local function render_current_buffer()
  if not M.state.is_active or not M.state.visible then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  -- Only render for normal files
  if filepath == "" or vim.bo[bufnr].buftype ~= "" then
    return
  end

  filepath = git_utils.normalize_file_key(filepath)

  note_ui.update_display(bufnr, filepath, M.state.current_set)
end

-- Enter note mode
function M.enter(set_name)
  if M.state.is_active then
    vim.notify("Note mode already active", vim.log.levels.INFO)
    return
  end

  set_name = set_name or "default"
  M.state.is_active = true
  M.state.current_set = set_name
  M.state.visible = true

  -- Load notes for this set
  local loaded_notes = note_persistence.auto_load(set_name)
  if #loaded_notes > 0 then
    notes.load_set(set_name, loaded_notes)
    vim.notify(string.format("Loaded %d notes from set '%s'", #loaded_notes, set_name), vim.log.levels.INFO)
  else
    vim.notify(string.format("Note mode active (set: %s)", set_name), vim.log.levels.INFO)
  end

  -- Set up autocmds for buffer navigation
  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function(ev)
      render_current_buffer()
      setup_buffer_keymaps(ev.buf)
    end,
  })

  -- Save session state on exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = save_session,
  })

  -- Render for current buffer
  render_current_buffer()

  -- Set up keymaps for current buffer
  local current_buf = vim.api.nvim_get_current_buf()
  setup_buffer_keymaps(current_buf)

  -- Save session state
  save_session()
end

-- Exit note mode
function M.exit()
  if not M.state.is_active then
    vim.notify("Note mode not active", vim.log.levels.INFO)
    return
  end

  -- Save notes before exiting
  local set_notes = notes.get_for_set(M.state.current_set)
  note_persistence.save(set_notes, M.state.current_set)

  M.state.is_active = false

  -- Clear all note displays
  note_ui.clear_all()

  -- Clear autocmds
  vim.api.nvim_clear_autocmds({ group = augroup })

  for bufnr, _ in pairs(mapped_buffers) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      clear_buffer_keymaps(bufnr)
    end
  end
  mapped_buffers = {}

  -- Clear session state
  note_persistence.clear_global_session()

  vim.notify("Note mode exited", vim.log.levels.INFO)
end

-- Toggle note mode
function M.toggle(set_name)
  if M.state.is_active then
    M.exit()
  else
    M.enter(set_name)
  end
end

-- Toggle note visibility (without exiting mode)
function M.toggle_visibility()
  if not M.state.is_active then
    vim.notify("Note mode not active", vim.log.levels.INFO)
    return
  end

  M.state.visible = not M.state.visible

  if M.state.visible then
    render_current_buffer()
    vim.notify("Notes visible", vim.log.levels.INFO)
  else
    note_ui.clear_all()
    vim.notify("Notes hidden", vim.log.levels.INFO)
  end

  save_session()
end

-- Switch to a different note set
function M.switch_set(new_set_name)
  if not M.state.is_active then
    vim.notify("Note mode not active", vim.log.levels.INFO)
    return
  end

  if new_set_name == M.state.current_set then
    vim.notify(string.format("Already using set '%s'", new_set_name), vim.log.levels.INFO)
    return
  end

  -- Save current set
  local current_notes = notes.get_for_set(M.state.current_set)
  note_persistence.save(current_notes, M.state.current_set)

  -- Switch to new set
  M.state.current_set = new_set_name

  -- Load new set
  local loaded_notes = note_persistence.auto_load(new_set_name)
  if #loaded_notes > 0 then
    notes.load_set(new_set_name, loaded_notes)
  end

  -- Re-render
  render_current_buffer()

  -- Save session state
  save_session()

  vim.notify(string.format("Switched to note set '%s' (%d notes)", new_set_name, #loaded_notes), vim.log.levels.INFO)
end

-- Restore session on startup
function M.restore_session()
  load_session()

  if not M.state.is_active then
    return
  end

  local opts = config.get()
  if not (opts.notes and opts.notes.auto_restore) then
    -- Clear session if auto-restore disabled
    note_persistence.clear_global_session()
    M.state.is_active = false
    return
  end

  -- Re-enter note mode silently
  M.state.is_active = false -- Reset state
  M.enter(M.state.current_set)
end

-- Get current state
function M.get_state()
  return M.state
end

return M
