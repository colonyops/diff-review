-- Test to verify test infrastructure is working
local helpers = require("tests.helpers")

describe("test infrastructure", function()
  it("can load test helpers", function()
    assert.is_not_nil(helpers)
    assert.is_function(helpers.create_buffer)
    assert.is_function(helpers.assert_eq)
  end)

  it("can create and cleanup buffers", function()
    local buf = helpers.create_buffer()
    assert.is_truthy(vim.api.nvim_buf_is_valid(buf))

    helpers.cleanup_buffer(buf)
    assert.is_falsy(vim.api.nvim_buf_is_valid(buf))
  end)

  it("has working assert helpers", function()
    helpers.assert_eq(1, 1, "numbers should be equal")
    helpers.assert_truthy(true, "true should be truthy")
    helpers.assert_falsy(false, "false should be falsy")
    helpers.assert_table_eq({ a = 1 }, { a = 1 }, "tables should be equal")
  end)

  it("can create temporary directories", function()
    local tmpdir = helpers.create_temp_dir()
    assert.is_truthy(vim.fn.isdirectory(tmpdir) == 1)

    helpers.cleanup_temp_dir(tmpdir)
    assert.is_truthy(vim.fn.isdirectory(tmpdir) == 0)
  end)

  it("can create test fixtures", function()
    local comment = helpers.create_comment_fixture({ id = 5, text = "custom" })
    assert.is_equal(5, comment.id)
    assert.is_equal("custom", comment.text)
    assert.is_equal("test.lua", comment.file)

    local diff = helpers.create_diff_fixture("main.lua")
    assert.is_equal("main.lua", diff.file)
    assert.is_not_nil(diff.changes)
    assert.is_not_nil(diff.hunks)
  end)
end)
