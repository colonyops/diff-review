# diff-review.nvim

A Neovim plugin for reviewing git diffs and pull requests with an intuitive split-pane interface.

## Features

- 🔍 Split-pane interface (file list + diff view)
- 📝 Git status integration (M/A/D indicators)
- ⌨️  Vim-style navigation (j/k/Enter)
- 🎨 Syntax highlighting for diffs
- ⚙️  Configurable keymaps and UI

## Installation

### Using lazy.nvim

```lua
{
  'hay-kot/diff-review.nvim',
  config = function()
    require('diff-review').setup({
      -- Configuration options (all optional)
      layout = {
        file_list_width = 40,
        position = "center",
      },
      keymaps = {
        next_file = "j",
        prev_file = "k",
        select_file = "<CR>",
        close = "q",
        refresh = "r",
      },
    })
  end
}
```

### Using packer.nvim

```lua
use {
  'hay-kot/diff-review.nvim',
  config = function()
    require('diff-review').setup()
  end
}
```

## Usage

Open the diff review window:
```vim
:DiffReview
```

### Keybindings (default)

In the file list panel:
- `j` / `k` - Navigate between files
- `Enter` - View file diff
- `r` - Refresh file list
- `q` - Close window

In the diff panel:
- `q` - Close window
- Standard Neovim navigation

## Configuration

Full configuration with defaults:

```lua
require('diff-review').setup({
  layout = {
    file_list_width = 40,
    min_width = 120,
    min_height = 20,
    position = "center",
  },
  keymaps = {
    next_file = "j",
    prev_file = "k",
    select_file = "<CR>",
    close = "q",
    refresh = "r",
    toggle_fold = "<Tab>",
  },
  git = {
    base_branch = "main",
    diff_args = {},
  },
  ui = {
    border = "rounded",
    show_icons = true,
    colors = {
      added = "DiffAdd",
      removed = "DiffDelete",
      modified = "DiffChange",
      selected = "Visual",
    },
  },
  diff = {
    context_lines = 3,
    ignore_whitespace = false,
    syntax_highlighting = true,
  },
})
```

## Development

This plugin is under active development. Contributions are welcome!

### Project Structure

```
lua/diff-review/
├── init.lua        # Main entry point
├── config.lua      # Configuration management
├── layout.lua      # Window/buffer management
├── file_list.lua   # File list panel
├── diff.lua        # Git diff execution/parsing
└── ui.lua          # UI rendering
```

### Testing Locally

Clone the repo and add it to your Neovim config:

```lua
vim.opt.runtimepath:append("~/path/to/diff-review.nvim")
require('diff-review').setup()
```

## License

MIT
