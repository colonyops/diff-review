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

**Main diff review command:**
```vim
:DiffReview              " Open with prompt to select type
:DiffReview origin/main  " Review against branch
:DiffReview pr:123       " Review pull request
:DiffReview close        " Close review
:DiffReview toggle       " Toggle visibility
:DiffReview list         " List/switch reviews
:DiffReview copy [mode]  " Copy to clipboard (comments/full/diff)
:DiffReview submit       " Submit to GitHub
:DiffReview health       " Health check
```

**Shortcut for toggling** (most common operation):
```vim
:DiffReviewToggle        " Quick toggle (preserves state)
```

### Navigating to Files

You can navigate directly from the diff view to the actual file in your editor:

- `gf` - Open file at cursor position in current window
- `<C-w>f` - Open file in horizontal split
- `<C-w>gf` - Open file in vertical split

Alternatively, use commands:
```vim
:DiffReviewOpenFile
:DiffReviewOpenFileSplit
:DiffReviewOpenFileVsplit
```

**Behavior:**
- For added and context lines: Opens file at the corresponding line number
- For deleted lines: Shows notification (cannot navigate to deleted content)
- For hunk headers: Jumps to the start of the hunk
- Closes the review window and returns focus to the original window

### Toggle Review with State Preservation

The `:DiffReviewToggle` command allows you to close and reopen the review while preserving your session state:

```lua
-- Map to a convenient key
vim.keymap.set("n", "<leader>dr", ":DiffReviewToggle<CR>", { desc = "Toggle diff review" })
```

**Preserved state includes:**
- Review context (PR number, branch comparison, uncommitted changes)
- Selected file and position
- Cursor and scroll position in diff view
- View mode (tree or flat)

State persists across Neovim restarts in `~/.local/share/nvim/diff-review/session_state.json` (respects `$XDG_DATA_HOME`).

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
- `gf` - Open file at cursor in current window
- `<C-w>f` - Open file in horizontal split
- `<C-w>gf` - Open file in vertical split
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

  -- Note mode options
  notes = {
    default_set = "default", -- Default note set name
    auto_restore = true, -- Auto-restore note mode on startup
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

When reviewing a PR (via `:DiffReview pr:123`), you can submit comments directly to GitHub:

```vim
:DiffReview submit
```

This requires the [GitHub CLI](https://cli.github.com/) to be installed and authenticated.

## Note Mode

Note mode allows you to add comments to any files in your codebase without requiring diff or review context. Perfect for code audits, documentation, learning notes, or refactoring plans.

### Features

- **Works anywhere**: Comment on any file during normal editing, no special layout required
- **Multiple note sets**: Organize notes for different purposes (e.g., "security-audit", "refactoring")
- **Persistent**: Notes auto-save and persist across Neovim sessions
- **Session restore**: Automatically restores note mode on startup (configurable)
- **Same UI**: Reuses diff review keymaps and styling for consistency

### Commands

**All note mode operations:**
```vim
:DiffNote enter [set]    " Enter note mode (default set if not specified)
:DiffNote exit           " Exit note mode
:DiffNote toggle [set]   " Toggle note mode
:DiffNote clear          " Clear all notes in current set
:DiffNote list           " List and switch between sets
:DiffNote switch <set>   " Switch to a different set
:DiffNote copy [mode]    " Copy to clipboard (notes/full)
```

**Examples:**
```vim
:DiffNote enter security-audit    " Start security audit notes
:DiffNote toggle                  " Quick toggle
:DiffNote copy full               " Export with code context
```

### Usage

1. **Enter note mode** with `:DiffNote enter [set_name]`
2. **Navigate files normally** (`:edit`, buffer switches, etc.)
3. **Add comments** using the same keymaps as diff review:
   - `<leader>c` - Add comment at cursor (or range in visual mode)
   - `<leader>e` - Edit comment at cursor
   - `<leader>d` - Delete comment at cursor
   - `<leader>l` - List comments for current file
   - `<leader>v` - View all comments (across all files)
4. **Comments auto-save** on each change
5. **Exit mode** with `:DiffNote exit` or toggle with `:DiffNote toggle`

### Storage

Notes are stored in `.diff-review/notes/` directory:
```
.diff-review/
├── notes/
│   ├── default.json          # Default note set
│   ├── security-audit.json   # Named set
│   └── refactoring.json      # Another named set
```

### Configuration

Configure note mode behavior in your setup:

```lua
require('diff-review').setup({
  notes = {
    default_set = "default",  -- Default note set name
    auto_restore = true,      -- Auto-restore note mode on startup
  },
})
```

### Example Workflows

**Code audit:**
```vim
:DiffNote enter security-audit
" Navigate files and add notes about security concerns
" Notes persist across sessions
```

**Refactoring plan:**
```vim
:DiffNote enter refactoring
" Document areas that need refactoring
" Switch between note sets as needed
:DiffNote switch technical-debt
```

**Learning codebase:**
```vim
:DiffNote enter learning
" Add notes about how things work
" View all notes: <leader>v
```

### Exporting Notes

Copy all notes to clipboard in markdown format:

**Notes only (with line numbers):**
```vim
:DiffNote copy
```

Output format:
```markdown
## Notes

**Note Set:** security-audit
**Date:** 2024-01-15 10:30

---

### src/auth.lua

- Line 45: Potential SQL injection vulnerability
- Lines 60-65: Missing input validation

### src/user.lua

- Line 23: TODO: Add rate limiting

---

**Total:** 3 notes across 2 files
```

**Full export (with code context):**
```vim
:DiffNote copy full
```

Includes 2 lines of code context before/after each note with syntax highlighting.

### Coexistence with Diff Review

Note mode and diff review mode can run simultaneously:
- Separate namespaces prevent conflicts
- Separate storage directories
- Both can be visible at the same time
- No conversion between notes and review comments

## Exporting Comments

Export all review comments to markdown:
```vim
:DiffReview copy           " Comments with line numbers
:DiffReview copy full      " Comments with code context
:DiffReview copy diff      " Annotated diff format
```

## Troubleshooting

### Layout fails to open or windows disappear

If you see "Layout failed to open correctly" or the diff view doesn't appear, this is often caused by session restore plugins interfering with the layout creation.

**Symptoms:**
- Windows open briefly then disappear
- "Layout failed to open" warning
- More common when using `nvim -c "DiffReview ..."` from command line
- May happen with other buffers/tabs already open

**Solution for auto-session users:**

Add this to the very top of your `init.lua` (before plugins load):

```lua
-- Disable auto-session when using -c commands
for _, arg in ipairs(vim.v.argv) do
  if arg == "-c" or arg == "+c" then
    vim.g.auto_session_enabled = false
    break
  end
end
```

Then update your auto-session config:

```lua
require("auto-session").setup({
  -- Add DiffReview to bypass list
  bypass_session_save_file_types = {
    "", "blank", "alpha", "NvimTree", "nofile",
    "Trouble", "dapui", "dap", "DiffReview"
  },
  -- Close diff-review before saving session
  pre_save_cmds = {
    "tabdo NvimTreeClose",
    "silent! DiffReviewClose"
  },
})
```

And add conditional loading to the plugin spec:

```lua
{
  "rmagatti/auto-session",
  cond = function()
    return vim.g.auto_session_enabled ~= false
  end,
  config = function()
    -- your setup here
  end,
}
```

**Solution for other session plugins (persisted.nvim, possession, etc.):**

Disable the plugin when starting with `-c` commands, or defer diff-review operations:

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "PersistedLoadPost", -- or your plugin's event
  callback = function()
    vim.defer_fn(function()
      -- Safe to use diff-review now
    end, 200)
  end,
})
```

**Health check:**

Run `:DiffReviewHealth` to diagnose layout issues and detect session plugins.

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
