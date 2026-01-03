# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-01-03

### Added
- "PR" text icon in menu bar with badge count (replaces SF Symbol)
- Last commit message display in PR menu items
- Custom notification sound support (mp3/wav/aiff via config or `PR_REVIEW_SOUND_PATH` env var)
- LaunchAgent for auto-start on login (`~/Library/LaunchAgents/com.prreview.system.plist`)
- Diff hunk navigation (`<leader>nd` / `<leader>pd` jump between diff hunks)

### Changed
- Ghostty launcher now uses Process API for reliable terminal launching
- GitHub token embedded in clone URLs for private repo authentication
- Parallel repo fetching for faster PR list loading (4x speedup with 4 repos)
- API request timeout set to 15 seconds to prevent hanging
- Optimized commit fetching (single page instead of all pages)
- PR list updates immediately, commit messages fill in asynchronously
- Comment save/cancel changed to `:w` / `:q` (was Ctrl+S)
- Comment navigation changed to `<leader>nc` / `<leader>pc` (was `]c` / `[c`)
- Removed Preferences menu item (edit config file directly)

### Fixed
- App crash when running as standalone executable (lazy notification center init)
- Git clone authentication for private repositories
- Tilde expansion in clone_root path

## [1.0.0] - 2026-01-03

### Added
- Loading spinner module (`nvim/lua/pr-review/spinner.lua`)
- Animated loading indicators for async operations
- Spinner tests (11 Lua)

### Changed
- Fixed CleanupService tests to use isolated state directories
- All 84 Swift tests and 210 Lua tests passing

### Summary
First stable release with complete PR review workflow:
- macOS menu bar app with polling and notifications
- Neovim plugin with diff display, comments, and review submission
- GitHub API integration with pagination
- Git operations for cloning and updating PR branches
- Automatic cleanup of old PR directories

## [0.13.0] - 2026-01-03

### Added
- CleanupService module (`app/Sources/PRReviewSystem/CleanupService.swift`)
- Automatic cleanup of PR directories older than 30 days
- State persistence in `state.json` tracking last cleanup date
- Preview mode to see what would be deleted without deleting
- Integration in AppDelegate - runs on app launch if 24+ hours since last cleanup
- CleanupService tests (8 Swift) + CleanupResult tests (5 Swift)

### Changed
- AppDelegate initializes and runs CleanupService on launch

## [0.12.0] - 2026-01-03

### Added
- PRPoller module (`app/Sources/PRReviewSystem/PRPoller.swift`)
- NotificationManager module (`app/Sources/PRReviewSystem/NotificationManager.swift`)
- Timer-based polling for PR updates at configured intervals
- Change detection: new PRs, new commits, new comments, status changes
- System notifications with actionable categories (Open PR, Dismiss)
- Notification callbacks for opening PRs from notification clicks
- Integration in AppDelegate with full polling lifecycle
- PRPoller tests (10 Swift) + NotificationManager enum tests (2 Swift)

### Changed
- AppDelegate now uses PRPoller for background PR monitoring
- All notifications routed through NotificationManager singleton
- GitHubAPI made public for cross-module usage

## [0.11.0] - 2026-01-03

### Added
- GhosttyLauncher module (`app/Sources/PRReviewSystem/GhosttyLauncher.swift`)
- NSWorkspace-based Ghostty terminal launching
- PR clone/update before opening in Neovim
- `openPR` method: clones repo, fetches branch, launches `nvim -c 'PRReview open {url}'`
- `openPRByURL` method for direct URL opening
- GhosttyLauncher tests (3 Swift)

### Changed
- Made Config and NotificationConfig public with Sendable conformance
- Made PullRequest and related models public for cross-module access
- Updated AppDelegate to use GhosttyLauncher for PR opening

## [0.10.0] - 2026-01-03

### Added
- Menu bar application (`app/Sources/PRReviewSystem/MenuBarController.swift`)
- AppDelegate with full app lifecycle (`app/Sources/PRReviewSystem/AppDelegate.swift`)
- NSStatusItem with SF Symbol icon and badge count
- PR list grouped by repository in menu
- Click PR to open in Ghostty + Neovim
- UserNotifications for alerts
- Menu bar tests (9 Swift)

## [0.9.0] - 2026-01-03

### Added
- Review submission module (`nvim/lua/pr-review/review.lua`)
- `:PRReview submit` command with UI for Approve/Request Changes/Comment
- Review body input with markdown support
- Quick approve via `<leader>ra`
- Review status display `<leader>ri`
- Submit review `<leader>rs`
- Pending comments bundled with review submission
- Review tests (18 Lua)

## [0.8.0] - 2026-01-03

### Added
- Comments module (`nvim/lua/pr-review/comments.lua`)
- Keymaps module (`nvim/lua/pr-review/keymaps.lua`)
- Sign column indicators for comments (resolved, pending, active)
- Virtual text preview of comments
- Comment navigation: `]c` next, `[c` previous
- Comment actions: `<leader>cc` create, `<leader>lc` list, `<leader>rc` toggle resolved
- Comment popup display with author and body
- `:PRReview comments` command to list file comments
- Comment tests (29 Lua) + Keymap tests (20 Lua)

## [0.7.0] - 2026-01-03

### Added
- Diff display module (`nvim/lua/pr-review/diff.lua`)
- Unified diff parsing (hunk headers, additions, deletions)
- DiffAdd/DiffDelete highlighting on changed lines
- File navigation keymaps: `]f` next file, `[f` previous file
- `:PRReview close` command to end review session
- Diff tests (39 Lua)

## [0.6.0] - 2026-01-03

### Added
- Session state module (`nvim/lua/pr-review/state.lua`)
- PR opening module (`nvim/lua/pr-review/open.lua`)
- `:PRReview open {url}` command - Parse URL, clone/pull repo, fetch data, open first file
- Session state: active tracking, files navigation, comments storage
- Navigation functions: next_file, prev_file, get_current_file
- State tests (24 Lua)

## [0.5.0] - 2026-01-03

### Added
- UI module for Neovim (`nvim/lua/pr-review/ui.lua`)
- Floating window helpers with title, border support
- `:PRReview list` command - shows all PRs in a floating picker
- PR list keybindings: j/k navigate, Enter open, q close, r refresh
- Multi-repo PR fetching and grouping
- UI tests (13 Lua)

## [0.4.0] - 2026-01-03

### Added
- Git operations module for Neovim (`nvim/lua/pr-review/git.lua`)
- Git operations module for Swift (`app/Sources/PRReviewSystem/GitOperations.swift`)
- Async git operations: clone, fetch_reset, get_current_branch, get_current_sha
- Helper functions: is_git_repo, get_remote_url, build_pr_path
- Git tests (17 Lua + 10 Swift)

## [0.3.0] - 2026-01-03

### Added
- GitHub API module for Neovim (`nvim/lua/pr-review/api.lua`)
- GitHub API module for Swift (`app/Sources/PRReviewSystem/GitHubAPI.swift`)
- Data models: PullRequest, PRFile, PRComment, Repository, GitHubUser
- PR URL parsing for both Lua and Swift
- Pagination support via Link header parsing
- API functions: list_prs, get_pr, get_pr_files, get_pr_comments, create_comment, submit_review
- Comprehensive API tests (15 Lua + 14 Swift)

## [0.2.0] - 2026-01-03

### Added
- Configuration module for Neovim plugin (`nvim/lua/pr-review/config.lua`)
- Configuration module for Swift app (`app/Sources/PRReviewSystem/Config.swift`)
- JSON config file support at `~/.config/pr-review/config.json`
- Config validation for required fields (github_token, github_username, repos)
- Tilde expansion for paths in config
- Default values for optional config fields
- Comprehensive config tests (11 Lua + 13 Swift)

## [0.1.0] - 2026-01-03

### Added
- Initial project structure
- Neovim plugin foundation with `setup()` entry point
- macOS menu bar app foundation (Swift Package Manager)
- Makefile with test, lint, build targets
- GitHub Actions CI workflow
- Test infrastructure for both Lua (plenary.busted) and Swift Testing
