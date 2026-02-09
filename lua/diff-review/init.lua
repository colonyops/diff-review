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

  -- Main DiffReview command with subcommands
  vim.api.nvim_create_user_command("DiffReview", function(opts)
    local args = vim.split(opts.args or "", "%s+", { trimempty = true })
    local subcommand = args[1]

    -- Known subcommands
    local subcommands = { close = true, toggle = true, list = true, copy = true, submit = true, health = true }

    -- If no subcommand or not a known subcommand, treat as open command with ref
    if not subcommand or not subcommands[subcommand] then
      -- Open diff review with optional ref
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
      return
    end

    -- Handle subcommands
    if subcommand == "close" then
      require("diff-review.layout").close()
    elseif subcommand == "toggle" then
      require("diff-review.layout").toggle()
    elseif subcommand == "list" then
      require("diff-review.picker").show()
    elseif subcommand == "copy" then
      local export = require("diff-review.export")
      local mode = args[2] or "comments"
      local valid_modes = { comments = true, full = true, diff = true }
      if not valid_modes[mode] then
        vim.notify("Invalid export mode: " .. mode .. ". Use: comments, full, or diff", vim.log.levels.ERROR)
        return
      end
      local content, err = export.export(mode)
      if err then
        vim.notify("Export failed: " .. err, vim.log.levels.ERROR)
        return
      end
      local success, clip_err = export.copy_to_clipboard(content)
      if not success then
        vim.notify("Clipboard copy failed: " .. clip_err, vim.log.levels.ERROR)
        return
      end
      local all_comments = require("diff-review.comments").get_all()
      vim.notify(
        string.format("Copied %d comment(s) to clipboard (%s mode)", #all_comments, mode),
        vim.log.levels.INFO
      )
    elseif subcommand == "submit" then
      require("diff-review.submit").submit_current_review()
    elseif subcommand == "health" then
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
      local session_plugins = { "persisted", "auto-session", "possession", "resession" }
      table.insert(status, "Detected Session Plugins:")
      for _, plugin in ipairs(session_plugins) do
        local ok = pcall(require, plugin)
        if ok then
          table.insert(status, "  ✓ " .. plugin)
        end
      end
      vim.notify(table.concat(status, "\n"), vim.log.levels.INFO)
    else
      vim.notify("Unknown subcommand: " .. subcommand .. "\nAvailable: close, toggle, list, copy, submit, health", vim.log.levels.ERROR)
    end
  end, {
    desc = "Diff review operations",
    nargs = "*",
    complete = function(arg_lead, cmd_line, cursor_pos)
      local args = vim.split(cmd_line, "%s+", { trimempty = true })
      if #args <= 2 then
        return vim.tbl_filter(function(cmd)
          return cmd:find(arg_lead, 1, true) == 1
        end, { "close", "toggle", "list", "copy", "submit", "health" })
      elseif args[2] == "copy" and #args <= 3 then
        return { "comments", "full", "diff" }
      end
      return {}
    end,
  })

  -- Shortcut for the most common operation
  vim.api.nvim_create_user_command("DiffReviewToggle", function()
    require("diff-review.layout").toggle()
  end, { desc = "Toggle diff review window (shortcut)" })


  -- DiffNote command with subcommands
  vim.api.nvim_create_user_command("DiffNote", function(opts)
    local args = vim.split(opts.args or "", "%s+", { trimempty = true })
    local subcommand = args[1]
    local note_mode = require("diff-review.note_mode")

    if not subcommand then
      vim.notify("Usage: DiffNote <subcommand>\nAvailable: enter, exit, toggle, clear, list, switch, copy", vim.log.levels.ERROR)
      return
    end

    if subcommand == "enter" then
      local set_name = args[2] or "default"
      note_mode.enter(set_name)
    elseif subcommand == "exit" then
      note_mode.exit()
    elseif subcommand == "toggle" then
      local set_name = args[2] or "default"
      note_mode.toggle(set_name)
    elseif subcommand == "clear" then
      local state = note_mode.get_state()
      if not state.is_active then
        vim.notify("Note mode not active", vim.log.levels.WARN)
        return
      end
      vim.ui.select(
        { "Yes", "No" },
        { prompt = string.format("Clear all notes in set '%s'?", state.current_set) },
        function(choice)
          if choice == "Yes" then
            local notes = require("diff-review.notes")
            local count = notes.clear_set(state.current_set)
            vim.notify(string.format("Cleared %d notes from set '%s'", count, state.current_set), vim.log.levels.INFO)
            local note_ui = require("diff-review.note_ui")
            note_ui.clear_all()
          end
        end
      )
    elseif subcommand == "list" then
      local note_persistence = require("diff-review.note_persistence")
      local state = note_mode.get_state()
      local sets = note_persistence.list_sets()
      if #sets == 0 then
        vim.notify("No note sets found", vim.log.levels.INFO)
        return
      end
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
        local selected_set = choice:gsub(" %(active%)$", "")
        if state.is_active then
          note_mode.switch_set(selected_set)
        else
          note_mode.enter(selected_set)
        end
      end)
    elseif subcommand == "switch" then
      local set_name = args[2]
      if not set_name then
        vim.notify("Usage: DiffNote switch <set_name>", vim.log.levels.ERROR)
        return
      end
      note_mode.switch_set(set_name)
    elseif subcommand == "copy" then
      local note_export = require("diff-review.note_export")
      local mode = args[2] or "notes"
      local valid_modes = { notes = true, full = true }
      if not valid_modes[mode] then
        vim.notify("Invalid export mode: " .. mode .. ". Use: notes or full", vim.log.levels.ERROR)
        return
      end
      local content, err
      if mode == "notes" then
        content, err = note_export.export_notes()
      else
        content, err = note_export.export_notes_with_context()
      end
      if err then
        vim.notify("Export failed: " .. err, vim.log.levels.ERROR)
        return
      end
      local success, clip_err = note_export.copy_to_clipboard(content)
      if not success then
        vim.notify("Clipboard copy failed: " .. clip_err, vim.log.levels.ERROR)
        return
      end
      local notes = require("diff-review.notes")
      local state = note_mode.get_state()
      local set_notes = notes.get_for_set(state.current_set)
      vim.notify(
        string.format("Copied %d note(s) to clipboard (%s mode)", #set_notes, mode),
        vim.log.levels.INFO
      )
    else
      vim.notify("Unknown subcommand: " .. subcommand .. "\nAvailable: enter, exit, toggle, clear, list, switch, copy", vim.log.levels.ERROR)
    end
  end, {
    desc = "Note mode operations",
    nargs = "+",
    complete = function(arg_lead, cmd_line, cursor_pos)
      local args = vim.split(cmd_line, "%s+", { trimempty = true })
      if #args <= 2 then
        return vim.tbl_filter(function(cmd)
          return cmd:find(arg_lead, 1, true) == 1
        end, { "enter", "exit", "toggle", "clear", "list", "switch", "copy" })
      elseif args[2] == "copy" and #args <= 3 then
        return { "notes", "full" }
      elseif args[2] == "switch" and #args <= 3 then
        local note_persistence = require("diff-review.note_persistence")
        return note_persistence.list_sets()
      end
      return {}
    end,
  })
end

M.config = config

return M
