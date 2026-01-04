# PR Review System

A complete PR code review system for GitHub, consisting of:

1. **macOS menu bar app** - Polls GitHub for PRs, shows notifications, launches review sessions
2. **Neovim plugin** - Full PR review experience with diff viewing, comments, and submissions

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
  "github_token": "ghp_xxxxxxxxxxxxxxxxxxxx",
  "github_username": "your-username",
  "repos": [
    "owner/repo1",
    "owner/repo2"
  ],
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
- **Refresh** - Manually refresh PR list
- **Quit** - Exit the app

**Ghostty Behavior:**
- If Ghostty is already running → PR opens in a **new tab** (Cmd+T)
- If Ghostty is not running → Ghostty launches and **maximizes** (Cmd+Shift+F)

**Note:** The app runs as a proper `.app` bundle from `/Applications`, enabling full system notification support.

### Neovim Commands

| Command | Description |
|---------|-------------|
| `:PRReview list` | Open floating window listing all PRs |
| `:PRReview open {url}` | Clone/pull PR, enter review mode |
| `:PRReview comments` | Show all comments in current PR |
| `:PRReview submit` | Submit review (approve/request changes/comment) |
| `:PRReview sync` | Force sync PR with remote (fetch latest commits) |
| `:PRReview update` | Alias for sync |
| `:PRReview refresh` | Alias for sync |
| `:PRReview close` | Exit review mode |
| `:PRReview config` | Open config file for editing |

**Auto-sync:** When a PR is open, it automatically syncs every 5 minutes to fetch new commits and comments.

### PR List Window

When viewing the PR list (`:PRReview list`):

| Key | Action |
|-----|--------|
| `j` / `k` | Navigate up/down |
| `Enter` | Open selected PR |
| `r` | Refresh list |
| `q` / `Esc` | Close window |

### Review Mode Keybindings

> **Note:** `<leader>` is your Neovim leader key (default: `\`, commonly remapped to `<Space>`).

**File Navigation:**

| Key | Action |
|-----|--------|
| `]f` | Next file in PR |
| `[f` | Previous file in PR |

**Diff Navigation (within file):**

| Key | Action |
|-----|--------|
| `<leader>nd` | Next diff change |
| `<leader>pd` | Previous diff change |

**Comments:**

| Key | Action |
|-----|--------|
| `cc` | Open comment thread (view/edit/add comments) |
| `<leader>cc` | Quick new comment popup |
| `<leader>nc` | Jump to next comment |
| `<leader>pc` | Jump to previous comment |
| `<leader>lc` | Open comment list |
| `<leader>rc` | Resolve/unresolve comment |

**Comment Thread View (`cc`):**

Opens a floating window showing all comments on the current line:
- Each comment shows author and content
- Edit existing comments by modifying their text
- Add new comments in the blank section at the bottom
- Press `s` to save changes (update or create)
- Press `q` or `Esc` to close

**Quick Comment Popup (`<leader>cc`):**
- Type your comment
- Press `Esc` to exit insert mode
- Press `s` to save and submit to GitHub
- Press `q` to cancel

**Review Submission:**

| Key | Action |
|-----|--------|
| `<leader>rs` | Submit review (opens dialog) |
| `<leader>ra` | Quick approve |
| `<leader>ri` | Show review info/status |

**Exit:**

| Key | Action |
|-----|--------|
| `q` | Close review mode |

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
