# PR Review System - Development Guide

## Project Structure

```
pr-review-system/
├── app/                          # macOS menu bar app (Swift)
│   ├── Package.swift
│   ├── Sources/PRReviewSystem/
│   │   ├── main.swift           # Entry point
│   │   ├── AppDelegate.swift    # App lifecycle, PR fetching
│   │   ├── MenuBarController.swift  # Menu bar UI
│   │   ├── GhosttyLauncher.swift    # Opens Ghostty + Neovim
│   │   ├── GitHubAPI.swift      # GitHub API client
│   │   ├── GitOperations.swift  # Git clone/fetch operations
│   │   ├── NotificationManager.swift  # System notifications
│   │   ├── PRPoller.swift       # Background polling
│   │   ├── CleanupService.swift # Old PR directory cleanup
│   │   ├── Config.swift         # Configuration loading
│   │   └── Models/              # Data models
│   └── Tests/
│
├── nvim/                         # Neovim plugin (Lua)
│   ├── lua/pr-review/
│   │   ├── init.lua             # Plugin entry point
│   │   ├── api.lua              # GitHub API client
│   │   ├── config.lua           # Configuration
│   │   ├── git.lua              # Git operations
│   │   ├── ui.lua               # Floating windows
│   │   ├── diff.lua             # Diff display & navigation
│   │   ├── comments.lua         # Comment system
│   │   ├── keymaps.lua          # Buffer-local keybindings
│   │   ├── review.lua           # Review submission
│   │   ├── state.lua            # Session state
│   │   └── open.lua             # PR opening logic
│   ├── plugin/pr-review.lua     # Command registration
│   └── tests/
│
└── ~/.config/pr-review/config.json  # User configuration
```

## Build Commands

```bash
# Full test suite (Lua + Swift)
make test

# Build macOS app
make build-app
# or directly:
cd app && swift build -c release

# Install to ~/.local/bin
cp app/.build/release/PRReviewSystem ~/.local/bin/
```

## Key Design Decisions

### macOS App
- **Standalone executable**: Runs from `~/.local/bin/`, not a `.app` bundle
- **Lazy notification init**: UNUserNotificationCenter requires app bundle, so we skip it for standalone
- **Process-based Ghostty launch**: Uses `/Applications/Ghostty.app/Contents/MacOS/ghostty -e` directly
- **Token in URLs**: Private repos require `https://TOKEN@github.com/...` for cloning
- **Parallel fetching**: Uses `withTaskGroup` to fetch all repos simultaneously

### Neovim Plugin
- **Async operations**: Uses `vim.fn.jobstart` for git, `plenary.curl` for API
- **Buffer-local commands**: `:w` and `:q` overridden in comment popup
- **Diff hunks**: Groups consecutive changed lines for navigation

## Configuration

Config file: `~/.config/pr-review/config.json`

Required fields:
- `github_token` - GitHub personal access token
- `github_username` - Your GitHub username
- `repos` - Array of "owner/repo" strings to monitor

Optional:
- `clone_root` - Where to clone PRs (default: `~/.local/share/pr-review/repos`)
- `poll_interval_seconds` - Polling interval (default: 300)
- `ghostty_path` - Path to Ghostty.app
- `nvim_path` - Path to nvim executable
- `notifications.sound_path` - Custom sound file (or use `PR_REVIEW_SOUND_PATH` env var)

## Testing

```bash
# Run all tests
make test

# Neovim tests only (requires plenary.nvim)
make test-nvim

# Swift tests only
make test-app
# or:
cd app && swift test
```

## Common Issues

1. **App crashes on launch**: Check `/tmp/prreview.error.log`
2. **PRs not showing**: Verify token has `repo` scope
3. **Clone fails**: Token must be embedded in URL for private repos
4. **Ghostty doesn't open**: Ensure `/Applications/Ghostty.app` exists
