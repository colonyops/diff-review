-- Minimal init file for running tests
-- This sets up the runtime path to include the plugin and plenary

local plenary_dir = os.getenv("PLENARY_DIR") or "/tmp/plenary.nvim"

-- Add plugin to runtime path
vim.opt.rtp:append(".")
vim.opt.rtp:append(plenary_dir)

-- Ensure plenary is loaded
vim.cmd("runtime! plugin/plenary.vim")

-- Set up test environment
vim.o.swapfile = false
vim.bo.swapfile = false
