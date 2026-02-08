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

  -- Create user commands
  vim.api.nvim_create_user_command("DiffReview", function()
    require("diff-review.layout").open()
  end, { desc = "Open diff review window" })

  vim.api.nvim_create_user_command("DiffReviewClose", function()
    require("diff-review.layout").close()
  end, { desc = "Close diff review window" })
end

M.config = config

return M
