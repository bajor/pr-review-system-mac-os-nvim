# PR Review System - Implementation Specification

## Instructions for Claude Code

Build a complete PR code review system consisting of:
1. **macOS menu bar application** (Swift/SwiftUI)
2. **Neovim plugin** (Lua)

Both components live in a single monorepo and share configuration.

---

## Project Initialization

Create the following files first:

### VERSION
```
0.1.0
```

### CHANGELOG.md
```markdown
# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - YYYY-MM-DD

### Added
- Initial project structure
- Neovim plugin foundation
- macOS menu bar app foundation
```

### .gitignore
```gitignore
# macOS
.DS_Store
*.swp
*.swo
*~

# Xcode
app/build/
app/DerivedData/
app/*.xcodeproj/xcuserdata/
app/*.xcodeproj/project.xcworkspace/xcuserdata/
app/*.xcworkspace/xcuserdata/
*.pbxuser
*.mode1v3
*.mode2v3
*.perspectivev3
*.xccheckout
*.moved-aside
*.hmap
*.ipa
*.dSYM.zip
*.dSYM

# Swift Package Manager
.build/
Packages/
Package.resolved

# Neovim
*.log
.luarc.json

# Project specific
.env
config.local.json

# Test artifacts
coverage/
*.lcov
```

**Version Bump Rule**: Every time you complete a phase or add significant functionality, bump the patch version in VERSION and add an entry to CHANGELOG.md.

---

## Repository Structure

```
pr-review-system/
├── VERSION
├── CHANGELOG.md
├── README.md
├── LICENSE
├── Makefile
├── .gitignore
│
├── app/                              # macOS menu bar application
│   ├── PRReviewSystem/
│   │   ├── PRReviewSystemApp.swift   # @main entry point
│   │   ├── MenuBarController.swift   # menu bar UI and dropdown
│   │   ├── GitHubAPI.swift           # GitHub REST API client
│   │   ├── PRPoller.swift            # background polling service
│   │   ├── NotificationManager.swift # macOS notifications
│   │   ├── CleanupService.swift      # 30-day stale PR cleanup
│   │   ├── GhosttyLauncher.swift     # launch terminal + nvim
│   │   ├── GitOperations.swift       # clone, pull, status
│   │   ├── Config.swift              # config file handling
│   │   ├── Models/
│   │   │   ├── PullRequest.swift
│   │   │   ├── PRComment.swift
│   │   │   ├── PRFile.swift
│   │   │   └── Repository.swift
│   │   └── Assets.xcassets/
│   │       └── AppIcon.appiconset/
│   ├── PRReviewSystem.xcodeproj/
│   └── PRReviewSystemTests/
│
├── nvim/                             # Neovim plugin
│   ├── lua/
│   │   └── pr-review/
│   │       ├── init.lua              # setup(), public API
│   │       ├── config.lua            # configuration management
│   │       ├── api.lua               # GitHub API calls via plenary
│   │       ├── git.lua               # clone, pull, branch operations
│   │       ├── ui.lua                # floating windows, pickers
│   │       ├── diff.lua              # diff parsing and rendering
│   │       ├── comments.lua          # comment CRUD, virtual text
│   │       ├── keymaps.lua           # buffer-local keybindings
│   │       ├── state.lua             # current review session state
│   │       └── utils.lua             # shared utilities
│   └── plugin/
│       └── pr-review.lua             # auto-commands, command registration
│
└── docs/
    ├── installation.md
    ├── configuration.md
    └── usage.md
```

---

## Shared Configuration

### Location
`~/.config/pr-review/config.json`

### Schema
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
  "cleanup_after_days": 30,
  "ghostty_path": "/Applications/Ghostty.app",
  "nvim_path": "/opt/homebrew/bin/nvim",
  "notifications": {
    "new_commits": true,
    "new_comments": true,
    "sound": true
  }
}
```

### State File
`~/.local/share/pr-review/state.json`
```json
{
  "last_cleanup_date": "2026-01-03",
  "known_prs": {
    "owner/repo1/142": {
      "last_commit_sha": "abc123",
      "known_comment_ids": [1234, 1235, 1236]
    }
  }
}
```

### Clone Directory Structure
```
~/.local/share/pr-review/repos/
└── {owner}/
    └── {repo}/
        └── pr-{number}/      # full clone, checked out to PR branch
```

---

## Component 1: macOS Menu Bar App

### Requirements
- macOS 14.0+ (Sonoma)
- Swift 5.9+
- SwiftUI for menu bar

### Features

#### Menu Bar Icon
- Use SF Symbol `eye.circle.fill` or similar
- Show badge with count of PRs awaiting review
- Click opens dropdown menu

#### Dropdown Menu
```
┌────────────────────────────────────────┐
│ ● 3 PRs awaiting review                │
├────────────────────────────────────────┤
│ owner/repo1                            │
│   #142 Fix auth bug            2 days  │
│   #138 Add caching             5 days  │
│ owner/repo2                            │
│   #89 Refactor API             1 day   │
├────────────────────────────────────────┤
│ ⟳ Refresh Now                          │
│ ⚙ Preferences...                       │
│ ─────────────────────────────────────  │
│ Quit                                   │
└────────────────────────────────────────┘
```

#### PR Click Action
1. Compute clone path: `{clone_root}/{owner}/{repo}/pr-{number}`
2. If directory does not exist:
   - Run `git clone {repo_url} {path}`
   - Run `git checkout {pr_branch}`
3. If directory exists:
   - Run `git fetch origin`
   - Run `git reset --hard origin/{pr_branch}`
4. Launch Ghostty with:
   ```
   cd {path} && nvim -c "PRReview open {pr_url}"
   ```

#### Background Polling
- Poll GitHub API every `poll_interval_seconds`
- For each PR in configured repos:
  - Compare current head SHA against `state.json`
  - Compare comment IDs against known list
  - If new commit (not by `github_username`): trigger notification
  - If new comment (not by `github_username`): trigger notification
- Update `state.json` after each poll

#### Notification Format
```
┌─────────────────────────────────────────┐
│ 🔔 New commit on #142                   │
│ owner/repo1                             │
│                                         │
│ "Fix edge case in auth flow"            │
│ +12 -3 in 2 files                       │
└─────────────────────────────────────────┘
```

Clicking notification should open that PR in Ghostty/nvim.

#### Daily Cleanup
On app launch:
1. Read `last_cleanup_date` from `state.json`
2. If date is not today:
   - Scan all directories in `clone_root`
   - For each PR directory:
     - Check last modified time of `.git` directory
     - If >30 days old, delete entire PR directory
   - Update `last_cleanup_date` to today
   - Write `state.json`

---

## Component 2: Neovim Plugin

### Requirements
- Neovim 0.9+
- Dependency: `plenary.nvim` (for HTTP and async)

### Setup (lazy.nvim)
```lua
{
  dir = "~/path/to/pr-review-system/nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("pr-review").setup({})
  end
}
```

### Commands

| Command | Description |
|---------|-------------|
| `:PRReview list` | Open floating window listing all PRs |
| `:PRReview open {url}` | Clone/pull PR, enter review mode |
| `:PRReview comments` | Show all comments in current PR |
| `:PRReview submit` | Submit review (approve/request changes/comment) |
| `:PRReview close` | Exit review mode |

### Keybindings (buffer-local in review mode)

| Key | Action |
|-----|--------|
| `cc` | Create comment on current line |
| `nc` | Jump to next unresolved comment |
| `pc` | Jump to previous unresolved comment |
| `lc` | Open comment list (j/k navigate, Enter jump) |
| `rc` | Resolve/unresolve comment under cursor |
| `]f` | Next file in PR |
| `[f` | Previous file in PR |
| `q` | Close review mode |

### Diff Display

#### Highlighting
- Additions: apply `DiffAdd` highlight (green background)
- Deletions: apply `DiffDelete` highlight (red background)
- Unchanged: normal syntax highlighting based on filetype

#### Comment Indicators
- Sign column: `💬` icon for lines with comments
- Virtual text (right aligned, dimmed): `-- 2 comments`
- Unresolved comments: yellow/orange sign
- Resolved comments: green/dimmed sign

### PR List UI (`:PRReview list`)
```
┌─────────────────────────────────────────────────────────────┐
│ PR Review - Open Pull Requests                      [?] help│
├─────────────────────────────────────────────────────────────┤
│ > #142 Fix authentication bug                    owner/repo1│
│   #138 Add Redis caching layer                   owner/repo1│
│   #89  Refactor API endpoints                    owner/repo2│
├─────────────────────────────────────────────────────────────┤
│ Enter: open | q: close | r: refresh                         │
└─────────────────────────────────────────────────────────────┘
```

Navigation: `j`/`k` to move, `Enter` to open, `q` to close, `r` to refresh.

### Comment List UI (`lc`)
```
┌─────────────────────────────────────────────────────────────┐
│ Comments (3 unresolved, 5 total)                            │
├─────────────────────────────────────────────────────────────┤
│ ● src/auth.rs:42        "Should we handle timeout here?"    │
│ ● src/auth.rs:87        "Missing error propagation"         │
│ ○ src/cache.rs:15       "Resolved: Added TTL"               │
│ ● src/api.rs:203        "Consider async here"               │
├─────────────────────────────────────────────────────────────┤
│ j/k: navigate | Enter: jump | r: resolve | q: close         │
└─────────────────────────────────────────────────────────────┘
```

`●` = unresolved, `○` = resolved

### Comment Creation (`cc`)
1. User presses `cc` on a diff line
2. Floating input opens:
```
┌─ New Comment ─────────────────────────────┐
│                                           │
│                                           │
├───────────────────────────────────────────┤
│ Ctrl+Enter: submit | Esc: cancel          │
└───────────────────────────────────────────┘
```
3. On Ctrl+Enter: POST to GitHub, update state, show virtual text

### Review Submission (`:PRReview submit`)
```
┌─ Submit Review ───────────────────────────┐
│                                           │
│  [1] Comment                              │
│  [2] Approve                              │
│  [3] Request Changes                      │
│                                           │
│  Press 1, 2, or 3                         │
└───────────────────────────────────────────┘
```

After selection, optionally prompt for review body, then POST to GitHub.

---

## GitHub API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/repos/{owner}/{repo}/pulls` | GET | List open PRs |
| `/repos/{owner}/{repo}/pulls/{number}` | GET | PR details (head SHA, branch) |
| `/repos/{owner}/{repo}/pulls/{number}/files` | GET | Files changed in PR |
| `/repos/{owner}/{repo}/pulls/{number}/comments` | GET | Review comments |
| `/repos/{owner}/{repo}/pulls/{number}/comments` | POST | Create comment |
| `/repos/{owner}/{repo}/pulls/{number}/reviews` | POST | Submit review |
| `/repos/{owner}/{repo}/pulls/comments/{id}` | PATCH | Update comment |

All requests require header: `Authorization: Bearer {github_token}`

Handle pagination: check `Link` header, fetch all pages.

---

## Implementation Phases

### Phase 1: Project Setup (bump to 0.1.0)
- [ ] Create repository with VERSION, CHANGELOG.md, .gitignore, README.md
- [ ] Create directory structure for app/ and nvim/
- [ ] Create Makefile with targets: `setup`, `build-app`, `install-nvim`, `clean`
- [ ] Initialize Xcode project skeleton
- [ ] Initialize nvim plugin skeleton with `init.lua`

### Phase 2: Configuration (bump to 0.2.0)
- [ ] Implement `nvim/lua/pr-review/config.lua`
  - [ ] Read JSON from `~/.config/pr-review/config.json`
  - [ ] Expand `~` paths
  - [ ] Validate required fields
  - [ ] Provide sensible defaults
- [ ] Implement `app/PRReviewSystem/Config.swift`
  - [ ] Same logic, Swift version
  - [ ] FileManager for paths

### Phase 3: GitHub API (bump to 0.3.0)
- [ ] Implement `nvim/lua/pr-review/api.lua`
  - [ ] `api.list_prs(owner, repo, callback)`
  - [ ] `api.get_pr(owner, repo, number, callback)`
  - [ ] `api.get_pr_files(owner, repo, number, callback)`
  - [ ] `api.get_pr_comments(owner, repo, number, callback)`
  - [ ] `api.create_comment(owner, repo, number, file, line, body, callback)`
  - [ ] `api.submit_review(owner, repo, number, event, body, callback)`
  - [ ] Use `plenary.curl` for requests
- [ ] Implement `app/PRReviewSystem/GitHubAPI.swift`
  - [ ] Same endpoints, async/await with URLSession

### Phase 4: Git Operations (bump to 0.4.0)
- [ ] Implement `nvim/lua/pr-review/git.lua`
  - [ ] `git.clone(url, path, branch, callback)`
  - [ ] `git.fetch_reset(path, branch, callback)`
  - [ ] `git.get_current_branch(path)`
  - [ ] Use `vim.fn.jobstart` for async
- [ ] Implement `app/PRReviewSystem/GitOperations.swift`
  - [ ] Same operations via Process

### Phase 5: Neovim PR List (bump to 0.5.0)
- [ ] Implement `nvim/lua/pr-review/ui.lua`
  - [ ] `ui.create_floating_window(opts)`
  - [ ] `ui.pr_list()` - fetch and display PRs
- [ ] Implement `:PRReview list` command
- [ ] Add keybindings: j/k navigation, Enter to select, q to close, r to refresh

### Phase 6: Neovim PR Opening (bump to 0.6.0)
- [ ] Implement `nvim/lua/pr-review/state.lua`
  - [ ] Track current PR, files, active file index
- [ ] Implement `:PRReview open {url}`
  - [ ] Parse URL → owner/repo/number
  - [ ] Clone or update repo
  - [ ] Fetch PR files and comments
  - [ ] Open first file in diff view

### Phase 7: Diff Display (bump to 0.7.0)
- [ ] Implement `nvim/lua/pr-review/diff.lua`
  - [ ] `diff.fetch(owner, repo, number, callback)` - get unified diff
  - [ ] `diff.parse(diff_text)` - parse hunks
  - [ ] `diff.render(bufnr, parsed)` - apply highlights
- [ ] Set buffer filetype based on file extension for syntax
- [ ] File navigation: `]f` and `[f`

### Phase 8: Comment System (bump to 0.8.0)
- [ ] Implement `nvim/lua/pr-review/comments.lua`
  - [ ] `comments.fetch(pr)` - load from API
  - [ ] `comments.render(bufnr)` - signs + virtual text
  - [ ] `comments.create(file, line)` - open input, POST on submit
  - [ ] `comments.navigate_next()` / `comments.navigate_prev()`
  - [ ] `comments.list()` - show picker
  - [ ] `comments.toggle_resolved(comment_id)`
- [ ] Implement keybindings: cc, nc, pc, lc, rc

### Phase 9: Review Submission (bump to 0.9.0)
- [ ] Implement `:PRReview submit`
  - [ ] Show selection UI
  - [ ] Optional body input
  - [ ] POST review to GitHub
- [ ] Implement `:PRReview close`
  - [ ] Clean up buffers
  - [ ] Clear state

### Phase 10: macOS App Menu Bar (bump to 0.10.0)
- [ ] Implement `MenuBarController.swift`
  - [ ] NSStatusItem with SF Symbol icon
  - [ ] NSMenu construction
  - [ ] PR count badge
- [ ] Implement `PRReviewSystemApp.swift`
  - [ ] App delegate setup
  - [ ] Launch at login option

### Phase 11: macOS App PR Actions (bump to 0.11.0)
- [ ] Implement `GhosttyLauncher.swift`
  - [ ] Build clone/pull command
  - [ ] Launch Ghostty via NSWorkspace or AppleScript
  - [ ] Pass nvim command with `:PRReview open`
- [ ] Wire menu item clicks to launcher

### Phase 12: Polling & Notifications (bump to 0.12.0)
- [ ] Implement `PRPoller.swift`
  - [ ] Timer-based polling
  - [ ] Compare SHAs and comment IDs
  - [ ] Track state in state.json
- [ ] Implement `NotificationManager.swift`
  - [ ] UNUserNotificationCenter setup
  - [ ] Rich notifications with preview
  - [ ] Click action opens PR

### Phase 13: Cleanup Service (bump to 0.13.0)
- [ ] Implement `CleanupService.swift`
  - [ ] Run on app launch
  - [ ] Check last_cleanup_date
  - [ ] Scan and delete old directories
  - [ ] Update state.json

### Phase 14: Polish & Release (bump to 1.0.0)
- [ ] Error handling throughout (network, git, invalid config)
- [ ] Loading indicators in nvim (spinners)
- [ ] Preferences window in app (SwiftUI)
- [ ] Documentation: installation.md, configuration.md, usage.md
- [ ] README with screenshots/GIF

---

## Error Handling

| Error | Response |
|-------|----------|
| Config file missing | Create default, show message to edit |
| Invalid GitHub token | Error message with link to token creation |
| Repo not found | Skip, warn, continue with other repos |
| Network timeout | Retry 3x with exponential backoff |
| Git clone fails | Show error, suggest manual clone |
| Rate limited | Show warning, pause polling |

---

## Makefile

```makefile
.PHONY: setup build-app install-nvim clean bump-version

VERSION := $(shell cat VERSION)

setup:
	mkdir -p ~/.config/pr-review
	mkdir -p ~/.local/share/pr-review/repos
	@echo "Created config directories"

build-app:
	cd app && xcodebuild -scheme PRReviewSystem -configuration Release build

install-nvim:
	@echo "Add to your nvim config:"
	@echo '{ dir = "$(PWD)/nvim", dependencies = { "nvim-lua/plenary.nvim" } }'

clean:
	cd app && xcodebuild clean
	rm -rf app/build app/DerivedData

bump-version:
	@echo "Current version: $(VERSION)"
	@read -p "New version: " NEW_VERSION && \
		echo "$$NEW_VERSION" > VERSION && \
		echo "Bumped to $$NEW_VERSION"
```

---

## Testing Notes

### Neovim Plugin
- Test with `plenary.busted` test framework
- Mock API responses for unit tests
- Test against real GitHub repo for integration

### macOS App
- XCTest for models and services
- Mock URLSession for API tests
- Manual test Ghostty integration

---

## Usage Example

1. User configures `~/.config/pr-review/config.json` with token and repos
2. User launches PR Review System app → appears in menu bar
3. Menu bar shows "3" badge (3 PRs to review)
4. User clicks menu → sees list grouped by repo
5. User clicks "#142 Fix auth bug"
6. App clones repo, opens Ghostty, runs `nvim -c "PRReview open https://..."`
7. Neovim shows diff with green/red highlighting
8. User presses `nc` → jumps to first comment
9. User presses `cc` → types reply → Ctrl+Enter to submit
10. User presses `:PRReview submit` → selects "Approve"
11. Done. PR approved.
12. 30 days later, cleanup removes the PR directory automatically.
