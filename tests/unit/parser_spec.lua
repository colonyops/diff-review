-- Unit tests for parser.lua
local helpers = require("tests.helpers")

describe("parser.parse_args", function()
  local parser

  before_each(function()
    parser = require("diff-review.parser")
  end)

  describe("uncommitted type", function()
    it("parses empty string as uncommitted", function()
      local result = parser.parse_args("")
      helpers.assert_eq(result.type, "uncommitted")
      helpers.assert_eq(result.base, nil)
      helpers.assert_eq(result.head, nil)
      helpers.assert_eq(result.pr_number, nil)
    end)

    it("parses nil as uncommitted", function()
      local result = parser.parse_args(nil)
      helpers.assert_eq(result.type, "uncommitted")
      helpers.assert_eq(result.base, nil)
      helpers.assert_eq(result.head, nil)
      helpers.assert_eq(result.pr_number, nil)
    end)

    it("parses whitespace-only as uncommitted", function()
      local result = parser.parse_args("   ")
      helpers.assert_eq(result.type, "uncommitted")
    end)
  end)

  describe("pr type", function()
    it("parses ghpr:N syntax", function()
      local result = parser.parse_args("ghpr:334")
      helpers.assert_eq(result.type, "pr")
      helpers.assert_eq(result.pr_number, 334)
      helpers.assert_eq(result.base, nil)
      helpers.assert_eq(result.head, nil)
    end)

    it("parses pr:N syntax", function()
      local result = parser.parse_args("pr:42")
      helpers.assert_eq(result.type, "pr")
      helpers.assert_eq(result.pr_number, 42)
      helpers.assert_eq(result.base, nil)
      helpers.assert_eq(result.head, nil)
    end)

    it("handles large PR numbers", function()
      local result = parser.parse_args("ghpr:99999")
      helpers.assert_eq(result.type, "pr")
      helpers.assert_eq(result.pr_number, 99999)
    end)

    it("handles single-digit PR numbers", function()
      local result = parser.parse_args("pr:1")
      helpers.assert_eq(result.type, "pr")
      helpers.assert_eq(result.pr_number, 1)
    end)

    it("trims whitespace around PR syntax", function()
      local result = parser.parse_args("  ghpr:334  ")
      helpers.assert_eq(result.type, "pr")
      helpers.assert_eq(result.pr_number, 334)
    end)

    it("rejects invalid PR syntax with letters", function()
      local result = parser.parse_args("ghpr:abc")
      helpers.assert_eq(result.type, "ref")
      helpers.assert_eq(result.base, "ghpr:abc")
    end)

    it("rejects PR with missing number", function()
      local result = parser.parse_args("ghpr:")
      helpers.assert_eq(result.type, "ref")
      helpers.assert_eq(result.base, "ghpr:")
    end)
  end)

  describe("range type", function()
    it("parses two-dot range syntax", function()
      local result = parser.parse_args("main..feature")
      helpers.assert_eq(result.type, "range")
      helpers.assert_eq(result.base, "main")
      helpers.assert_eq(result.head, "feature")
      helpers.assert_eq(result.pr_number, nil)
    end)

    it("parses three-dot range syntax", function()
      local result = parser.parse_args("main...feature")
      helpers.assert_eq(result.type, "range")
      helpers.assert_eq(result.base, "main")
      helpers.assert_eq(result.head, "feature")
    end)

    it("handles commit hash ranges", function()
      local result = parser.parse_args("abc123..def456")
      helpers.assert_eq(result.type, "range")
      helpers.assert_eq(result.base, "abc123")
      helpers.assert_eq(result.head, "def456")
    end)

    it("handles HEAD in range", function()
      local result = parser.parse_args("main..HEAD")
      helpers.assert_eq(result.type, "range")
      helpers.assert_eq(result.base, "main")
      helpers.assert_eq(result.head, "HEAD")
    end)

    it("handles origin/ prefix in range", function()
      local result = parser.parse_args("origin/main..origin/feature")
      helpers.assert_eq(result.type, "range")
      helpers.assert_eq(result.base, "origin/main")
      helpers.assert_eq(result.head, "origin/feature")
    end)

    it("trims whitespace around range", function()
      local result = parser.parse_args("  main..feature  ")
      helpers.assert_eq(result.type, "range")
      helpers.assert_eq(result.base, "main")
      helpers.assert_eq(result.head, "feature")
    end)

    it("handles branch names with slashes", function()
      local result = parser.parse_args("feature/auth..feature/login")
      helpers.assert_eq(result.type, "range")
      helpers.assert_eq(result.base, "feature/auth")
      helpers.assert_eq(result.head, "feature/login")
    end)
  end)

  describe("ref type", function()
    it("parses single branch name as ref", function()
      local result = parser.parse_args("main")
      helpers.assert_eq(result.type, "ref")
      helpers.assert_eq(result.base, "main")
      helpers.assert_eq(result.head, "HEAD")
      helpers.assert_eq(result.pr_number, nil)
    end)

    it("parses commit hash as ref", function()
      local result = parser.parse_args("abc123")
      helpers.assert_eq(result.type, "ref")
      helpers.assert_eq(result.base, "abc123")
      helpers.assert_eq(result.head, "HEAD")
    end)

    it("parses HEAD as ref", function()
      local result = parser.parse_args("HEAD~1")
      helpers.assert_eq(result.type, "ref")
      helpers.assert_eq(result.base, "HEAD~1")
      helpers.assert_eq(result.head, "HEAD")
    end)

    it("handles origin/ prefix", function()
      local result = parser.parse_args("origin/main")
      helpers.assert_eq(result.type, "ref")
      helpers.assert_eq(result.base, "origin/main")
      helpers.assert_eq(result.head, "HEAD")
    end)

    it("handles branch names with slashes", function()
      local result = parser.parse_args("feature/auth-system")
      helpers.assert_eq(result.type, "ref")
      helpers.assert_eq(result.base, "feature/auth-system")
      helpers.assert_eq(result.head, "HEAD")
    end)

    it("trims whitespace around ref", function()
      local result = parser.parse_args("  main  ")
      helpers.assert_eq(result.type, "ref")
      helpers.assert_eq(result.base, "main")
    end)
  end)
end)

describe("parser.validate", function()
  local parser

  before_each(function()
    parser = require("diff-review.parser")
  end)

  describe("uncommitted validation", function()
    it("validates uncommitted type without git checks", function()
      local parsed = { type = "uncommitted", base = nil, head = nil, pr_number = nil }
      local valid, err = parser.validate(parsed)
      helpers.assert_truthy(valid)
      helpers.assert_eq(err, nil)
    end)
  end)

  describe("pr validation", function()
    it("validates pr with valid number", function()
      local parsed = { type = "pr", base = nil, head = nil, pr_number = 334 }
      local valid, err = parser.validate(parsed)
      helpers.assert_truthy(valid)
      helpers.assert_eq(err, nil)
    end)

    it("rejects pr without number", function()
      local parsed = { type = "pr", base = nil, head = nil, pr_number = nil }
      local valid, err = parser.validate(parsed)
      helpers.assert_falsy(valid)
      assert.is_not_nil(err:match("Invalid PR number"))
    end)
  end)

  describe("ref validation with git", function()
    it("validates existing ref", function()
      -- Mock git command to return success
      local restore = helpers.mock_git_command("abc123def456")
      local restore_escape = helpers.mock_shellescape()

      local parsed = { type = "ref", base = "main", head = "HEAD", pr_number = nil }
      local valid, err = parser.validate(parsed)

      restore()
      restore_escape()

      helpers.assert_truthy(valid)
      helpers.assert_eq(err, nil)
    end)

    it("rejects non-existent ref", function()
      local restore = helpers.mock_git_command("fatal: not a valid ref")
      local restore_escape = helpers.mock_shellescape()

      local parsed = { type = "ref", base = "nonexistent", head = "HEAD", pr_number = nil }
      local valid, err = parser.validate(parsed)

      restore()
      restore_escape()

      helpers.assert_falsy(valid)
      assert.is_not_nil(err:match("Unknown ref"))
    end)

    it("rejects ref without base", function()
      local parsed = { type = "ref", base = nil, head = "HEAD", pr_number = nil }
      local valid, err = parser.validate(parsed)
      helpers.assert_falsy(valid)
      assert.is_not_nil(err:match("Invalid ref"))
    end)
  end)

  describe("range validation with git", function()
    it("validates range with both refs existing", function()
      local call_count = 0
      local original_popen = io.popen
      local restore_escape = helpers.mock_shellescape()

      _G.io.popen = function(cmd)
        call_count = call_count + 1
        return {
          read = function() return "abc123" end,
          close = function() return true end,
        }
      end

      local parsed = { type = "range", base = "main", head = "feature", pr_number = nil }
      local valid, err = parser.validate(parsed)

      _G.io.popen = original_popen
      restore_escape()

      helpers.assert_truthy(valid)
      helpers.assert_eq(err, nil)
      helpers.assert_eq(call_count, 2) -- Both base and head checked
    end)

    it("rejects range with invalid base", function()
      local call_count = 0
      local original_popen = io.popen
      local restore_escape = helpers.mock_shellescape()

      _G.io.popen = function(cmd)
        call_count = call_count + 1
        return {
          read = function() return "fatal: not a valid ref" end,
          close = function() return false end,
        }
      end

      local parsed = { type = "range", base = "bad-base", head = "feature", pr_number = nil }
      local valid, err = parser.validate(parsed)

      _G.io.popen = original_popen
      restore_escape()

      helpers.assert_falsy(valid)
      assert.is_not_nil(err:match("Unknown base ref"))
    end)

    it("rejects range with invalid head", function()
      local call_count = 0
      local original_popen = io.popen
      local restore_escape = helpers.mock_shellescape()

      _G.io.popen = function(cmd)
        call_count = call_count + 1
        if call_count == 1 then
          -- Base is valid
          return {
            read = function() return "abc123" end,
            close = function() return true end,
          }
        else
          -- Head is invalid
          return {
            read = function() return "fatal: not a valid ref" end,
            close = function() return false end,
          }
        end
      end

      local parsed = { type = "range", base = "main", head = "bad-head", pr_number = nil }
      local valid, err = parser.validate(parsed)

      _G.io.popen = original_popen
      restore_escape()

      helpers.assert_falsy(valid)
      assert.is_not_nil(err:match("Unknown head ref"))
    end)

    it("rejects range without base", function()
      local parsed = { type = "range", base = nil, head = "feature", pr_number = nil }
      local valid, err = parser.validate(parsed)
      helpers.assert_falsy(valid)
      assert.is_not_nil(err:match("Invalid range syntax"))
    end)

    it("rejects range without head", function()
      local parsed = { type = "range", base = "main", head = nil, pr_number = nil }
      local valid, err = parser.validate(parsed)
      helpers.assert_falsy(valid)
      assert.is_not_nil(err:match("Invalid range syntax"))
    end)
  end)
end)

describe("parser.format", function()
  local parser

  before_each(function()
    parser = require("diff-review.parser")
  end)

  it("formats uncommitted type", function()
    local parsed = { type = "uncommitted" }
    local result = parser.format(parsed)
    helpers.assert_eq(result, "Uncommitted Changes")
  end)

  it("formats pr type", function()
    local parsed = { type = "pr", pr_number = 334 }
    local result = parser.format(parsed)
    helpers.assert_eq(result, "PR #334")
  end)

  it("formats ref type", function()
    local parsed = { type = "ref", base = "main" }
    local result = parser.format(parsed)
    helpers.assert_eq(result, "main..HEAD")
  end)

  it("formats range type", function()
    local parsed = { type = "range", base = "main", head = "feature" }
    local result = parser.format(parsed)
    helpers.assert_eq(result, "main..feature")
  end)

  it("handles unknown type", function()
    local parsed = { type = "unknown" }
    local result = parser.format(parsed)
    helpers.assert_eq(result, "Unknown")
  end)
end)

describe("parser.get_diff_args", function()
  local parser

  before_each(function()
    parser = require("diff-review.parser")
  end)

  it("returns empty args for uncommitted", function()
    local parsed = { type = "uncommitted" }
    local result = parser.get_diff_args(parsed)
    helpers.assert_table_eq(result, {})
  end)

  it("returns ref..HEAD for ref type", function()
    local parsed = { type = "ref", base = "main" }
    local result = parser.get_diff_args(parsed)
    helpers.assert_table_eq(result, { "main..HEAD" })
  end)

  it("returns base..head for range type", function()
    local parsed = { type = "range", base = "main", head = "feature" }
    local result = parser.get_diff_args(parsed)
    helpers.assert_table_eq(result, { "main..feature" })
  end)

  it("returns pr-N placeholder for pr type", function()
    local parsed = { type = "pr", pr_number = 334 }
    local result = parser.get_diff_args(parsed)
    helpers.assert_table_eq(result, { "pr-334" })
  end)

  it("handles unknown type gracefully", function()
    local parsed = { type = "unknown" }
    local result = parser.get_diff_args(parsed)
    helpers.assert_table_eq(result, {})
  end)
end)
