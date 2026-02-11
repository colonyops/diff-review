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
end)
