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
    local parsed = parser.parse_args(opts.args)

    -- Validate
    local valid, err = parser.validate(parsed)
    if not valid then
      vim.notify("Invalid arguments: " .. err, vim.log.levels.ERROR)
      return
    end

    -- Open with parsed context
    require("diff-review.layout").open(
      parsed.type,
      parsed.base,
      parsed.head,
      parsed.pr_number
    )
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
end

M.config = config

return M
