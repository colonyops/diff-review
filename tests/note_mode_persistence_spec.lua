local note_mode = require("diff-review.note_mode")
local notes = require("diff-review.notes")
local note_persistence = require("diff-review.note_persistence")
local config = require("diff-review.config")

describe("note_mode persistence", function()
  local test_set = "test-persist-" .. os.time()

  before_each(function()
    config.setup({})
    notes.clear()
    note_persistence.delete_set(test_set)
    note_persistence.clear_global_session()

    -- Reset note mode state
    if note_mode.get_state().is_active then
      note_mode.exit()
    end
  end)

  after_each(function()
    if note_mode.get_state().is_active then
      note_mode.exit()
    end
    note_persistence.delete_set(test_set)
    note_persistence.clear_global_session()
  end)

  describe("session save on exit", function()
    it("should save notes when exiting note mode", function()
      -- Enter note mode
      note_mode.enter(test_set)

      -- Add a note
      notes.add("test.lua", 10, "Test comment", nil, test_set)

      -- Exit note mode (should save notes)
      note_mode.exit()

      -- Verify notes were saved to disk
      local loaded = note_persistence.load(test_set)
      assert.is_not_nil(loaded)
      assert.equals(1, #loaded)
      assert.equals("Test comment", loaded[1].text)
    end)

    it("should save notes and session state when Vim closes", function()
      -- Enter note mode
      note_mode.enter(test_set)

      -- Add notes
      notes.add("test.lua", 10, "Comment 1", nil, test_set)
      notes.add("test.lua", 20, "Comment 2", nil, test_set)

      -- Simulate VimLeavePre by calling the save_session internals
      -- We'll manually call the save logic
      local set_notes = notes.get_for_set(test_set)
      note_persistence.save(set_notes, test_set)
      note_persistence.save_global_session({
        is_active = true,
        current_set = test_set,
        visible = true,
      })

      -- Verify notes were saved
      local loaded_notes = note_persistence.load(test_set)
      assert.equals(2, #loaded_notes)

      -- Verify session state was saved
      local session = note_persistence.load_global_session()
      assert.is_not_nil(session)
      assert.is_true(session.is_active)
      assert.equals(test_set, session.current_set)
    end)
  end)

  describe("session restore", function()
    it("should restore notes when re-entering mode", function()
      -- Create and save notes
      notes.clear()
      notes.add("test.lua", 10, "Saved comment", nil, test_set)
      local set_notes = notes.get_for_set(test_set)
      note_persistence.save(set_notes, test_set)

      -- Clear in-memory notes
      notes.clear()

      -- Enter note mode (should load notes)
      note_mode.enter(test_set)

      -- Verify notes were loaded
      local loaded = notes.get_for_set(test_set)
      assert.equals(1, #loaded)
      assert.equals("Saved comment", loaded[1].text)

      note_mode.exit()
    end)

    it("should auto-restore session on startup when enabled", function()
      -- Setup config with auto_restore
      config.setup({
        notes = {
          auto_restore = true,
        },
      })

      -- Create a saved session
      note_persistence.save_global_session({
        is_active = true,
        current_set = test_set,
        visible = true,
      })

      -- Create saved notes
      notes.clear()
      notes.add("test.lua", 10, "Persistent comment", nil, test_set)
      local set_notes = notes.get_for_set(test_set)
      note_persistence.save(set_notes, test_set)

      -- Clear in-memory state
      notes.clear()

      -- Simulate startup by calling restore_session
      note_mode.restore_session()

      -- Verify mode was restored
      local state = note_mode.get_state()
      assert.is_true(state.is_active)
      assert.equals(test_set, state.current_set)

      -- Verify notes were loaded
      local loaded = notes.get_for_set(test_set)
      assert.equals(1, #loaded)
      assert.equals("Persistent comment", loaded[1].text)

      note_mode.exit()
    end)

    it("should not auto-restore when disabled", function()
      -- Setup config with auto_restore disabled
      config.setup({
        notes = {
          auto_restore = false,
        },
      })

      -- Create a saved session
      note_persistence.save_global_session({
        is_active = true,
        current_set = test_set,
        visible = true,
      })

      -- Simulate startup
      note_mode.restore_session()

      -- Verify mode was NOT restored
      local state = note_mode.get_state()
      assert.is_false(state.is_active)
    end)
  end)

  describe("multiple sessions", function()
    it("should preserve notes across enter/exit cycles", function()
      -- First session
      note_mode.enter(test_set)
      notes.add("test.lua", 10, "First comment", nil, test_set)
      note_mode.exit()

      -- Second session
      note_mode.enter(test_set)
      notes.add("test.lua", 20, "Second comment", nil, test_set)
      note_mode.exit()

      -- Verify both comments persist
      local loaded = note_persistence.load(test_set)
      assert.equals(2, #loaded)
    end)
  end)
end)
