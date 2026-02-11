# Changelog

All notable changes to this project will be documented in this file.

This changelog starts tracking releases from the point it was introduced.

## Unreleased

### Added

- **Note Mode**: Add comments to any codebase files without diff context
  - Multiple note sets for different purposes (e.g., "security-audit", "refactoring")
  - Persistent storage across Neovim sessions with auto-restore
  - Same keymaps and UI as diff review mode for consistency
  - Export notes to markdown with optional code context
  - New commands: `:DiffNote enter/exit/toggle/clear/list/switch/copy`
  - Separate storage from review comments (`.diff-review/notes/`)
  - Session persistence and auto-restore on startup (configurable)

### Changed

- Consolidated commands to `:DiffReview` and `:DiffNote` with subcommands
- Improved command completion and help text
