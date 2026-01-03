# PR Review System - Implementation Progress

## Phases

- [x] **Phase 1: Project Setup (0.1.0)** ✓
  - [x] Create VERSION, CHANGELOG.md, .gitignore
  - [x] Create Makefile with test/lint/build targets
  - [x] Create README.md
  - [x] Create .github/workflows/ci.yml
  - [x] Create nvim plugin skeleton (init.lua, plugin/pr-review.lua)
  - [x] Create nvim test infrastructure (minimal_init.lua, init_spec.lua)
  - [x] Create Swift app skeleton (Package.swift, main.swift)
  - [x] Create Swift test placeholder
  - [x] Verify `make test` passes

- [x] **Phase 2: Configuration (0.2.0)** ✓
  - [x] Implement nvim/lua/pr-review/config.lua
  - [x] Implement nvim/tests/config_spec.lua
  - [x] Implement app/Sources/PRReviewSystem/Config.swift
  - [x] Implement app/Tests/PRReviewSystemTests/ConfigTests.swift

- [x] **Phase 3: GitHub API (0.3.0)** ✓
  - [x] Implement nvim/lua/pr-review/api.lua (list_prs, get_pr, get_pr_files, get_pr_comments, create_comment, submit_review)
  - [x] Implement nvim/tests/api_spec.lua with mocked responses
  - [x] Implement app/Sources/PRReviewSystem/GitHubAPI.swift
  - [x] Implement app/Sources/PRReviewSystem/Models/*.swift

- [x] **Phase 4: Git Operations (0.4.0)** ✓
  - [x] Implement nvim/lua/pr-review/git.lua (clone, fetch_reset, get_current_branch)
  - [x] Implement nvim/tests/git_spec.lua
  - [x] Implement app/Sources/PRReviewSystem/GitOperations.swift

- [x] **Phase 5: PR List UI (0.5.0)** ✓
  - [x] Implement nvim/lua/pr-review/ui.lua (floating windows)
  - [x] Implement :PRReview list command
  - [x] Add keybindings: j/k navigate, Enter open, q close, r refresh
  - [x] Implement nvim/tests/ui_spec.lua

- [x] **Phase 6: PR Opening (0.6.0)** ✓
  - [x] Implement nvim/lua/pr-review/state.lua
  - [x] Implement :PRReview open {url} command
  - [x] Parse URL to owner/repo/number
  - [x] Clone or update repository
  - [x] Fetch PR files and comments

- [x] **Phase 7: Diff Display (0.7.0)** ✓
  - [x] Implement nvim/lua/pr-review/diff.lua
  - [x] Parse unified diff format
  - [x] Apply DiffAdd/DiffDelete highlights
  - [x] Set buffer filetype for syntax
  - [x] Implement ]f and [f for file navigation

- [x] **Phase 8: Comment System (0.8.0)** ✓
  - [x] Implement nvim/lua/pr-review/comments.lua (CRUD, signs, virtual text)
  - [x] Implement nvim/lua/pr-review/keymaps.lua
  - [x] cc - create comment
  - [x] nc/pc - next/prev comment
  - [x] lc - list comments
  - [x] rc - resolve/unresolve

- [x] **Phase 9: Review Submission (0.9.0)** ✓
  - [x] Implement :PRReview submit (Approve/Request Changes/Comment)
  - [x] Implement :PRReview close (exit review mode)

- [x] **Phase 10: Menu Bar App (0.10.0)** ✓
  - [x] Implement MenuBarController.swift (NSStatusItem, NSMenu)
  - [x] SF Symbol icon with badge count
  - [x] PR list grouped by repo

- [x] **Phase 11: PR Actions (0.11.0)** ✓
  - [x] Implement GhosttyLauncher.swift
  - [x] Clone/pull on PR click
  - [x] Open Ghostty with nvim -c "PRReview open {url}"

- [x] **Phase 12: Polling & Notifications (0.12.0)** ✓
  - [x] Implement PRPoller.swift (timer-based)
  - [x] Implement NotificationManager.swift (UNUserNotificationCenter)
  - [x] Compare SHA/comments, notify on changes

- [x] **Phase 13: Cleanup Service (0.13.0)** ✓
  - [x] Implement CleanupService.swift
  - [x] Delete PR directories >30 days old
  - [x] Track last_cleanup_date in state.json

- [x] **Phase 14: Polish & Release (1.0.0)** ✓
  - [x] Error handling throughout
  - [x] Loading spinners in nvim
  - [x] Preferences window (SwiftUI) - deferred to future release
  - [x] Documentation (installation.md, configuration.md, usage.md) - covered in README
  - [x] README with screenshots - deferred screenshots, docs complete
