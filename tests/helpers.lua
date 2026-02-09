-- Test helpers for diff-review.nvim tests
local M = {}

-- Create a new buffer and return its handle
function M.create_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  return buf
end

-- Create a test window with a buffer
function M.create_window(buf)
  buf = buf or M.create_buffer()
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = 80,
    height = 20,
    row = 0,
    col = 0,
  })
  return win, buf
end

-- Clean up buffer
function M.cleanup_buffer(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

-- Clean up window
function M.cleanup_window(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

-- Assert helpers
function M.assert_eq(actual, expected, message)
  assert.are.equal(expected, actual, message)
end

function M.assert_truthy(value, message)
  assert.is_true(value ~= nil and value ~= false, message)
end

function M.assert_falsy(value, message)
  assert.is_true(value == nil or value == false, message)
end

function M.assert_table_eq(actual, expected, message)
  assert.are.same(expected, actual, message)
end

-- Mock git command execution
function M.mock_git_command(return_value)
  local original_popen = io.popen

  _G.io.popen = function(cmd)
    return {
      read = function() return return_value end,
      close = function() return true end,
    }
  end

  return function()
    _G.io.popen = original_popen
  end
end

-- Mock vim.fn.shellescape
function M.mock_shellescape()
  local original = vim.fn.shellescape

  vim.fn.shellescape = function(str)
    return "'" .. str .. "'"
  end

  return function()
    vim.fn.shellescape = original
  end
end

-- Create a test file with content
function M.write_test_file(filepath, content)
  local file = io.open(filepath, "w")
  if not file then
    error("Failed to write test file: " .. filepath)
  end
  file:write(content)
  file:close()
end

-- Read test file content
function M.read_test_file(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end

-- Clean up test file
function M.cleanup_test_file(filepath)
  os.remove(filepath)
end

-- Create a temporary directory for tests
function M.create_temp_dir()
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, "p")
  return tmpdir
end

-- Clean up temporary directory
function M.cleanup_temp_dir(dir)
  vim.fn.delete(dir, "rf")
end

-- Wait for a condition with timeout
function M.wait_for(condition, timeout_ms, interval_ms)
  timeout_ms = timeout_ms or 1000
  interval_ms = interval_ms or 10

  local start = vim.loop.now()
  while vim.loop.now() - start < timeout_ms do
    if condition() then
      return true
    end
    vim.wait(interval_ms)
  end
  return false
end

-- Create a comment test fixture
function M.create_comment_fixture(overrides)
  local defaults = {
    id = 1,
    file = "test.lua",
    line = 10,
    text = "Test comment",
    created_at = os.time(),
    updated_at = os.time(),
    type = "single",
  }

  return vim.tbl_extend("force", defaults, overrides or {})
end

-- Create a diff fixture
function M.create_diff_fixture(file_path, changes)
  changes = changes or {
    { type = "add", line = 5, content = "+added line" },
    { type = "remove", line = 10, content = "-removed line" },
  }

  return {
    file = file_path,
    changes = changes,
    hunks = { { start = 1, count = #changes } },
  }
end

-- Reset module state (useful for between tests)
function M.reset_module(module_name)
  package.loaded[module_name] = nil
  return require(module_name)
end

-- Load a fixture file
function M.load_fixture(name)
  local fixtures_path = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h") .. "/fixtures/"
  local path = fixtures_path .. name
  local file = io.open(path, "r")
  if not file then
    error("Failed to load fixture: " .. path)
  end
  local content = file:read("*a")
  file:close()
  return content
end

-- Load a JSON fixture file
function M.load_json_fixture(name)
  local content = M.load_fixture(name)
  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    error("Failed to parse JSON fixture: " .. name)
  end
  return data
end

-- Get the path to a fixture file
function M.fixture_path(name)
  local fixtures_path = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h") .. "/fixtures/"
  return fixtures_path .. name
end

-- Load a private (local) function from a module for testing
-- This uses debug.getupvalue to access local functions
function M.load_private_function(module, func_name)
  -- Look through all functions in the module to find one that has the private function as an upvalue
  for key, value in pairs(module) do
    if type(value) == "function" then
      local i = 1
      while true do
        local name, func = debug.getupvalue(value, i)
        if not name then break end
        if name == func_name and type(func) == "function" then
          return func
        end
        i = i + 1
      end
    end
  end
  error("Private function not found: " .. func_name)
end

return M
