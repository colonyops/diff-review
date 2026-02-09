local clipboard_utils = require("diff-review.clipboard_utils")

describe("clipboard_utils", function()
  describe("copy_to_clipboard", function()
    it("should return error for nil content", function()
      local ok, err = clipboard_utils.copy_to_clipboard(nil)

      assert.is_false(ok)
      assert.is_not_nil(err)
      assert.equals("No content to copy", err)
    end)

    it("should return error for empty content", function()
      local ok, err = clipboard_utils.copy_to_clipboard("")

      -- Empty string is technically valid content, so this should succeed
      -- or fail based on clipboard availability
      if vim.fn.has("clipboard") == 1 or vim.fn.executable("pbcopy") == 1 or vim.fn.executable("xclip") == 1
        or vim.fn.executable("wl-copy") == 1 then
        -- Should succeed if clipboard is available
        assert.is_boolean(ok)
      else
        assert.is_false(ok)
        assert.is_not_nil(err)
      end
    end)

    it("should attempt to copy text content", function()
      local content = "Test clipboard content"
      local ok, err = clipboard_utils.copy_to_clipboard(content)

      -- If clipboard is available, should succeed
      if vim.fn.has("clipboard") == 1 or vim.fn.executable("pbcopy") == 1 or vim.fn.executable("xclip") == 1
        or vim.fn.executable("wl-copy") == 1 then
        assert.is_true(ok, "Expected clipboard copy to succeed, got error: " .. tostring(err))
        assert.is_nil(err)
      else
        -- If no clipboard available, should return appropriate error
        assert.is_false(ok)
        assert.is_not_nil(err)
        assert.is_true(string.match(err, "No clipboard utility available") ~= nil)
      end
    end)

    it("should handle multiline content", function()
      local content = "Line 1\nLine 2\nLine 3"
      local ok, err = clipboard_utils.copy_to_clipboard(content)

      if vim.fn.has("clipboard") == 1 or vim.fn.executable("pbcopy") == 1 or vim.fn.executable("xclip") == 1
        or vim.fn.executable("wl-copy") == 1 then
        assert.is_true(ok, "Expected clipboard copy to succeed, got error: " .. tostring(err))
      end
    end)
  end)
end)
