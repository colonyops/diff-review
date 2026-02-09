-- Minimal init.lua for running tests
-- This loads only the test dependencies

-- Add current directory to runtimepath so we can require our plugin modules
vim.opt.runtimepath:append(".")

-- Add plenary.nvim to runtimepath (required for testing)
local plenary_path = vim.fn.stdpath("data") .. "/site/pack/vendor/start/plenary.nvim"
vim.opt.runtimepath:append(plenary_path)

-- Ensure plenary is available
local plenary_ok, plenary = pcall(require, "plenary.busted")
if not plenary_ok then
  print(
    string.format(
      "plenary.nvim not found at %s\nInstall it with: git clone https://github.com/nvim-lua/plenary.nvim %s",
      plenary_path,
      plenary_path
    )
  )
  os.exit(1)
end

-- Set up test environment (don't load plugin yet - tests will do that)
vim.opt.swapfile = false

-- Note: Individual tests will require('diff-review').setup() if needed
