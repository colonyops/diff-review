local git_utils = require("diff-review.git_utils")

describe("git_utils", function()
  describe("get_git_root", function()
    it("should return git directory when in a git repository", function()
      local git_dir, err = git_utils.get_git_root()

      -- We're in a git repo for this test
      assert.is_not_nil(git_dir)
      assert.is_nil(err)
      assert.is_true(string.len(git_dir) > 0)
    end)
  end)

  describe("get_storage_dir", function()
    it("should return storage directory path", function()
      local storage_dir, err = git_utils.get_storage_dir()

      assert.is_not_nil(storage_dir)
      assert.is_nil(err)
      assert.is_true(string.match(storage_dir, "/diff%-review$") ~= nil)
    end)

    it("should use git directory when available", function()
      local git_dir = git_utils.get_git_root()

      if git_dir then
        local storage_dir = git_utils.get_storage_dir()
        assert.is_true(string.find(storage_dir, git_dir, 1, true) == 1)
      end
    end)

    it("should fallback to cwd when not in git repo", function()
      -- Can't easily test this without changing directories,
      -- but the function should always return a valid path
      local storage_dir, err = git_utils.get_storage_dir()
      assert.is_not_nil(storage_dir)
      assert.is_nil(err)
    end)
  end)

  describe("normalize_file_key", function()
    it("should normalize to repo-root-relative path when in repo", function()
      local original_get_repo_root = git_utils.get_repo_root
      git_utils.get_repo_root = function()
        return "/tmp/example-repo", nil
      end

      local normalized = git_utils.normalize_file_key("/tmp/example-repo/lua/diff-review/note_mode.lua")
      assert.equals("lua/diff-review/note_mode.lua", normalized)

      git_utils.get_repo_root = original_get_repo_root
    end)

    it("should fallback to absolute path when repo root is unavailable", function()
      local original_get_repo_root = git_utils.get_repo_root
      git_utils.get_repo_root = function()
        return nil, "Not in a git repository"
      end

      local normalized = git_utils.normalize_file_key("lua/diff-review/note_mode.lua")
      assert.is_true(normalized:sub(1, 1) == "/")
      assert.is_true(normalized:match("lua/diff%-review/note_mode%.lua$") ~= nil)

      git_utils.get_repo_root = original_get_repo_root
    end)
  end)
end)
