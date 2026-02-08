-- Neovim plugin entry point
-- This file is loaded automatically by Neovim

if vim.fn.has("nvim-0.8.0") == 0 then
  vim.api.nvim_err_writeln("diff-review.nvim requires Neovim >= 0.8.0")
  return
end

-- Prevent loading plugin twice
if vim.g.loaded_diff_review then
  return
end
vim.g.loaded_diff_review = 1

-- TODO: Setup commands and keymaps
