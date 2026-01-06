# PR Review System

A complete PR code review system for GitHub, consisting of:

1. **macOS menu bar app** - Polls GitHub for PRs, shows notifications, launches review sessions
2. **Neovim plugin** - Full PR review experience with diff viewing, comments, and submissions

## Quick Reference

| Key | Action |
|-----|--------|
| `nn` / `pp` | Next/previous diff or comment |
| `nt` / `pt` | Next/previous comment thread |
| `cc` | Open/create comment at cursor |
| `<leader>ll` | List all PR comments |
| `<leader>rr` | Merge PR (pick method) |
| `s` | Save comment |
| `r` | Resolve thread |
| `q` | Close window |

## Requirements

### Neovim Plugin
- Neovim 0.9+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

### macOS App
- macOS 14.0+ (Sonoma)
- Command Line Tools (`xcode-select --install`)
- [Ghostty](https://ghostty.org) terminal

## Installation

### Neovim Plugin (lazy.nvim)

```lua
{
  dir = "~/path/to/pr-review-system/nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("pr-review").setup({})
  end
}
```

### macOS App

```bash
# Build and install to /Applications
make install-app

# Or manually:
make build-app
cp -r app/.build/PRReview.app /Applications/

# Run it
open /Applications/PRReview.app

# Uninstall
make uninstall-app
```

## Configuration

Create `~/.config/pr-review/config.json`:

```json
{
  "github_token": "ghp_your_default_token",
  "github_username": "your-username",
  "tokens": {
    "my-org": "ghp_token_for_my_org",
    "another-org": "ghp_token_for_another_org"
  },
  "clone_root": "~/.local/share/pr-review/repos",
  "poll_interval_seconds": 300,
  "ghostty_path": "/Applications/Ghostty.app",
  "nvim_path": "/opt/homebrew/bin/nvim",
  "notifications": {
    "new_commits": true,
    "new_comments": true,
    "sound": true,
    "sound_path": "~/Music/pr-notification.mp3"
  }
}
```

**Token resolution:** When accessing a repo, the app checks if the owner/org exists in the `tokens` map. If found, that token is used; otherwise falls back to `github_token`.

**Auto-discovery:** If `repos` is not specified, the app auto-discovers all accessible repos from your tokens (archived repos are excluded).

### Notification Sound

You can set a custom notification sound in two ways:

1. **Config file**: Set `notifications.sound_path` to your audio file (mp3/wav/aiff)
2. **Environment variable**: Set `PR_REVIEW_SOUND_PATH` (takes precedence over config)

### Auto-Start on Login

The app can be configured to start automatically on login. A LaunchAgent is created at:
```
~/Library/LaunchAgents/com.prreview.system.plist
```

To enable/disable:
```bash
# Enable
launchctl load ~/Library/LaunchAgents/com.prreview.system.plist

# Disable
launchctl unload ~/Library/LaunchAgents/com.prreview.system.plist
```

## Usage

### macOS Menu Bar App

Once running, you'll see **"PR"** (or **"PR N"** where N is the count) in your menu bar.

**Menu Bar Features:**
- Shows all open PRs from configured repos
- Displays PR title and last commit message
- Click a PR to clone/update and open in Ghostty + Neovim
- **Issues section** - Shows all open issues from configured repos
  - Hover to see issue description
  - Click "Go to GitHub" to open issue in browser
- **Open All PRs** - Opens all PRs in separate Ghostty tabs
- **Refresh** - Manually refresh PR list
- **Quit** - Exit the app

**Ghostty Behavior:**
- If Ghostty is already running → PR opens in a **new tab** (Cmd+T)
- If Ghostty is not running → Ghostty launches and **maximizes** (Cmd+Shift+F)

**Note:** The app runs as a proper `.app` bundle from `/Applications`, enabling full system notification support.

### Neovim Commands

| Command | Description |
|---------|-------------|
| `:PRReview list` | Show all comments in current PR |
| `:PRReview description` | Show PR description in floating window |
| `:PRReview sync` | Force sync PR with remote (fetch latest) |
| `:PRReview merge` | Merge the PR (merge commit) |
| `:PRReview squash` | Squash and merge the PR |
| `:PRReview rebase` | Rebase and merge the PR |
| `:PRReview close` | Exit review mode |
| `:PRReview config` | Open config file for editing |

**Auto-sync:** When a PR is open, it automatically syncs every 5 minutes.

### Review Mode Keybindings

Only 6 shortcuts to remember:

| Key | Action |
|-----|--------|
| `nn` | Next diff or comment (across all files) |
| `pp` | Previous diff or comment (across all files) |
| `nt` | Next comment thread (across all files) |
| `pt` | Previous comment thread (across all files) |
| `cc` | Open/create comment at cursor |
| `<leader>dd` | Show PR description |

**Navigation (`nn` / `pp`):**
- Jumps to next/previous "point of interest" (diff hunk or comment)
- Automatically switches files when needed
- Wraps around at start/end of PR

**Thread Navigation (`nt` / `pt`):**
- Jumps to next/previous comment thread only (skips diffs)
- Useful for reviewing feedback without stopping at every change
- Wraps around at start/end of PR

**Comments (`cc`):**
- Opens floating window showing all comments on the current line
- If no comments exist, opens new comment editor
- Press `s` to save and submit to GitHub
- Press `r` to resolve/unresolve the thread
- Press `q` or `Esc` to close

## Development

```bash
# Run all tests and linting
make test

# Run only Neovim tests
make test-nvim

# Run only Swift tests
make test-app

# Build the macOS app
make build-app

# Clean build artifacts
make clean
```

## License

MIT
