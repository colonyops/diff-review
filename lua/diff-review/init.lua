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
end

M.config = config

return M
