local notes = require("diff-review.notes")

describe("notes", function()
  before_each(function()
    -- Clear notes before each test
    notes.clear()
  end)

  describe("add", function()
    it("should add a single line note", function()
      local note = notes.add("test.lua", 10, "Test comment")
      assert.is_not_nil(note)
      assert.equals("test.lua", note.file)
      assert.equals(10, note.line)
      assert.equals("Test comment", note.text)
      assert.equals("single", note.type)
      assert.equals("default", note.set_name)
    end)

    it("should add a range note", function()
      local note = notes.add("test.lua", 10, "Range comment", { start = 10, ["end"] = 15 })
      assert.is_not_nil(note)
      assert.equals("test.lua", note.file)
      assert.equals(10, note.line)
      assert.equals("Range comment", note.text)
      assert.equals("range", note.type)
      assert.is_not_nil(note.line_range)
      assert.equals(10, note.line_range.start)
      assert.equals(15, note.line_range["end"])
    end)

    it("should add note with custom set name", function()
      local note = notes.add("test.lua", 10, "Test comment", nil, "custom-set")
      assert.equals("custom-set", note.set_name)
    end)

    it("should generate unique IDs", function()
      local note1 = notes.add("test.lua", 10, "Comment 1")
      local note2 = notes.add("test.lua", 20, "Comment 2")
      assert.is_not_equal(note1.id, note2.id)
    end)

    it("should set timestamps", function()
      local note = notes.add("test.lua", 10, "Test comment")
      assert.is_not_nil(note.created_at)
      assert.is_not_nil(note.updated_at)
      assert.equals(note.created_at, note.updated_at)
    end)
  end)

  describe("get", function()
    it("should retrieve note by ID", function()
      local note = notes.add("test.lua", 10, "Test comment")
      local retrieved = notes.get(note.id)
      assert.equals(note.id, retrieved.id)
      assert.equals(note.text, retrieved.text)
    end)

    it("should return nil for non-existent ID", function()
      local retrieved = notes.get(9999)
      assert.is_nil(retrieved)
    end)
  end)

  describe("get_for_file", function()
    it("should return all notes for a file", function()
      notes.add("test.lua", 10, "Comment 1")
      notes.add("test.lua", 20, "Comment 2")
      notes.add("other.lua", 30, "Comment 3")

      local file_notes = notes.get_for_file("test.lua")
      assert.equals(2, #file_notes)
    end)

    it("should return empty table for file with no notes", function()
      local file_notes = notes.get_for_file("nonexistent.lua")
      assert.equals(0, #file_notes)
    end)
  end)

  describe("get_for_file_in_set", function()
    it("should return notes for file in specific set", function()
      notes.add("test.lua", 10, "Comment 1", nil, "set1")
      notes.add("test.lua", 20, "Comment 2", nil, "set2")
      notes.add("test.lua", 30, "Comment 3", nil, "set1")

      local file_notes = notes.get_for_file_in_set("test.lua", "set1")
      assert.equals(2, #file_notes)
    end)
  end)

  describe("get_at_line", function()
    it("should return notes at specific line", function()
      notes.add("test.lua", 10, "Comment at line 10")
      notes.add("test.lua", 20, "Comment at line 20")

      local line_notes = notes.get_at_line("test.lua", 10)
      assert.equals(1, #line_notes)
      assert.equals("Comment at line 10", line_notes[1].text)
    end)

    it("should include range notes", function()
      notes.add("test.lua", 10, "Range", { start = 10, ["end"] = 15 })

      local line_notes = notes.get_at_line("test.lua", 12)
      assert.equals(1, #line_notes)
    end)
  end)

  describe("update", function()
    it("should update note text", function()
      local note = notes.add("test.lua", 10, "Original text")
      local original_time = note.updated_at

      -- Wait a moment to ensure timestamp changes
      vim.wait(10, function() return false end)

      notes.update(note.id, "Updated text")
      local updated = notes.get(note.id)

      assert.equals("Updated text", updated.text)
      assert.is_true(updated.updated_at >= original_time)
    end)

    it("should return false for non-existent note", function()
      local result = notes.update(9999, "New text")
      assert.is_false(result)
    end)
  end)

  describe("delete", function()
    it("should delete note by ID", function()
      local note = notes.add("test.lua", 10, "Test comment")
      local result = notes.delete(note.id)

      assert.is_true(result)
      assert.is_nil(notes.get(note.id))
    end)

    it("should return false for non-existent note", function()
      local result = notes.delete(9999)
      assert.is_false(result)
    end)
  end)

  describe("get_for_set", function()
    it("should return all notes in a set", function()
      notes.add("test.lua", 10, "Comment 1", nil, "set1")
      notes.add("test.lua", 20, "Comment 2", nil, "set1")
      notes.add("test.lua", 30, "Comment 3", nil, "set2")

      local set_notes = notes.get_for_set("set1")
      assert.equals(2, #set_notes)
    end)
  end)

  describe("clear_set", function()
    it("should clear all notes in a set", function()
      notes.add("test.lua", 10, "Comment 1", nil, "set1")
      notes.add("test.lua", 20, "Comment 2", nil, "set1")
      notes.add("test.lua", 30, "Comment 3", nil, "set2")

      local count = notes.clear_set("set1")
      assert.equals(2, count)

      local remaining = notes.get_all()
      assert.equals(1, #remaining)
      assert.equals("set2", remaining[1].set_name)
    end)
  end)

  describe("load_set", function()
    it("should load notes for a set", function()
      local note_data = {
        { id = 1, file = "test.lua", line = 10, text = "Comment 1", type = "single", set_name = "set1", created_at = 123, updated_at = 123 },
        { id = 2, file = "test.lua", line = 20, text = "Comment 2", type = "single", set_name = "set1", created_at = 124, updated_at = 124 },
      }

      notes.load_set("set1", note_data)

      local loaded = notes.get_for_set("set1")
      assert.equals(2, #loaded)
    end)

    it("should update next_id to prevent collisions", function()
      local note_data = {
        { id = 100, file = "test.lua", line = 10, text = "Comment", type = "single", set_name = "set1", created_at = 123, updated_at = 123 },
      }

      notes.load_set("set1", note_data)
      local new_note = notes.add("test.lua", 20, "New comment")

      assert.is_true(new_note.id > 100)
    end)
  end)

  describe("stats", function()
    it("should calculate statistics", function()
      notes.add("test.lua", 10, "Comment 1")
      notes.add("test.lua", 20, "Comment 2", { start = 20, ["end"] = 25 })
      notes.add("other.lua", 30, "Comment 3")

      local stats = notes.stats()
      assert.equals(3, stats.total)
      assert.equals(2, stats.by_file["test.lua"])
      assert.equals(1, stats.by_file["other.lua"])
      assert.equals(2, stats.by_type.single)
      assert.equals(1, stats.by_type.range)
      assert.equals(3, stats.by_set.default)
    end)
  end)
end)
