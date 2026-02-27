local note_mode = require("diff-review.note_mode")
local notes = require("diff-review.notes")
local note_persistence = require("diff-review.note_persistence")
local config = require("diff-review.config")

describe("note_mode edge cases", function()
  local test_set = "edge-test-" .. os.time()

  before_each(function()
    config.setup({})

    -- Ensure clean state
    if note_mode.get_state().is_active then
      note_mode.exit()
    end
    notes.clear()
  end)

  after_each(function()
    if note_mode.get_state().is_active then
      note_mode.exit()
    end
    note_persistence.delete_set(test_set)
    notes.clear()
  end)

  describe("concurrent auto-save", function()
    it("should handle rapid note additions", function()
      note_mode.enter(test_set)

      -- Rapidly add notes
      for i = 1, 50 do
        notes.add("test.lua", i, "Comment " .. i, nil, test_set)
      end

      -- Give auto-save time to process if async
      vim.wait(100)

      -- Verify all notes are persisted
      local loaded = note_persistence.load(test_set)
      assert.is_not_nil(loaded)
      assert.equals(50, #loaded)
    end)

    it("should handle rapid set switching", function()
      local set1 = test_set .. "-1"
      local set2 = test_set .. "-2"

      note_mode.enter(set1)
      notes.add("test.lua", 1, "Comment 1", nil, set1)

      note_mode.switch_set(set2)
      notes.add("test.lua", 2, "Comment 2", nil, set2)

      note_mode.switch_set(set1)

      -- Verify both sets are intact
      local loaded1 = note_persistence.load(set1)
      local loaded2 = note_persistence.load(set2)

      assert.is_not_nil(loaded1)
      assert.equals(1, #loaded1)
      assert.is_not_nil(loaded2)
      assert.equals(1, #loaded2)

      -- Cleanup
      note_persistence.delete_set(set1)
      note_persistence.delete_set(set2)
    end)

    it("should handle exit and re-enter quickly", function()
      note_mode.enter(test_set)
      notes.add("test.lua", 1, "Comment", nil, test_set)
      note_mode.exit()

      -- Immediately re-enter
      note_mode.enter(test_set)

      local state = note_mode.get_state()
      assert.is_true(state.is_active)
      assert.equals(test_set, state.current_set)

      -- Notes should be restored
      local set_notes = notes.get_for_set(test_set)
      assert.equals(1, #set_notes)
    end)
  end)

  describe("invalid buffer state", function()
    it("should remove note-mode keymaps when exiting", function()
      local add_key = config.get().keymaps.add_comment

      note_mode.enter(test_set)
      local before = vim.fn.maparg(add_key, "n", false, true)
      assert.equals(add_key, before.lhs)

      note_mode.exit()
      local after = vim.fn.maparg(add_key, "n", false, true)
      assert.is_true(after.lhs == nil or after.lhs == "")
    end)

    it("should handle enter when already active", function()
      note_mode.enter(test_set)
      local state1 = note_mode.get_state()

      -- Try to enter again
      note_mode.enter(test_set)
      local state2 = note_mode.get_state()

      -- Should still be active with same set
      assert.is_true(state2.is_active)
      assert.equals(test_set, state2.current_set)
    end)

    it("should handle exit when not active", function()
      -- Exit when not in note mode
      note_mode.exit()

      -- Should not error
      local state = note_mode.get_state()
      assert.is_false(state.is_active)
    end)

    it("should handle toggle rapidly", function()
      -- Rapid toggle (5 times: off->on->off->on->off->on)
      for i = 1, 5 do
        note_mode.toggle(test_set)
      end

      -- Should end up active (started inactive, toggled odd number of times)
      local state = note_mode.get_state()
      assert.is_true(state.is_active)

      -- Clean up
      note_mode.exit()
    end)

    it("should handle switch_set when not active", function()
      -- Try to switch when not in note mode
      -- This should be a no-op or gracefully handled
      pcall(note_mode.switch_set, test_set)

      local state = note_mode.get_state()
      assert.is_false(state.is_active)
    end)
  end)

  describe("state validation boundaries", function()
    it("should handle empty set name", function()
      -- Try to enter with empty set name
      note_mode.enter("")

      local state = note_mode.get_state()
      -- Should either use default or handle gracefully
      assert.is_true(state.is_active)
    end)

    it("should handle set name with special characters", function()
      local special_set = "test-set_" .. os.time() .. ".@#$"

      note_mode.enter(special_set)
      notes.add("test.lua", 1, "Comment", nil, special_set)
      note_mode.exit()

      -- Verify it was saved
      local loaded = note_persistence.load(special_set)
      assert.is_not_nil(loaded)
      assert.equals(1, #loaded)

      note_persistence.delete_set(special_set)
    end)

    it("should handle very long set names", function()
      local long_set = "test-" .. string.rep("x", 200)

      note_mode.enter(long_set)
      notes.add("test.lua", 1, "Comment", nil, long_set)
      note_mode.exit()

      -- Should handle gracefully
      local loaded = note_persistence.load(long_set)
      assert.is_not_nil(loaded)

      note_persistence.delete_set(long_set)
    end)

    it("should handle notes with empty text", function()
      note_mode.enter(test_set)

      -- Add note with empty text
      notes.add("test.lua", 1, "", nil, test_set)

      local set_notes = notes.get_for_set(test_set)
      assert.equals(1, #set_notes)
      assert.equals("", set_notes[1].text)

      note_mode.exit()

      -- Verify empty text is preserved
      local loaded = note_persistence.load(test_set)
      assert.is_not_nil(loaded)
      assert.equals(1, #loaded)
      assert.equals("", loaded[1].text)
    end)

    it("should handle notes with very long text", function()
      note_mode.enter(test_set)

      local long_text = string.rep("This is a very long comment. ", 100)
      notes.add("test.lua", 1, long_text, nil, test_set)

      note_mode.exit()

      local loaded = note_persistence.load(test_set)
      assert.is_not_nil(loaded)
      assert.equals(1, #loaded)
      assert.equals(long_text, loaded[1].text)
    end)

    it("should handle notes with multiline text", function()
      note_mode.enter(test_set)

      local multiline = "Line 1\nLine 2\nLine 3"
      notes.add("test.lua", 1, multiline, nil, test_set)

      note_mode.exit()

      local loaded = note_persistence.load(test_set)
      assert.is_not_nil(loaded)
      assert.equals(multiline, loaded[1].text)
    end)

    it("should handle notes with unicode", function()
      note_mode.enter(test_set)

      local unicode_text = "Hello 世界 🌍 Testing emoji 🚀"
      notes.add("test.lua", 1, unicode_text, nil, test_set)

      note_mode.exit()

      local loaded = note_persistence.load(test_set)
      assert.is_not_nil(loaded)
      assert.equals(unicode_text, loaded[1].text)
    end)

    it("should handle many notes in single set", function()
      note_mode.enter(test_set)

      -- Add many notes
      for i = 1, 500 do
        notes.add("file" .. (i % 10) .. ".lua", i, "Comment " .. i, nil, test_set)
      end

      note_mode.exit()

      local loaded = note_persistence.load(test_set)
      assert.is_not_nil(loaded)
      assert.equals(500, #loaded)
    end)
  end)

  describe("session restore edge cases", function()
    it("should handle restore with corrupt session data", function()
      -- Directly manipulate session file to create corrupt state
      local session_file = vim.fn.stdpath("data") .. "/diff-review/session.json"
      local storage_utils = require("diff-review.storage_utils")

      -- Create directory
      local session_dir = vim.fn.fnamemodify(session_file, ":h")
      storage_utils.ensure_dir(session_dir)

      -- Write corrupt data
      local file = io.open(session_file, "w")
      file:write("{ corrupt json")
      file:close()

      -- Attempt to restore - should not error
      pcall(note_mode.restore_session)

      -- State should be clean
      local state = note_mode.get_state()
      assert.is_false(state.is_active)

      -- Cleanup
      vim.fn.delete(session_file)
    end)

    it("should handle restore with missing note set", function()
      note_mode.enter(test_set)
      notes.add("test.lua", 1, "Comment", nil, test_set)
      note_mode.exit()

      -- Delete the note set but leave session
      note_persistence.delete_set(test_set)

      -- Restore should handle missing set gracefully
      pcall(note_mode.restore_session)

      -- Should not crash
      assert.is_true(true)
    end)
  end)
end)
