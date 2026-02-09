# diff-review.nvim

A Neovim plugin for reviewing git diffs and pull requests with an intuitive split-pane interface.

## Features

- 🔍 Split-pane interface (file list + diff view)
- 🗂️ Tree or flat file list view
- 📝 Git status integration (M/A/D indicators)
- 💬 Inline review comments with counts per file
- ➕➖ Line change stats per file
- ⌨️  Vim-style navigation and folding controls
- 🎨 Syntax highlighting for diffs
- ⚙️  Configurable keymaps, UI, and diff tools

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

Submit PR review comments (PR reviews only):
```vim
:DiffReviewSubmit
```

### Keybindings (default)

In the file list panel:
- `j` / `k` - Navigate between files
- `Enter` - View file diff
- `r` - Refresh file list
- `<Tab>` - Toggle directory fold (tree view)
- `o` - Open directory (tree view)
- `O` - Close directory (tree view)
- `<leader>t` - Toggle tree/flat view
- `q` - Close window

In the diff panel:
- `q` - Close window
- Standard Neovim navigation
- `<leader>c` - Add comment at cursor
- `<leader>e` - Edit comment at cursor
- `<leader>d` - Delete comment at cursor
- `<leader>l` - List comments for current file
- `<leader>v` - View all comments in quickfix

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
    open_directory = "o",
    close_directory = "O",
    add_comment = "<leader>c",
    edit_comment = "<leader>e",
    delete_comment = "<leader>d",
    list_comments = "<leader>l",
    view_all_comments = "<leader>v",
  },
  file_list = {
    view_mode = "tree", -- "flat" or "tree"
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
    tool = "git", -- "git" | "difftastic" | "delta" | "custom"
    custom_command = "", -- used when tool = "custom", supports {args}
  },
})
```

## Diff Tools

By default the plugin uses `git diff`. You can switch to alternative tools:

```lua
require('diff-review').setup({
  diff = {
    tool = "difftastic", -- or "delta"
  },
})
```

For custom tools, provide a command with `{args}` placeholder:

```lua
require('diff-review').setup({
  diff = {
    tool = "custom",
    custom_command = "my-diff-tool {args}",
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
