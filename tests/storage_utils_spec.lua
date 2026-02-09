local storage_utils = require("diff-review.storage_utils")

describe("storage_utils", function()
  local test_dir = "/tmp/diff-review-test-" .. os.time()
  local test_file = test_dir .. "/test.json"

  after_each(function()
    -- Clean up test files
    vim.fn.delete(test_dir, "rf")
  end)

  describe("ensure_dir", function()
    it("should create directory if it doesn't exist", function()
      local ok, err = storage_utils.ensure_dir(test_dir)

      assert.is_true(ok)
      assert.is_nil(err)
      assert.equals(1, vim.fn.isdirectory(test_dir))
    end)

    it("should succeed if directory already exists", function()
      vim.fn.mkdir(test_dir, "p")

      local ok, err = storage_utils.ensure_dir(test_dir)

      assert.is_true(ok)
      assert.is_nil(err)
    end)

    it("should create nested directories", function()
      local nested_dir = test_dir .. "/nested/deep"

      local ok, err = storage_utils.ensure_dir(nested_dir)

      assert.is_true(ok)
      assert.is_nil(err)
      assert.equals(1, vim.fn.isdirectory(nested_dir))
    end)
  end)

  describe("file_exists", function()
    it("should return false for non-existent file", function()
      assert.is_false(storage_utils.file_exists(test_file))
    end)

    it("should return true for existing file", function()
      vim.fn.mkdir(test_dir, "p")
      local file = io.open(test_file, "w")
      file:write("test")
      file:close()

      assert.is_true(storage_utils.file_exists(test_file))
    end)
  end)

  describe("write_json and read_json", function()
    before_each(function()
      vim.fn.mkdir(test_dir, "p")
    end)

    it("should write and read simple data", function()
      local data = { foo = "bar", count = 42 }

      local write_ok, write_err = storage_utils.write_json(test_file, data)
      assert.is_true(write_ok)
      assert.is_nil(write_err)

      local read_data, read_err = storage_utils.read_json(test_file)
      assert.is_nil(read_err)
      assert.are.same(data, read_data)
    end)

    it("should write and read nested data", function()
      local data = {
        version = 1,
        items = {
          { id = 1, name = "first" },
          { id = 2, name = "second" },
        },
      }

      storage_utils.write_json(test_file, data)
      local read_data = storage_utils.read_json(test_file)

      assert.are.same(data, read_data)
    end)

    it("should handle arrays", function()
      local data = { 1, 2, 3, 4, 5 }

      storage_utils.write_json(test_file, data)
      local read_data = storage_utils.read_json(test_file)

      assert.are.same(data, read_data)
    end)

    it("should return error for non-existent file", function()
      local data, err = storage_utils.read_json("/nonexistent/path/file.json")

      assert.is_nil(data)
      assert.is_not_nil(err)
      assert.is_true(string.match(err, "File not found") ~= nil)
    end)

    it("should return error for invalid JSON", function()
      -- Write invalid JSON
      local file = io.open(test_file, "w")
      file:write("{ invalid json }")
      file:close()

      local data, err = storage_utils.read_json(test_file)

      assert.is_nil(data)
      assert.is_not_nil(err)
      assert.is_true(string.match(err, "Failed to parse JSON") ~= nil)
    end)

    it("should return error for empty file", function()
      -- Write empty file
      local file = io.open(test_file, "w")
      file:close()

      local data, err = storage_utils.read_json(test_file)

      assert.is_nil(data)
      assert.is_not_nil(err)
      assert.is_true(string.match(err, "Empty file") ~= nil)
    end)

    it("should return error when writing to invalid path", function()
      local ok, err = storage_utils.write_json("/invalid/readonly/path.json", { test = "data" })

      assert.is_false(ok)
      assert.is_not_nil(err)
      assert.is_true(string.match(err, "Failed to open") ~= nil)
    end)
  end)
end)
