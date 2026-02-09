local note_persistence = require("diff-review.note_persistence")
local notes = require("diff-review.notes")

describe("note_persistence", function()
  local test_set = "test-set-" .. os.time()

  after_each(function()
    -- Clean up test files
    note_persistence.delete_set(test_set)
  end)

  describe("save and load", function()
    it("should save and load notes", function()
      -- Add some notes
      notes.clear()
      notes.add("test.lua", 10, "Comment 1", nil, test_set)
      notes.add("test.lua", 20, "Comment 2", nil, test_set)

      local set_notes = notes.get_for_set(test_set)

      -- Save
      local success = note_persistence.save(set_notes, test_set)
      assert.is_true(success)

      -- Clear in-memory notes
      notes.clear()

      -- Load
      local loaded = note_persistence.load(test_set)
      assert.is_not_nil(loaded)
      assert.equals(2, #loaded)
      assert.equals("Comment 1", loaded[1].text)
      assert.equals("Comment 2", loaded[2].text)
    end)

    it("should return nil for non-existent set", function()
      local loaded = note_persistence.load("nonexistent-set-12345")
      assert.is_nil(loaded)
    end)
  end)

  describe("list_sets", function()
    it("should list all note sets", function()
      -- Create multiple sets
      notes.clear()
      notes.add("test.lua", 10, "Comment 1", nil, test_set)
      note_persistence.save(notes.get_for_set(test_set), test_set)

      local sets = note_persistence.list_sets()
      local found = false
      for _, set in ipairs(sets) do
        if set == test_set then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("should return empty table when no sets exist", function()
      -- Clean up any existing sets
      local sets = note_persistence.list_sets()
      for _, set in ipairs(sets) do
        note_persistence.delete_set(set)
      end

      sets = note_persistence.list_sets()
      assert.equals(0, #sets)
    end)
  end)

  describe("delete_set", function()
    it("should delete a note set", function()
      -- Create a set
      notes.clear()
      notes.add("test.lua", 10, "Comment", nil, test_set)
      note_persistence.save(notes.get_for_set(test_set), test_set)

      -- Verify it exists
      local loaded = note_persistence.load(test_set)
      assert.is_not_nil(loaded)

      -- Delete it
      local success = note_persistence.delete_set(test_set)
      assert.is_true(success)

      -- Verify it's gone
      loaded = note_persistence.load(test_set)
      assert.is_nil(loaded)
    end)

    it("should return false for non-existent set", function()
      local success = note_persistence.delete_set("nonexistent-12345")
      assert.is_false(success)
    end)
  end)

  describe("auto_save and auto_load", function()
    it("should auto-save notes", function()
      notes.clear()
      notes.add("test.lua", 10, "Comment", nil, test_set)

      local set_notes = notes.get_for_set(test_set)
      note_persistence.auto_save(set_notes, test_set)

      -- Load directly
      local loaded = note_persistence.load(test_set)
      assert.is_not_nil(loaded)
      assert.equals(1, #loaded)
    end)

    it("should delete set when auto-saving empty notes", function()
      -- Create and save a set
      notes.clear()
      notes.add("test.lua", 10, "Comment", nil, test_set)
      note_persistence.save(notes.get_for_set(test_set), test_set)

      -- Auto-save empty notes
      note_persistence.auto_save({}, test_set)

      -- Should be deleted
      local loaded = note_persistence.load(test_set)
      assert.is_nil(loaded)
    end)

    it("should return empty table when auto-loading non-existent set", function()
      local loaded = note_persistence.auto_load("nonexistent-12345")
      assert.equals(0, #loaded)
    end)
  end)
end)
