# nvim-web-devicons Integration Testing

## Manual Test Steps

1. **Without devicons installed:**
   - Open the plugin: `:DiffReviewOpen`
   - Verify file list shows without icons (graceful degradation)
   - Verify no errors in `:messages`

2. **With devicons installed:**
   - Install nvim-web-devicons (e.g., via lazy.nvim)
   - Open the plugin: `:DiffReviewOpen`
   - Verify file icons appear next to filenames
   - Verify icons are colored appropriately
   - Verify status icons (●, +, -, →) still display correctly

## Expected Behavior

- Status icon appears first: `> ● lua/diff-review/file_list.lua`
- File icon appears between status and filename: `> ●  lua/diff-review/file_list.lua`
- Each file type should have appropriate icon:
  - `.lua` files → 󰢱 (Lua icon)
  - `.md` files →  (Markdown icon)
  - `.json` files →  (JSON icon)
  - etc.

## Implementation Details

- `pcall` used for safe loading of devicons
- Falls back to no icons if module not available
- Icon colors applied via dynamic highlight groups
- Pattern: `DevIcon_{sanitized_filepath}`
