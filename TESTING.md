# Testing diff-review.nvim

## Manual Testing

1. Make some changes to files in your git repo
2. Open Neovim
3. Run `:lua require('diff-review').setup()`
4. Run `:DiffReview`

You should see:
- Left panel: List of changed files with status indicators (M/A/D)
- Right panel: Diff view of the selected file

### Navigation
- Press `j`/`k` to navigate between files
- Press `Enter` to select a file and view its diff
- Press `q` to close the window
- Press `r` to refresh the file list

## Automated Testing

Tests are written using [plenary.nvim](https://github.com/nvim-lua/plenary.nvim).

### Running Tests

Run all tests:
```bash
task test
```

Run a specific test file:
```bash
task test-file -- tests/config_spec.lua
```

### Test Coverage

- `tests/config_spec.lua` - Configuration module tests
  - Default status symbols and highlights
  - Custom configuration merging
  - Partial overrides
  - Backwards compatibility

- `tests/file_list_spec.lua` - File list status icon tests
  - Default status icon behavior
  - Custom symbols (brackets, longer text)
  - Custom highlight groups
  - Fallback behavior

### Setup

The first time you run tests, plenary.nvim will be automatically cloned to `/tmp/plenary.nvim`. To clean up:
```bash
task clean-test
```

### Writing New Tests

Test files should be placed in `tests/` and follow the naming convention `*_spec.lua`. Use plenary's `describe` and `it` blocks:

```lua
local my_module = require("diff-review.my_module")

describe("my_module", function()
  it("should do something", function()
    assert.equals("expected", my_module.do_something())
  end)
end)
```
