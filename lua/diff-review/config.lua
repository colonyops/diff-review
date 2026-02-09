local M = {}

-- Default configuration
M.defaults = {
  -- Fuzzy finder for review switching
  picker = "snacks",       -- "snacks" | "telescope"

  -- Window layout
  layout = {
    file_list_width = 45,  -- Width of file list panel
    min_width = 120,       -- Minimum total width
    min_height = 20,       -- Minimum total height
    position = "center",   -- "center", "left", "right", "top", "bottom"
  },

  -- Keymaps for navigation
  keymaps = {
    next_file = "j",
    prev_file = "k",
    select_file = "<CR>",
    close = "q",
    refresh = "r",
    toggle_fold = "<Tab>",
    open_directory = "o",
    close_directory = "O",
    -- Comment keymaps
    add_comment = "<leader>c",
    edit_comment = "<leader>e",
    delete_comment = "<leader>d",
    list_comments = "<leader>l",
    view_all_comments = "<leader>v",
  },

  -- File list options
  file_list = {
    view_mode = "tree",  -- "flat" or "tree"
    focus_diff_on_select = true,  -- Auto-focus diff window when selecting a file
  },

  -- Git options
  git = {
    base_branch = "main",  -- Default base branch for diffs
    diff_args = {},        -- Additional args for git diff
  },

  -- UI options
  ui = {
    border = "rounded",    -- Border style: "none", "single", "double", "rounded"
    show_icons = true,     -- Show file type icons
    show_stats_header = true,  -- Show statistics header at top of file list
    stats_header = {
      separator = " | ",   -- Separator between stats and file list
    },
    text_wrap_width = 80,  -- Maximum width for comment text before wrapping
    comment_window = {
      initial_height = 10,  -- Starting height of comment window
      max_height = 30,      -- Maximum height for comment window
      dynamic_resize = true,  -- Auto-resize based on content
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
    context_lines = 3,     -- Lines of context around changes
    ignore_whitespace = false,
    syntax_highlighting = true,
  },

  -- Persistence options
  persistence = {
    auto_save = true,      -- Auto-save comments after each change
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
  return M.options
end

function M.get()
  return M.options
end

return M
