local note_export = require("diff-review.note_export")
local notes = require("diff-review.notes")
local note_mode = require("diff-review.note_mode")

describe("note_export", function()
  local test_set = "test-export-" .. os.time()

  before_each(function()
    -- Initialize config for tests that enter note mode
    local config = require("diff-review.config")
    config.setup({})

    notes.clear()
    if note_mode.get_state().is_active then
      note_mode.exit()
    end
  end)

  after_each(function()
    notes.clear()
    if note_mode.get_state().is_active then
      note_mode.exit()
    end
  end)

  describe("export_notes", function()
    it("should export notes in markdown format", function()
      -- Add some notes
      notes.add("test.lua", 10, "First comment", nil, test_set)
      notes.add("test.lua", 20, "Second comment", nil, test_set)
      notes.add("other.lua", 5, "Third comment", nil, test_set)

      -- Export
      local content, err = note_export.export_notes(test_set)
      assert.is_nil(err)
      assert.is_not_nil(content)

      -- Verify content structure (use find() to avoid pattern escaping issues)
      assert.is_not_nil(content:find("## Notes", 1, true))
      assert.is_not_nil(content:find(test_set, 1, true))
      assert.is_not_nil(content:find("### test.lua", 1, true))
      assert.is_not_nil(content:find("### other.lua", 1, true))
      assert.is_not_nil(content:find("Line 10: First comment", 1, true))
      assert.is_not_nil(content:find("Line 20: Second comment", 1, true))
      assert.is_not_nil(content:find("Line 5: Third comment", 1, true))
      assert.is_not_nil(content:find("3 note", 1, true))
      assert.is_not_nil(content:find("2 file", 1, true))
    end)

    it("should handle range notes", function()
      notes.add("test.lua", 10, "Range comment", { start = 10, ["end"] = 15 }, test_set)

      local content, err = note_export.export_notes(test_set)
      assert.is_nil(err)
      assert.is_not_nil(content:find("Lines 10-15: Range comment", 1, true))
    end)

    it("should sort files alphabetically", function()
      notes.add("zebra.lua", 1, "Last", nil, test_set)
      notes.add("alpha.lua", 1, "First", nil, test_set)
      notes.add("beta.lua", 1, "Middle", nil, test_set)

      local content, err = note_export.export_notes(test_set)
      assert.is_nil(err)

      -- Check order by finding positions
      local alpha_pos = content:find("### alpha.lua")
      local beta_pos = content:find("### beta.lua")
      local zebra_pos = content:find("### zebra.lua")

      assert.is_true(alpha_pos < beta_pos)
      assert.is_true(beta_pos < zebra_pos)
    end)

    it("should sort notes by line number within file", function()
      notes.add("test.lua", 30, "Third", nil, test_set)
      notes.add("test.lua", 10, "First", nil, test_set)
      notes.add("test.lua", 20, "Second", nil, test_set)

      local content, err = note_export.export_notes(test_set)
      assert.is_nil(err)

      local first_pos = content:find("Line 10: First")
      local second_pos = content:find("Line 20: Second")
      local third_pos = content:find("Line 30: Third")

      assert.is_true(first_pos < second_pos)
      assert.is_true(second_pos < third_pos)
    end)

    it("should return error when no notes exist", function()
      local content, err = note_export.export_notes(test_set)
      assert.is_nil(content)
      assert.equals("No notes to export", err)
    end)

    it("should use current set when active and no set specified", function()
      note_mode.enter(test_set)
      notes.add("test.lua", 10, "Comment", nil, test_set)

      local content, err = note_export.export_notes()
      assert.is_nil(err)
      assert.is_not_nil(content)
      assert.is_not_nil(content:find(test_set, 1, true))
    end)

    it("should return error when not active and no set specified", function()
      local content, err = note_export.export_notes()
      assert.is_nil(content)
      assert.equals("Note mode not active and no set specified", err)
    end)
  end)

  describe("export_notes_with_context", function()
    it("should export notes with context markers", function()
      notes.add("test.lua", 10, "Comment", nil, test_set)

      local content, err = note_export.export_notes_with_context(test_set)
      assert.is_nil(err)
      assert.is_not_nil(content)

      -- Should have markdown structure
      assert.is_not_nil(content:find("## Notes", 1, true))
      assert.is_not_nil(content:find("**Line 10:**", 1, true))
      assert.is_not_nil(content:find("> Comment", 1, true))
    end)

    it("should handle range notes with context", function()
      notes.add("test.lua", 10, "Range", { start = 10, ["end"] = 15 }, test_set)

      local content, err = note_export.export_notes_with_context(test_set)
      assert.is_nil(err)
      assert.is_not_nil(content:find("**Lines 10-15:**", 1, true))
    end)
  end)
end)
