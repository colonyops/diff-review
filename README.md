# diff-review.nvim

A Neovim plugin for reviewing git diffs and pull requests with an intuitive split-pane interface.

## Features

- Split-pane interface (file list + diff view)
- Tree or flat file list view
- Git status integration (M/A/D indicators)
- Inline review comments with counts per file
- Line change stats per file
- Vim-style navigation and folding controls
- Syntax highlighting with treesitter (strips +/- and shows as line backgrounds)
- Configurable keymaps, UI, and diff tools
- Auto-focus diff window for seamless navigation
- Statistics header with aggregate review metrics
- Dynamic comment window that resizes with content

## Requirements

- Neovim >= 0.8.0
- Git
- (Optional) Treesitter parsers for syntax highlighting

## Installation

### Using lazy.nvim

```lua
{
  'hay-kot/diff-review.nvim',
  dependencies = {
    'nvim-treesitter/nvim-treesitter', -- Optional, for syntax highlighting
  },
  config = function()
    require('diff-review').setup({
      -- Configuration options (all optional)
      layout = {
        file_list_width = 45,
        position = "center",
      },
      diff = {
        syntax_highlighting = true, -- Enable treesitter-based syntax highlighting
      },
    })
  end
}
```

### Using packer.nvim

```lua
use {
  'hay-kot/diff-review.nvim',
  requires = {
    'nvim-treesitter/nvim-treesitter', -- Optional, for syntax highlighting
  },
  config = function()
    require('diff-review').setup()
  end
}
```

### Manual Installation

Clone the repository into your Neovim runtime path:

```bash
git clone https://github.com/hay-kot/diff-review.nvim ~/.local/share/nvim/site/pack/plugins/start/diff-review.nvim
```

Then add to your init.lua:

```lua
require('diff-review').setup()
```

## Usage

### Commands

Open the diff review window:
```vim
:DiffReview
```

Review changes against a specific branch:
```vim
:DiffReview origin/main
```

Review a pull request (requires gh CLI):
```vim
:DiffReviewPR 123
```

Submit PR review comments (PR reviews only):
```vim
:DiffReviewSubmit
```

### Keybindings (default)

**File List Panel:**
- `j` / `k` - Navigate between files
- `Enter` - View file diff
- `r` - Refresh file list
- `<Tab>` - Toggle directory fold (tree view)
- `o` - Open directory (tree view)
- `O` - Close directory (tree view)
- `<leader>t` - Toggle tree/flat view
- `q` - Close window

**Diff Panel:**
- `q` - Close window
- Standard Neovim navigation (`j`, `k`, `gg`, `G`, etc.)
- `<leader>c` - Add comment at cursor (normal) or for range (visual)
- `<leader>e` - Edit comment at cursor
- `<leader>d` - Delete comment at cursor
- `<leader>l` - List comments for current file
- `<leader>v` - View all comments in quickfix

## Configuration

Full configuration with defaults:

```lua
require('diff-review').setup({
  -- Picker for review selection
  picker = "snacks", -- "snacks" | "telescope"

  -- Window layout
  layout = {
    file_list_width = 45,
    min_width = 120,
    min_height = 20,
    position = "center", -- "center" | "left" | "right" | "top" | "bottom"
  },

  -- Keymaps
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

  -- File list options
  file_list = {
    view_mode = "tree", -- "flat" | "tree"
    focus_diff_on_select = true, -- Auto-focus diff window when selecting a file
  },

  -- Git options
  git = {
    base_branch = "main",
    diff_args = {},
  },

  -- UI options
  ui = {
    border = "rounded", -- "none" | "single" | "double" | "rounded"
    show_icons = true,
    show_stats_header = true, -- Show statistics header at top of file list
    stats_header = {
      separator = " | ", -- Separator between stats and file list
    },
    comment_window = {
      initial_height = 10, -- Starting height of comment window
      max_height = 30, -- Maximum height for comment window
      dynamic_resize = true, -- Auto-resize based on content
    },
    status = {
      symbols = {
        modified = "M",
        added = "A",
        deleted = "D",
        renamed = "R",
      },
      highlights = {
        modified = "DiffChange",
        added = "DiffAdd",
        deleted = "DiffDelete",
        renamed = "DiffReviewRenamed",
      },
    },
    comment_line_bg = nil, -- Override comment line background (e.g., "#2f3b45")
    comment_line_hl = nil, -- Link comment line highlight to another group
    colors = {
      added = "DiffAdd",
      removed = "DiffDelete",
      modified = "DiffChange",
      selected = "Visual",
    },
  },

  -- Diff display options
  diff = {
    context_lines = 3,
    ignore_whitespace = false,
    syntax_highlighting = true, -- Use treesitter to highlight code, show +/- as line backgrounds
    tool = "git", -- "git" | "difftastic" | "delta" | "custom"
    custom_command = "", -- used when tool = "custom", supports {args}
  },

  -- Persistence options
  persistence = {
    auto_save = true, -- Auto-save comments after each change
  },
})
```

### Quality of Life Features

**Auto-focus Diff Window**: When enabled, selecting a file automatically focuses the diff window for immediate viewing:
```lua
require('diff-review').setup({
  file_list = {
    focus_diff_on_select = true, -- Default: true
  },
})
```

**Statistics Header**: Display aggregate review statistics at the top of the file list:
```lua
require('diff-review').setup({
  ui = {
    show_stats_header = true, -- Default: true
    stats_header = {
      separator = " | ", -- Line separator
    },
  },
})
```

The statistics header shows:
- Review type (PR number, branch comparison, etc.)
- File counts by status (Modified, Added, Deleted)
- Total line additions and deletions
- Comment count

**Dynamic Comment Window**: The comment input window automatically resizes based on content:
```lua
require('diff-review').setup({
  ui = {
    comment_window = {
      initial_height = 10, -- Starting height
      max_height = 30, -- Maximum height
      dynamic_resize = true, -- Default: true
    },
  },
})
```

### Customizing Status Symbols

The file list displays the status of each file (Modified, Added, Deleted, Renamed) using single-letter indicators. You can customize both the symbols and their colors:

**With brackets:**
```lua
require('diff-review').setup({
  ui = {
    status = {
      symbols = {
        modified = "[M]",
        added = "[A]",
        deleted = "[D]",
        renamed = "[R]",
      },
    },
  },
})
```

**Longer text:**
```lua
require('diff-review').setup({
  ui = {
    status = {
      symbols = {
        modified = "MOD",
        added = "NEW",
        deleted = "DEL",
        renamed = "REN",
      },
    },
  },
})
```

**Custom colors:**
```lua
require('diff-review').setup({
  ui = {
    status = {
      highlights = {
        modified = "WarningMsg",
        added = "String",
        deleted = "ErrorMsg",
        renamed = "Function",
      },
    },
  },
})
```

## Syntax Highlighting

When `syntax_highlighting = true`, the plugin:
- Detects the file type from the file extension
- Applies treesitter syntax highlighting to the code
- Shows added lines with green background
- Shows deleted lines with red background
- Strips +/- prefixes for clean code display

This requires treesitter parsers for the languages you're reviewing. Install them with:
```vim
:TSInstall <language>
```

## Diff Tools

By default the plugin uses `git diff`. You can switch to alternative tools:

### Difftastic

```lua
require('diff-review').setup({
  diff = {
    tool = "difftastic",
  },
})
```

### Delta

```lua
require('diff-review').setup({
  diff = {
    tool = "delta",
  },
})
```

### Custom Tool

For custom tools, provide a command with `{args}` placeholder:

```lua
require('diff-review').setup({
  diff = {
    tool = "custom",
    custom_command = "my-diff-tool {args}",
  },
})
```

## Comments and Reviews

### Local Reviews

Comments are stored locally in `.diff-review/` directory and persist across sessions. You can:
- Add comments to specific lines or ranges
- Edit and delete comments
- Export comments to markdown
- View all comments in quickfix list

### Pull Request Reviews

When reviewing a PR (via `:DiffReviewPR`), you can submit comments directly to GitHub:

```vim
:DiffReviewSubmit
```

This requires the [GitHub CLI](https://cli.github.com/) to be installed and authenticated.

## Exporting Comments

Export all comments to markdown:
```vim
:DiffReviewExport
```

Export with annotated diff:
```vim
:DiffReviewExport annotated
```

## Development

### Project Structure

```
lua/diff-review/
├── init.lua         # Main entry point
├── config.lua       # Configuration management
├── layout.lua       # Window/buffer management
├── file_list.lua    # File list panel with tree/flat views
├── tree_view.lua    # Tree structure building and flattening
├── diff.lua         # Git diff execution/parsing
├── ui.lua           # Comment UI rendering
├── comments.lua     # Comment storage and management
├── actions.lua      # Comment actions (add/edit/delete)
├── popup.lua        # Comment input popup
└── reviews.lua      # Review session management
```

### Testing Locally

Clone the repo and add it to your Neovim config:

```lua
vim.opt.runtimepath:append("~/path/to/diff-review.nvim")
require('diff-review').setup()
```

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT
