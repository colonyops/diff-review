-- Unit tests for comments.lua
local helpers = require("tests.helpers")

describe("comments", function()
  local comments

  before_each(function()
    -- Reset the module to clear state
    comments = helpers.reset_module("diff-review.comments")
  end)

  describe("add", function()
    it("adds a single-line comment", function()
      local comment = comments.add("test.lua", 10, "Test comment")

      assert.is_not_nil(comment)
      helpers.assert_eq(comment.id, 1)
      helpers.assert_eq(comment.file, "test.lua")
      helpers.assert_eq(comment.line, 10)
      helpers.assert_eq(comment.text, "Test comment")
      helpers.assert_eq(comment.type, "single")
      assert.is_not_nil(comment.created_at)
      assert.is_not_nil(comment.updated_at)
    end)

    it("adds a range comment", function()
      local range = { start = 10, ["end"] = 15 }
      local comment = comments.add("test.lua", 10, "Range comment", range)

      assert.is_not_nil(comment)
      helpers.assert_eq(comment.type, "range")
      helpers.assert_table_eq(comment.line_range, range)
    end)

    it("generates unique IDs for multiple comments", function()
      local c1 = comments.add("test.lua", 1, "Comment 1")
      local c2 = comments.add("test.lua", 2, "Comment 2")
      local c3 = comments.add("test.lua", 3, "Comment 3")

      helpers.assert_eq(c1.id, 1)
      helpers.assert_eq(c2.id, 2)
      helpers.assert_eq(c3.id, 3)
    end)

    it("increments next_id after each add", function()
      helpers.assert_eq(comments.next_id, 1)
      comments.add("test.lua", 1, "Comment")
      helpers.assert_eq(comments.next_id, 2)
    end)

    it("allows adding multiple comments on same line", function()
      local c1 = comments.add("test.lua", 10, "First comment")
      local c2 = comments.add("test.lua", 10, "Second comment")

      assert.is_not_nil(c1)
      assert.is_not_nil(c2)
      assert.are_not.equal(c1.id, c2.id)
    end)
  end)

  describe("get", function()
    it("retrieves comment by ID", function()
      local added = comments.add("test.lua", 10, "Test comment")
      local retrieved = comments.get(added.id)

      helpers.assert_eq(retrieved.id, added.id)
      helpers.assert_eq(retrieved.text, "Test comment")
    end)

    it("returns nil for non-existent ID", function()
      local result = comments.get(999)
      helpers.assert_eq(result, nil)
    end)

    it("returns nil when no comments exist", function()
      local result = comments.get(1)
      helpers.assert_eq(result, nil)
    end)
  end)

  describe("get_for_file", function()
    it("returns all comments for a file", function()
      comments.add("file1.lua", 10, "Comment 1")
      comments.add("file1.lua", 20, "Comment 2")
      comments.add("file2.lua", 30, "Comment 3")

      local file1_comments = comments.get_for_file("file1.lua")

      helpers.assert_eq(#file1_comments, 2)
      helpers.assert_eq(file1_comments[1].text, "Comment 1")
      helpers.assert_eq(file1_comments[2].text, "Comment 2")
    end)

    it("returns empty array for file with no comments", function()
      comments.add("file1.lua", 10, "Comment")

      local result = comments.get_for_file("file2.lua")

      helpers.assert_table_eq(result, {})
    end)

    it("returns empty array when no comments exist", function()
      local result = comments.get_for_file("any.lua")
      helpers.assert_table_eq(result, {})
    end)
  end)

  describe("get_at_line", function()
    it("returns single-line comment at exact line", function()
      comments.add("test.lua", 10, "Comment at line 10")
      comments.add("test.lua", 20, "Comment at line 20")

      local result = comments.get_at_line("test.lua", 10)

      helpers.assert_eq(#result, 1)
      helpers.assert_eq(result[1].text, "Comment at line 10")
    end)

    it("returns range comment when line is within range", function()
      local range = { start = 10, ["end"] = 15 }
      comments.add("test.lua", 10, "Range comment", range)

      local result_start = comments.get_at_line("test.lua", 10)
      local result_mid = comments.get_at_line("test.lua", 12)
      local result_end = comments.get_at_line("test.lua", 15)

      helpers.assert_eq(#result_start, 1)
      helpers.assert_eq(#result_mid, 1)
      helpers.assert_eq(#result_end, 1)
    end)

    it("does not return range comment outside range", function()
      local range = { start = 10, ["end"] = 15 }
      comments.add("test.lua", 10, "Range comment", range)

      local result_before = comments.get_at_line("test.lua", 9)
      local result_after = comments.get_at_line("test.lua", 16)

      helpers.assert_table_eq(result_before, {})
      helpers.assert_table_eq(result_after, {})
    end)

    it("returns multiple comments at same line", function()
      comments.add("test.lua", 10, "Comment 1")
      comments.add("test.lua", 10, "Comment 2")

      local result = comments.get_at_line("test.lua", 10)

      helpers.assert_eq(#result, 2)
    end)

    it("filters by file", function()
      comments.add("file1.lua", 10, "File 1 comment")
      comments.add("file2.lua", 10, "File 2 comment")

      local result = comments.get_at_line("file1.lua", 10)

      helpers.assert_eq(#result, 1)
      helpers.assert_eq(result[1].text, "File 1 comment")
    end)

    it("returns empty array when no comments at line", function()
      comments.add("test.lua", 10, "Comment")

      local result = comments.get_at_line("test.lua", 99)

      helpers.assert_table_eq(result, {})
    end)
  end)

  describe("update", function()
    it("updates comment text", function()
      local comment = comments.add("test.lua", 10, "Original text")
      local original_updated_at = comment.updated_at

      -- Wait a bit to ensure timestamp changes
      vim.wait(10)

      local success = comments.update(comment.id, "Updated text")

      helpers.assert_truthy(success)

      local updated = comments.get(comment.id)
      helpers.assert_eq(updated.text, "Updated text")
      assert.is_true(updated.updated_at >= original_updated_at)
    end)

    it("preserves other comment fields", function()
      local comment = comments.add("test.lua", 10, "Original")
      local created_at = comment.created_at

      comments.update(comment.id, "Updated")

      local updated = comments.get(comment.id)
      helpers.assert_eq(updated.id, comment.id)
      helpers.assert_eq(updated.file, "test.lua")
      helpers.assert_eq(updated.line, 10)
      helpers.assert_eq(updated.created_at, created_at)
    end)

    it("returns false for non-existent comment", function()
      local success = comments.update(999, "New text")
      helpers.assert_falsy(success)
    end)
  end)

  describe("delete", function()
    it("deletes comment by ID", function()
      local comment = comments.add("test.lua", 10, "To be deleted")

      local success = comments.delete(comment.id)

      helpers.assert_truthy(success)

      local result = comments.get(comment.id)
      helpers.assert_eq(result, nil)
    end)

    it("removes comment from list", function()
      comments.add("test.lua", 10, "Comment 1")
      local to_delete = comments.add("test.lua", 20, "Comment 2")
      comments.add("test.lua", 30, "Comment 3")

      comments.delete(to_delete.id)

      local all = comments.get_all()
      helpers.assert_eq(#all, 2)
    end)

    it("returns false for non-existent comment", function()
      local success = comments.delete(999)
      helpers.assert_falsy(success)
    end)

    it("returns false when no comments exist", function()
      local success = comments.delete(1)
      helpers.assert_falsy(success)
    end)
  end)

  describe("delete_for_file", function()
    it("deletes all comments for a file", function()
      comments.add("file1.lua", 10, "Comment 1")
      comments.add("file1.lua", 20, "Comment 2")
      comments.add("file2.lua", 30, "Comment 3")

      local count = comments.delete_for_file("file1.lua")

      helpers.assert_eq(count, 2)

      local remaining = comments.get_all()
      helpers.assert_eq(#remaining, 1)
      helpers.assert_eq(remaining[1].file, "file2.lua")
    end)

    it("returns 0 when file has no comments", function()
      comments.add("file1.lua", 10, "Comment")

      local count = comments.delete_for_file("file2.lua")

      helpers.assert_eq(count, 0)
    end)

    it("returns 0 when no comments exist", function()
      local count = comments.delete_for_file("any.lua")
      helpers.assert_eq(count, 0)
    end)
  end)

  describe("get_all", function()
    it("returns all comments", function()
      comments.add("file1.lua", 10, "Comment 1")
      comments.add("file2.lua", 20, "Comment 2")
      comments.add("file3.lua", 30, "Comment 3")

      local all = comments.get_all()

      helpers.assert_eq(#all, 3)
    end)

    it("returns empty array when no comments", function()
      local all = comments.get_all()
      helpers.assert_table_eq(all, {})
    end)
  end)

  describe("clear", function()
    it("removes all comments", function()
      comments.add("file1.lua", 10, "Comment 1")
      comments.add("file2.lua", 20, "Comment 2")

      comments.clear()

      local all = comments.get_all()
      helpers.assert_table_eq(all, {})
    end)

    it("resets next_id", function()
      comments.add("test.lua", 10, "Comment")
      helpers.assert_eq(comments.next_id, 2)

      comments.clear()

      helpers.assert_eq(comments.next_id, 1)
    end)

    it("allows adding comments after clear", function()
      comments.add("test.lua", 10, "First")
      comments.clear()

      local new_comment = comments.add("test.lua", 20, "After clear")

      helpers.assert_eq(new_comment.id, 1)
      helpers.assert_eq(#comments.get_all(), 1)
    end)
  end)

  describe("stats", function()
    it("returns total count", function()
      comments.add("file1.lua", 10, "Comment 1")
      comments.add("file2.lua", 20, "Comment 2")

      local stats = comments.stats()

      helpers.assert_eq(stats.total, 2)
    end)

    it("counts comments by file", function()
      comments.add("file1.lua", 10, "Comment 1")
      comments.add("file1.lua", 20, "Comment 2")
      comments.add("file2.lua", 30, "Comment 3")

      local stats = comments.stats()

      helpers.assert_eq(stats.by_file["file1.lua"], 2)
      helpers.assert_eq(stats.by_file["file2.lua"], 1)
    end)

    it("counts comments by type", function()
      comments.add("test.lua", 10, "Single 1")
      comments.add("test.lua", 20, "Single 2")
      comments.add("test.lua", 30, "Range 1", { start = 30, ["end"] = 35 })

      local stats = comments.stats()

      helpers.assert_eq(stats.by_type.single, 2)
      helpers.assert_eq(stats.by_type.range, 1)
    end)

    it("returns zeros when no comments", function()
      local stats = comments.stats()

      helpers.assert_eq(stats.total, 0)
      helpers.assert_table_eq(stats.by_file, {})
      helpers.assert_eq(stats.by_type.single, 0)
      helpers.assert_eq(stats.by_type.range, 0)
    end)
  end)

  describe("set_auto_save_hook", function()
    it("calls hook on add", function()
      local called = false
      comments.set_auto_save_hook(function()
        called = true
      end)

      comments.add("test.lua", 10, "Comment")

      helpers.assert_truthy(called)
    end)

    it("calls hook on update", function()
      local comment = comments.add("test.lua", 10, "Original")

      local called = false
      comments.set_auto_save_hook(function()
        called = true
      end)

      comments.update(comment.id, "Updated")

      helpers.assert_truthy(called)
    end)

    it("calls hook on delete", function()
      local comment = comments.add("test.lua", 10, "To delete")

      local called = false
      comments.set_auto_save_hook(function()
        called = true
      end)

      comments.delete(comment.id)

      helpers.assert_truthy(called)
    end)

    it("does not call hook when no hook set", function()
      -- Should not error when hook is nil
      comments.add("test.lua", 10, "Comment")
      comments.update(1, "Updated")
      comments.delete(1)
    end)
  end)
end)
