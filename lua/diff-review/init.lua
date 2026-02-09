local M = {}

local config = require("diff-review.config")

M.setup = function(opts)
  -- Validate Neovim version
  if vim.fn.has("nvim-0.8.0") == 0 then
    vim.notify("diff-review.nvim requires Neovim >= 0.8.0", vim.log.levels.ERROR)
    return
  end

  -- Setup configuration
  config.setup(opts)

  -- Initialize UI (signs, highlights)
  local ui = require("diff-review.ui")
  ui.init()

  -- Initialize note UI (signs, highlights)
  local note_ui = require("diff-review.note_ui")
  note_ui.init()

  -- Setup auto-save for comments
  local reviews = require("diff-review.reviews")
  reviews.setup_auto_save()

  -- Restore note mode session if needed
  local note_mode = require("diff-review.note_mode")
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      note_mode.restore_session()
    end,
    once = true,
  })

  -- Create user commands
  vim.api.nvim_create_user_command("DiffReview", function(opts)
    local parser = require("diff-review.parser")
    local function open_parsed(parsed)
      local valid, err = parser.validate(parsed)
      if not valid then
        vim.notify("Invalid arguments: " .. err, vim.log.levels.ERROR)
        return
      end

      require("diff-review.layout").open(
        parsed.type,
        parsed.base,
        parsed.head,
        parsed.pr_number
      )
    end

    if not opts.args or opts.args == "" then
      vim.ui.select(
        { "uncommitted", "ref", "range", "pr" },
        { prompt = "DiffReview type" },
        function(choice)
          if not choice then
            return
          end

          if choice == "uncommitted" then
            open_parsed(parser.parse_args(""))
          elseif choice == "ref" then
            vim.ui.input({ prompt = "Base ref" }, function(ref)
              if not ref or ref == "" then
                return
              end
              open_parsed(parser.parse_args(ref))
            end)
          elseif choice == "range" then
            vim.ui.input({ prompt = "Base ref" }, function(base)
              if not base or base == "" then
                return
              end
              vim.ui.input({ prompt = "Head ref" }, function(head)
                if not head or head == "" then
                  return
                end
                open_parsed(parser.parse_args(base .. ".." .. head))
              end)
            end)
          elseif choice == "pr" then
            vim.ui.input({ prompt = "PR number" }, function(pr_number)
              if not pr_number or pr_number == "" then
                return
              end
              open_parsed(parser.parse_args("pr:" .. pr_number))
            end)
          end
        end
      )
      return
    end

    open_parsed(parser.parse_args(opts.args))
  end, {
    desc = "Open diff review window",
    nargs = "?",  -- Optional arguments
    complete = function(arg_lead, cmd_line, cursor_pos)
      -- TODO: Add completion for refs, branches, PRs
      return {}
    end,
  })

  vim.api.nvim_create_user_command("DiffReviewClose", function()
    require("diff-review.layout").close()
  end, { desc = "Close diff review window" })

  vim.api.nvim_create_user_command("DiffReviewToggle", function()
    require("diff-review.layout").toggle()
  end, { desc = "Toggle diff review window (preserves state)" })

  vim.api.nvim_create_user_command("DiffReviewList", function()
    require("diff-review.picker").show()
  end, { desc = "List and switch between active reviews" })

  vim.api.nvim_create_user_command("DiffReviewCopy", function(opts)
    local export = require("diff-review.export")
    local mode = opts.args and opts.args ~= "" and opts.args or "comments"

    -- Validate mode
    local valid_modes = { comments = true, full = true, diff = true }
    if not valid_modes[mode] then
      vim.notify(
        string.format("Invalid export mode: %s. Use: comments, full, or diff", mode),
        vim.log.levels.ERROR
      )
      return
    end

    -- Export
    local content, err = export.export(mode)
    if err then
      vim.notify(string.format("Export failed: %s", err), vim.log.levels.ERROR)
      return
    end

    -- Copy to clipboard
    local success, clip_err = export.copy_to_clipboard(content)
    if not success then
      vim.notify(string.format("Clipboard copy failed: %s", clip_err), vim.log.levels.ERROR)
      return
    end

    local all_comments = require("diff-review.comments").get_all()
    vim.notify(
      string.format("Copied %d comment(s) to clipboard (%s mode)", #all_comments, mode),
      vim.log.levels.INFO
    )
  end, {
    desc = "Copy review comments to clipboard",
    nargs = "?",
    complete = function()
      return { "comments", "full", "diff" }
    end,
  })

  vim.api.nvim_create_user_command("DiffReviewSubmit", function()
    require("diff-review.submit").submit_current_review()
  end, { desc = "Submit review comments to GitHub" })

  vim.api.nvim_create_user_command("DiffReviewOpenFile", function()
    require("diff-review.actions").open_file()
  end, { desc = "Open file at cursor in current window" })

  vim.api.nvim_create_user_command("DiffReviewOpenFileSplit", function()
    require("diff-review.actions").open_file_split()
  end, { desc = "Open file at cursor in horizontal split" })

  vim.api.nvim_create_user_command("DiffReviewOpenFileVsplit", function()
    require("diff-review.actions").open_file_vsplit()
  end, { desc = "Open file at cursor in vertical split" })

  vim.api.nvim_create_user_command("DiffReviewHealth", function()
    local layout = require("diff-review.layout")
    local state = layout.get_state()

    local status = {
      "Diff Review Health Check",
      "========================",
      "",
      "Layout State:",
      "  is_open: " .. tostring(state.is_open),
      "  file_list_win valid: " .. tostring(state.file_list_win and vim.api.nvim_win_is_valid(state.file_list_win)),
      "  diff_win valid: " .. tostring(state.diff_win and vim.api.nvim_win_is_valid(state.diff_win)),
      "  file_list_buf valid: " .. tostring(state.file_list_buf and vim.api.nvim_buf_is_valid(state.file_list_buf)),
      "  diff_buf valid: " .. tostring(state.diff_buf and vim.api.nvim_buf_is_valid(state.diff_buf)),
      "",
      "Environment:",
      "  Current tab: " .. vim.api.nvim_get_current_tabpage(),
      "  Total tabs: " .. vim.fn.tabpagenr("$"),
      "  Total windows: " .. vim.fn.winnr("$"),
      "  Current buffer: " .. vim.api.nvim_get_current_buf(),
      "",
    }

    -- Check for session plugins
    local session_plugins = {
      "persisted",
      "auto-session",
      "possession",
      "resession",
    }

    table.insert(status, "Detected Session Plugins:")
    for _, plugin in ipairs(session_plugins) do
      local ok = pcall(require, plugin)
      if ok then
        table.insert(status, "  ✓ " .. plugin)
      end
    end

    vim.notify(table.concat(status, "\n"), vim.log.levels.INFO)
  end, { desc = "Check diff-review health and diagnose issues" })

  -- Note mode commands
  vim.api.nvim_create_user_command("DiffReviewNoteEnter", function(opts)
    local set_name = opts.args and opts.args ~= "" and opts.args or "default"
    require("diff-review.note_mode").enter(set_name)
  end, {
    desc = "Enter note mode",
    nargs = "?",
  })

  vim.api.nvim_create_user_command("DiffReviewNoteExit", function()
    require("diff-review.note_mode").exit()
  end, { desc = "Exit note mode" })

  vim.api.nvim_create_user_command("DiffReviewNoteToggle", function(opts)
    local set_name = opts.args and opts.args ~= "" and opts.args or "default"
    require("diff-review.note_mode").toggle(set_name)
  end, {
    desc = "Toggle note mode",
    nargs = "?",
  })

  vim.api.nvim_create_user_command("DiffReviewNoteClear", function()
    local note_mode = require("diff-review.note_mode")
    local state = note_mode.get_state()

    if not state.is_active then
      vim.notify("Note mode not active", vim.log.levels.WARN)
      return
    end

    -- Confirm before clearing
    vim.ui.select(
      { "Yes", "No" },
      { prompt = string.format("Clear all notes in set '%s'?", state.current_set) },
      function(choice)
        if choice == "Yes" then
          local notes = require("diff-review.notes")
          local count = notes.clear_set(state.current_set)
          vim.notify(string.format("Cleared %d notes from set '%s'", count, state.current_set), vim.log.levels.INFO)

          -- Refresh display
          local note_ui = require("diff-review.note_ui")
          note_ui.clear_all()
        end
      end
    )
  end, { desc = "Clear all notes in current set" })

  vim.api.nvim_create_user_command("DiffReviewNoteList", function()
    local note_persistence = require("diff-review.note_persistence")
    local note_mode = require("diff-review.note_mode")
    local state = note_mode.get_state()

    local sets = note_persistence.list_sets()

    if #sets == 0 then
      vim.notify("No note sets found", vim.log.levels.INFO)
      return
    end

    -- Format sets with indicator for current set
    local display_sets = {}
    for _, set in ipairs(sets) do
      if state.is_active and set == state.current_set then
        table.insert(display_sets, set .. " (active)")
      else
        table.insert(display_sets, set)
      end
    end

    vim.ui.select(display_sets, { prompt = "Select note set" }, function(choice)
      if not choice then
        return
      end

      -- Remove " (active)" suffix if present
      local selected_set = choice:gsub(" %(active%)$", "")

      if state.is_active then
        note_mode.switch_set(selected_set)
      else
        note_mode.enter(selected_set)
      end
    end)
  end, { desc = "List and switch note sets" })

  vim.api.nvim_create_user_command("DiffReviewNoteSwitch", function(opts)
    local set_name = opts.args

    if not set_name or set_name == "" then
      vim.notify("Usage: DiffReviewNoteSwitch <set_name>", vim.log.levels.ERROR)
      return
    end

    require("diff-review.note_mode").switch_set(set_name)
  end, {
    desc = "Switch to a different note set",
    nargs = 1,
    complete = function()
      local note_persistence = require("diff-review.note_persistence")
      return note_persistence.list_sets()
    end,
  })
end

M.config = config

return M
