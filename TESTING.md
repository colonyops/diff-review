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

TODO: Add automated tests with plenary.nvim
