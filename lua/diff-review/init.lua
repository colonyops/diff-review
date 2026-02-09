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

  -- Setup auto-save for comments
  local reviews = require("diff-review.reviews")
  reviews.setup_auto_save()

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
end

M.config = config

return M
