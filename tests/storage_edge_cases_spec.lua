local storage_utils = require("diff-review.storage_utils")

describe("storage_utils edge cases", function()
  local test_dir = "/tmp/diff-review-edge-" .. os.time()
  local test_file = test_dir .. "/test.json"

  after_each(function()
    -- Clean up test files
    vim.fn.delete(test_dir, "rf")
  end)

  describe("concurrent writes", function()
    it("should handle rapid successive writes", function()
      vim.fn.mkdir(test_dir, "p")

      -- Rapid successive writes
      for i = 1, 10 do
        local data = { iteration = i, timestamp = os.time() }
        local ok, err = storage_utils.write_json(test_file, data)
        assert.is_true(ok, "Write " .. i .. " failed: " .. tostring(err))
      end

      -- Verify final state is readable
      local data, err = storage_utils.read_json(test_file)
      assert.is_nil(err)
      assert.is_not_nil(data)
      assert.equals(10, data.iteration)
    end)
  end)

  describe("partial writes", function()
    it("should handle truncated JSON data", function()
      vim.fn.mkdir(test_dir, "p")

      -- Write partial JSON (simulating interrupted write)
      local file = io.open(test_file, "w")
      file:write('{"incomplete": "data", "missing')
      file:close()

      local data, err = storage_utils.read_json(test_file)

      assert.is_nil(data)
      assert.is_not_nil(err)
      assert.is_true(string.match(err, "Failed to parse JSON") ~= nil)
    end)

    it("should handle file with only opening bracket", function()
      vim.fn.mkdir(test_dir, "p")

      local file = io.open(test_file, "w")
      file:write("{")
      file:close()

      local data, err = storage_utils.read_json(test_file)

      assert.is_nil(data)
      assert.is_not_nil(err)
    end)

    it("should handle file with null bytes", function()
      vim.fn.mkdir(test_dir, "p")

      -- Write data with null byte
      local file = io.open(test_file, "w")
      file:write('{"data": "before\0after"}')
      file:close()

      local data, err = storage_utils.read_json(test_file)

      -- This might succeed or fail depending on JSON parser
      -- The test documents the actual behavior
      if err then
        assert.is_true(string.match(err, "Failed to parse JSON") ~= nil)
      end
    end)
  end)

  describe("directory permissions", function()
    it("should handle readonly parent directory", function()
      -- Create a readonly parent directory
      local readonly_dir = "/tmp/diff-review-readonly-" .. os.time()
      vim.fn.mkdir(readonly_dir, "p")

      -- Make it readonly
      vim.fn.setfperm(readonly_dir, "r-xr-xr-x")

      local readonly_file = readonly_dir .. "/nested/test.json"
      local ok, err = storage_utils.write_json(readonly_file, { test = "data" })

      -- Should fail
      assert.is_false(ok)
      assert.is_not_nil(err)

      -- Cleanup - restore permissions first
      vim.fn.setfperm(readonly_dir, "rwxr-xr-x")
      vim.fn.delete(readonly_dir, "rf")
    end)
  end)

  describe("large data", function()
    it("should handle large JSON objects", function()
      vim.fn.mkdir(test_dir, "p")

      -- Create large nested structure
      local large_data = { items = {} }
      for i = 1, 1000 do
        table.insert(large_data.items, {
          id = i,
          name = "Item " .. i,
          description = string.rep("x", 100),
        })
      end

      local ok, err = storage_utils.write_json(test_file, large_data)
      assert.is_true(ok, tostring(err))

      local read_data, read_err = storage_utils.read_json(test_file)
      assert.is_nil(read_err)
      assert.equals(1000, #read_data.items)
    end)

    it("should handle deeply nested objects", function()
      vim.fn.mkdir(test_dir, "p")

      -- Create deeply nested structure
      local deep_data = {}
      local current = deep_data
      for i = 1, 50 do
        current.level = i
        current.nested = {}
        current = current.nested
      end

      local ok, err = storage_utils.write_json(test_file, deep_data)
      assert.is_true(ok, tostring(err))

      local read_data, read_err = storage_utils.read_json(test_file)
      assert.is_nil(read_err)
      assert.is_not_nil(read_data)
    end)
  end)

  describe("special characters", function()
    it("should handle unicode characters", function()
      vim.fn.mkdir(test_dir, "p")

      local data = {
        unicode = "Hello 世界 🌍",
        emoji = "🚀💻🎉",
        special = "quotes\"escape\\slash",
      }

      local ok, err = storage_utils.write_json(test_file, data)
      assert.is_true(ok, tostring(err))

      local read_data, read_err = storage_utils.read_json(test_file)
      assert.is_nil(read_err)
      assert.equals(data.unicode, read_data.unicode)
      assert.equals(data.emoji, read_data.emoji)
    end)

    it("should handle newlines and tabs", function()
      vim.fn.mkdir(test_dir, "p")

      local data = {
        multiline = "Line 1\nLine 2\nLine 3",
        tabs = "Tab\there\tand\there",
      }

      local ok, err = storage_utils.write_json(test_file, data)
      assert.is_true(ok)

      local read_data, read_err = storage_utils.read_json(test_file)
      assert.is_nil(read_err)
      assert.equals(data.multiline, read_data.multiline)
      assert.equals(data.tabs, read_data.tabs)
    end)
  end)

  describe("file system edge cases", function()
    it("should handle very long file paths", function()
      -- Create a very long path (but not exceeding OS limits)
      local long_path = test_dir
      for i = 1, 10 do
        long_path = long_path .. "/subdir" .. i
      end
      long_path = long_path .. "/test.json"

      local ok, err = storage_utils.write_json(long_path, { test = "data" })

      -- Should fail because parent directories don't exist
      assert.is_false(ok)
      assert.is_not_nil(err)
    end)

    it("should handle file names with special characters", function()
      vim.fn.mkdir(test_dir, "p")

      -- File name with spaces and dashes
      local special_file = test_dir .. "/test-file with spaces.json"

      local ok, err = storage_utils.write_json(special_file, { test = "data" })
      assert.is_true(ok, tostring(err))

      local read_data, read_err = storage_utils.read_json(special_file)
      assert.is_nil(read_err)
      assert.equals("data", read_data.test)
    end)
  end)
end)
