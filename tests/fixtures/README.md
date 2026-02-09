# Test Fixtures

This directory contains test fixtures used by the integration tests.

## Diff Fixtures (`diffs/`)

### Git Diff Outputs

- `standard.diff` - Standard unified diff with additions and deletions
- `rename.diff` - File rename with modifications
- `binary.diff` - Binary file change
- `multi_hunk.diff` - Multiple hunks in a single file
- `empty.diff` - Empty diff (no changes)
- `all_added.diff` - Newly added file
- `all_deleted.diff` - Deleted file

### Git Command Outputs

- `git_status_standard.txt` - Output of `git status --porcelain` with various file states
- `git_status_rename.txt` - Git status with file rename
- `git_name_status_standard.txt` - Output of `git diff --name-status`
- `git_name_status_rename.txt` - Name status with file rename
- `git_numstat.txt` - Output of `git diff --numstat` including binary file

## GitHub Fixtures (`github/`)

- `diff_with_positions.txt` - Annotated diff showing expected position values for GitHub API
- `range_valid.json` - Valid multi-line comment range (both lines on same side)
- `range_invalid.json` - Invalid range spanning both sides (should fail validation)
- `single_line_range.json` - Single-line range comment

## Comment Fixtures (`comments/`)

- `basic_comments.json` - Standard comment array with multiple files
- `empty_comments.json` - Empty comment array
- `special_chars.json` - Comments with special characters (quotes, newlines, symbols)
- `multiple_same_line.json` - Multiple comments on the same line
- `range_comments.json` - Comments with line ranges

## Usage

Load fixtures in tests using the helper function:

```lua
local helpers = require("tests.helpers")
local fixture = helpers.load_fixture("diffs/standard.diff")
```

For JSON fixtures:

```lua
local fixture = helpers.load_json_fixture("comments/basic_comments.json")
```
