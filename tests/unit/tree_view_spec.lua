-- Unit tests for tree_view.lua
local helpers = require("tests.helpers")

describe("tree_view.build_tree", function()
  local tree_view

  before_each(function()
    tree_view = require("diff-review.tree_view")
  end)

  it("builds tree from flat file list", function()
    local files = {
      { path = "src/main.lua" },
      { path = "src/utils.lua" },
      { path = "tests/test.lua" },
    }

    local tree = tree_view.build_tree(files)

    helpers.assert_eq(tree.type, "directory")
    helpers.assert_eq(tree.name, "")
    helpers.assert_truthy(tree.expanded)
    assert.is_not_nil(tree.children["src"])
    assert.is_not_nil(tree.children["tests"])
  end)

  it("creates nested directory structure", function()
    local files = {
      { path = "src/lib/parser.lua" },
      { path = "src/lib/renderer.lua" },
    }

    local tree = tree_view.build_tree(files)

    local src = tree.children["src"]
    helpers.assert_eq(src.type, "directory")
    helpers.assert_eq(src.name, "src")

    local lib = src.children["lib"]
    helpers.assert_eq(lib.type, "directory")
    helpers.assert_eq(lib.name, "lib")

    local parser = lib.children["parser.lua"]
    helpers.assert_eq(parser.type, "file")
    helpers.assert_eq(parser.path, "src/lib/parser.lua")
  end)

  it("handles single file", function()
    local files = {
      { path = "README.md" },
    }

    local tree = tree_view.build_tree(files)

    local readme = tree.children["README.md"]
    helpers.assert_eq(readme.type, "file")
    helpers.assert_eq(readme.name, "README.md")
    helpers.assert_eq(readme.path, "README.md")
  end)

  it("preserves file data in nodes", function()
    local files = {
      { path = "test.lua", status = "M", additions = 10, deletions = 5 },
    }

    local tree = tree_view.build_tree(files)

    local file_node = tree.children["test.lua"]
    helpers.assert_eq(file_node.file_data.status, "M")
    helpers.assert_eq(file_node.file_data.additions, 10)
    helpers.assert_eq(file_node.file_data.deletions, 5)
  end)

  it("expands all directories by default", function()
    local files = {
      { path = "a/b/c/file.lua" },
    }

    local tree = tree_view.build_tree(files)

    helpers.assert_truthy(tree.expanded)
    helpers.assert_truthy(tree.children["a"].expanded)
    helpers.assert_truthy(tree.children["a"].children["b"].expanded)
    helpers.assert_truthy(tree.children["a"].children["b"].children["c"].expanded)
  end)

  it("accepts custom root name", function()
    local files = {
      { path = "file.lua" },
    }

    local tree = tree_view.build_tree(files, "custom-root")
    helpers.assert_eq(tree.name, "custom-root")
  end)

  it("handles empty file list", function()
    local tree = tree_view.build_tree({})

    helpers.assert_eq(tree.type, "directory")
    helpers.assert_table_eq(tree.children, {})
  end)
end)

describe("tree_view.flatten_tree", function()
  local tree_view

  before_each(function()
    tree_view = require("diff-review.tree_view")
  end)

  it("flattens simple tree structure", function()
    local files = {
      { path = "a.lua" },
      { path = "b.lua" },
    }

    local tree = tree_view.build_tree(files)
    local flat = tree_view.flatten_tree(tree, files)

    helpers.assert_eq(#flat, 2)
    helpers.assert_eq(flat[1].node.name, "a.lua")
    helpers.assert_eq(flat[1].index, 1)
    helpers.assert_eq(flat[2].node.name, "b.lua")
    helpers.assert_eq(flat[2].index, 2)
  end)

  it("includes directories in flattened list", function()
    local files = {
      { path = "src/main.lua" },
    }

    local tree = tree_view.build_tree(files)
    local flat = tree_view.flatten_tree(tree, files)

    helpers.assert_eq(#flat, 2)
    helpers.assert_eq(flat[1].node.name, "src")
    helpers.assert_eq(flat[1].node.type, "directory")
    helpers.assert_eq(flat[1].index, nil)
    helpers.assert_eq(flat[2].node.name, "main.lua")
    helpers.assert_eq(flat[2].node.type, "file")
  end)

  it("sets correct depth for nested items", function()
    local files = {
      { path = "a/b/c.lua" },
    }

    local tree = tree_view.build_tree(files)
    local flat = tree_view.flatten_tree(tree, files)

    helpers.assert_eq(flat[1].depth, 1) -- "a" directory
    helpers.assert_eq(flat[2].depth, 2) -- "b" directory
    helpers.assert_eq(flat[3].depth, 2) -- "c.lua" file
  end)

  it("sorts directories before files", function()
    local files = {
      { path = "file.lua" },
      { path = "dir/nested.lua" },
    }

    local tree = tree_view.build_tree(files)
    local flat = tree_view.flatten_tree(tree, files)

    -- Directory "dir" should come before file "file.lua"
    helpers.assert_eq(flat[1].node.name, "dir")
    helpers.assert_eq(flat[1].node.type, "directory")
    helpers.assert_eq(flat[2].node.name, "nested.lua")
    helpers.assert_eq(flat[3].node.name, "file.lua")
  end)

  it("sorts items alphabetically within type", function()
    local files = {
      { path = "z.lua" },
      { path = "a.lua" },
      { path = "m.lua" },
    }

    local tree = tree_view.build_tree(files)
    local flat = tree_view.flatten_tree(tree, files)

    helpers.assert_eq(flat[1].node.name, "a.lua")
    helpers.assert_eq(flat[2].node.name, "m.lua")
    helpers.assert_eq(flat[3].node.name, "z.lua")
  end)

  it("excludes collapsed directory children", function()
    local files = {
      { path = "dir/file1.lua" },
      { path = "dir/file2.lua" },
    }

    local tree = tree_view.build_tree(files)
    tree.children["dir"].expanded = false

    local flat = tree_view.flatten_tree(tree, files)

    -- Should only include the collapsed directory, not its children
    helpers.assert_eq(#flat, 1)
    helpers.assert_eq(flat[1].node.name, "dir")
    helpers.assert_eq(flat[1].node.type, "directory")
  end)

  it("preserves file index mapping", function()
    local files = {
      { path = "b.lua" },
      { path = "a.lua" },
      { path = "c.lua" },
    }

    local tree = tree_view.build_tree(files)
    local flat = tree_view.flatten_tree(tree, files)

    -- Files should be sorted alphabetically but preserve original indices
    helpers.assert_eq(flat[1].node.name, "a.lua")
    helpers.assert_eq(flat[1].index, 2) -- Second in original list

    helpers.assert_eq(flat[2].node.name, "b.lua")
    helpers.assert_eq(flat[2].index, 1) -- First in original list

    helpers.assert_eq(flat[3].node.name, "c.lua")
    helpers.assert_eq(flat[3].index, 3) -- Third in original list
  end)

  it("handles empty tree", function()
    local tree = tree_view.build_tree({})
    local flat = tree_view.flatten_tree(tree, {})

    helpers.assert_table_eq(flat, {})
  end)
end)

describe("tree_view.toggle_directory", function()
  local tree_view

  before_each(function()
    tree_view = require("diff-review.tree_view")
  end)

  it("toggles root directory", function()
    local files = { { path = "file.lua" } }
    local tree = tree_view.build_tree(files)

    helpers.assert_truthy(tree.expanded)

    local result = tree_view.toggle_directory(tree, "")
    helpers.assert_truthy(result)
    helpers.assert_falsy(tree.expanded)

    result = tree_view.toggle_directory(tree, "")
    helpers.assert_truthy(result)
    helpers.assert_truthy(tree.expanded)
  end)

  it("toggles nested directory", function()
    local files = { { path = "src/main.lua" } }
    local tree = tree_view.build_tree(files)

    local src = tree.children["src"]
    helpers.assert_truthy(src.expanded)

    local result = tree_view.toggle_directory(tree, "src")
    helpers.assert_truthy(result)
    helpers.assert_falsy(src.expanded)
  end)

  it("toggles deeply nested directory", function()
    local files = { { path = "a/b/c/file.lua" } }
    local tree = tree_view.build_tree(files)

    local c = tree.children["a"].children["b"].children["c"]
    helpers.assert_truthy(c.expanded)

    local result = tree_view.toggle_directory(tree, "a/b/c")
    helpers.assert_truthy(result)
    helpers.assert_falsy(c.expanded)
  end)

  it("returns false for non-existent path", function()
    local tree = tree_view.build_tree({})

    local result = tree_view.toggle_directory(tree, "nonexistent")
    helpers.assert_falsy(result)
  end)

  it("returns false for file node", function()
    local files = { { path = "file.lua" } }
    local tree = tree_view.build_tree(files)

    local result = tree_view.toggle_directory(tree, "file.lua")
    helpers.assert_falsy(result)
  end)

  it("handles nil path on root", function()
    local tree = tree_view.build_tree({ { path = "file.lua" } })

    helpers.assert_truthy(tree.expanded)

    local result = tree_view.toggle_directory(tree, nil)
    helpers.assert_truthy(result)
    helpers.assert_falsy(tree.expanded)
  end)
end)

describe("tree_view.set_directory_expanded", function()
  local tree_view

  before_each(function()
    tree_view = require("diff-review.tree_view")
  end)

  it("expands collapsed directory", function()
    local files = { { path = "src/main.lua" } }
    local tree = tree_view.build_tree(files)

    tree.children["src"].expanded = false

    local result = tree_view.set_directory_expanded(tree, "src", true)
    helpers.assert_truthy(result)
    helpers.assert_truthy(tree.children["src"].expanded)
  end)

  it("collapses expanded directory", function()
    local files = { { path = "src/main.lua" } }
    local tree = tree_view.build_tree(files)

    helpers.assert_truthy(tree.children["src"].expanded)

    local result = tree_view.set_directory_expanded(tree, "src", false)
    helpers.assert_truthy(result)
    helpers.assert_falsy(tree.children["src"].expanded)
  end)

  it("returns false when state unchanged", function()
    local files = { { path = "src/main.lua" } }
    local tree = tree_view.build_tree(files)

    helpers.assert_truthy(tree.children["src"].expanded)

    -- Try to expand already expanded directory
    local result = tree_view.set_directory_expanded(tree, "src", true)
    helpers.assert_falsy(result)
  end)

  it("returns false for non-existent path", function()
    local tree = tree_view.build_tree({})

    local result = tree_view.set_directory_expanded(tree, "nonexistent", true)
    helpers.assert_falsy(result)
  end)

  it("returns false for file node", function()
    local files = { { path = "file.lua" } }
    local tree = tree_view.build_tree(files)

    local result = tree_view.set_directory_expanded(tree, "file.lua", false)
    helpers.assert_falsy(result)
  end)
end)

describe("tree_view.find_file_index", function()
  local tree_view

  before_each(function()
    tree_view = require("diff-review.tree_view")
  end)

  it("finds file by path", function()
    local files = {
      { path = "a.lua" },
      { path = "b.lua" },
      { path = "c.lua" },
    }

    local index = tree_view.find_file_index(files, "b.lua")
    helpers.assert_eq(index, 2)
  end)

  it("finds file with nested path", function()
    local files = {
      { path = "src/main.lua" },
      { path = "src/utils.lua" },
    }

    local index = tree_view.find_file_index(files, "src/utils.lua")
    helpers.assert_eq(index, 2)
  end)

  it("returns nil for non-existent path", function()
    local files = {
      { path = "a.lua" },
    }

    local index = tree_view.find_file_index(files, "nonexistent.lua")
    helpers.assert_eq(index, nil)
  end)

  it("handles empty file list", function()
    local index = tree_view.find_file_index({}, "any.lua")
    helpers.assert_eq(index, nil)
  end)

  it("finds first file in list", function()
    local files = {
      { path = "first.lua" },
      { path = "second.lua" },
    }

    local index = tree_view.find_file_index(files, "first.lua")
    helpers.assert_eq(index, 1)
  end)

  it("finds last file in list", function()
    local files = {
      { path = "first.lua" },
      { path = "second.lua" },
      { path = "last.lua" },
    }

    local index = tree_view.find_file_index(files, "last.lua")
    helpers.assert_eq(index, 3)
  end)
end)
