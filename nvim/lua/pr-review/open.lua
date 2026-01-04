---@class PRReviewOpen
---PR opening functionality
local M = {}

local api = require("pr-review.api")
local comments = require("pr-review.comments")
local config = require("pr-review.config")
local diff = require("pr-review.diff")
local git = require("pr-review.git")
local keymaps = require("pr-review.keymaps")
local state = require("pr-review.state")

--- Sync timer (runs every 5 minutes)
local sync_timer = nil
local SYNC_INTERVAL_MS = 5 * 60 * 1000 -- 5 minutes

--- Last known commit SHA (to detect changes)
local last_known_sha = nil

--- Show a loading notification
---@param msg string
local function notify_loading(msg)
  vim.notify(msg, vim.log.levels.INFO)
end

--- Show an error notification
---@param msg string
local function notify_error(msg)
  vim.notify(msg, vim.log.levels.ERROR)
end

--- Show a success notification
---@param msg string
local function notify_success(msg)
  vim.notify(msg, vim.log.levels.INFO)
end

--- Open the first file in the PR with diff highlighting
local function open_first_file()
  local file = state.get_current_file()
  if not file then
    notify_error("No files in this PR")
    return
  end

  -- Setup all PR review keymaps
  keymaps.setup()

  -- Open file with diff highlighting
  local buf = diff.open_file(file)
  if buf then
    -- Show any existing comments
    local file_comments = state.get_comments(file.filename)
    if #file_comments > 0 then
      comments.show_comments(buf, file_comments)
    end
    notify_success(string.format("Opened %s (1/%d files) - Use ]f/[f to navigate", file.filename, #state.get_files()))
  end
end

--- Fetch PR data and files
---@param owner string
---@param repo string
---@param number number
---@param token string
---@param callback fun(err: string|nil)
local function fetch_pr_data(owner, repo, number, token, callback)
  notify_loading("Fetching PR data...")

  -- Fetch PR details
  api.get_pr(owner, repo, number, token, function(pr, pr_err)
    if pr_err then
      callback(pr_err)
      return
    end

    state.set_pr(pr)

    -- Fetch files
    api.get_pr_files(owner, repo, number, token, function(files, files_err)
      if files_err then
        callback(files_err)
        return
      end

      state.set_files(files)

      -- Fetch review comments (line-level)
      api.get_pr_comments(owner, repo, number, token, function(comments, comments_err)
        if comments_err then
          vim.notify("Warning: Could not fetch review comments: " .. comments_err, vim.log.levels.WARN)
        else
          -- Index comments by file path
          for _, comment in ipairs(comments or {}) do
            if comment.path then
              local file_comments = state.get_comments(comment.path)
              table.insert(file_comments, comment)
              state.set_comments(comment.path, file_comments)
            end
          end
        end

        -- Also fetch issue comments (general PR comments)
        api.get_issue_comments(owner, repo, number, token, function(issue_comments, issue_err)
          if issue_err then
            vim.notify("Warning: Could not fetch issue comments: " .. issue_err, vim.log.levels.WARN)
          else
            -- Parse issue comments that have file:line references in body
            -- Format: **`file:line`**\n\ncomment body
            for _, comment in ipairs(issue_comments or {}) do
              local body = comment.body or ""
              local file_path, line_num = body:match("^%*%*`([^:]+):(%d+)`%*%*")
              if file_path and line_num then
                -- Extract actual comment body (after the file reference)
                local actual_body = body:gsub("^%*%*`[^`]+`%*%*\n*", "")
                local parsed_comment = {
                  id = comment.id,
                  body = actual_body,
                  path = file_path,
                  line = tonumber(line_num),
                  user = comment.user,
                  created_at = comment.created_at,
                  updated_at = comment.updated_at,
                  issue_comment = true, -- Mark as issue comment
                }
                local file_comments = state.get_comments(file_path)
                table.insert(file_comments, parsed_comment)
                state.set_comments(file_path, file_comments)
              end
            end
          end

          callback(nil)
        end)
      end)
    end)
  end)
end

--- Stop the sync timer
local function stop_sync_timer()
  if sync_timer then
    sync_timer:stop()
    sync_timer:close()
    sync_timer = nil
  end
end

--- Sync the PR with remote (fetch latest, update files/comments)
---@param silent boolean If true, don't show notifications unless something changed
local function sync_pr(silent)
  if not state.is_active() then
    return
  end

  local cfg, cfg_err = config.load()
  if cfg_err then
    if not silent then
      notify_error("Config error: " .. cfg_err)
    end
    return
  end

  local owner = state.get_owner()
  local repo = state.get_repo()
  local number = state.get_number()
  local clone_path = state.get_clone_path()
  local pr = state.get_pr()

  if not owner or not repo or not number or not clone_path or not pr then
    return
  end

  local branch = pr.head.ref
  local repo_url = string.format("https://%s@github.com/%s/%s.git", cfg.github_token, owner, repo)

  -- Check remote for updates first
  api.get_pr(owner, repo, number, cfg.github_token, function(new_pr, pr_err)
    if pr_err then
      if not silent then
        notify_error("Sync failed: " .. pr_err)
      end
      return
    end

    -- Check if SHA changed
    local new_sha = new_pr.head.sha
    if new_sha == last_known_sha then
      -- No changes
      if not silent then
        vim.notify("PR is up to date", vim.log.levels.INFO)
      end
      return
    end

    -- SHA changed, do full sync
    if not silent then
      notify_loading("Syncing PR (new commits detected)...")
    end

    -- Update local repo
    git.fetch_reset(clone_path, branch, repo_url, function(success, err)
      if not success then
        notify_error("Sync failed: " .. (err or "git error"))
        return
      end

      -- Update PR data
      state.set_pr(new_pr)
      last_known_sha = new_sha

      -- Re-fetch files
      api.get_pr_files(owner, repo, number, cfg.github_token, function(files, files_err)
        if files_err then
          notify_error("Failed to fetch files: " .. files_err)
          return
        end

        state.set_files(files)

        -- Clear comments for all files first
        for _, file in ipairs(files) do
          state.set_comments(file.filename, {})
        end

        -- Re-fetch review comments
        api.get_pr_comments(owner, repo, number, cfg.github_token, function(new_comments, comments_err)
          if not comments_err then
            for _, comment in ipairs(new_comments or {}) do
              if comment.path then
                local file_comments = state.get_comments(comment.path)
                table.insert(file_comments, comment)
                state.set_comments(comment.path, file_comments)
              end
            end
          end

          -- Also fetch issue comments
          api.get_issue_comments(owner, repo, number, cfg.github_token, function(issue_comments, issue_err)
            if not issue_err then
              for _, comment in ipairs(issue_comments or {}) do
                local body = comment.body or ""
                local file_path, line_num = body:match("^%*%*`([^:]+):(%d+)`%*%*")
                if file_path and line_num then
                  local actual_body = body:gsub("^%*%*`[^`]+`%*%*\n*", "")
                  local parsed_comment = {
                    id = comment.id,
                    body = actual_body,
                    path = file_path,
                    line = tonumber(line_num),
                    user = comment.user,
                    created_at = comment.created_at,
                    updated_at = comment.updated_at,
                    issue_comment = true,
                  }
                  local file_comments = state.get_comments(file_path)
                  table.insert(file_comments, parsed_comment)
                  state.set_comments(file_path, file_comments)
                end
              end
            end

            -- Refresh current file display
            local current_file = state.get_current_file()
            if current_file then
              local buf = vim.api.nvim_get_current_buf()
              diff.apply_highlights(buf, current_file.patch)
              comments.show_comments(buf, state.get_comments(current_file.filename))
            end

            vim.notify("PR synced - new commits loaded", vim.log.levels.INFO)
          end)
        end)
      end)
    end)
  end)
end

--- Start the periodic sync timer
local function start_sync_timer()
  stop_sync_timer()

  sync_timer = vim.uv.new_timer()
  sync_timer:start(SYNC_INTERVAL_MS, SYNC_INTERVAL_MS, vim.schedule_wrap(function()
    sync_pr(true) -- silent sync
  end))
end

--- Manual sync command
function M.sync()
  sync_pr(false)
end

--- Clone or update the repository
---@param clone_path string
---@param repo_url string
---@param branch string
---@param callback fun(err: string|nil)
local function prepare_repo(clone_path, repo_url, branch, callback)
  if git.is_git_repo(clone_path) then
    notify_loading("Updating repository...")
    -- Pass URL to update remote with auth token
    git.fetch_reset(clone_path, branch, repo_url, function(success, err)
      if success then
        callback(nil)
      else
        callback(err or "Failed to update repository")
      end
    end)
  else
    notify_loading("Cloning repository...")
    git.clone(repo_url, clone_path, branch, function(success, err)
      if success then
        callback(nil)
      else
        callback(err or "Failed to clone repository")
      end
    end)
  end
end

--- Open a PR for review
---@param url string GitHub PR URL
function M.open_pr(url)
  -- Parse URL
  local owner, repo, number = api.parse_pr_url(url)
  if not owner or not repo or not number then
    notify_error("Invalid PR URL: " .. url)
    return
  end

  -- Load config
  local cfg, cfg_err = config.load()
  if cfg_err then
    notify_error("Config error: " .. cfg_err)
    return
  end

  -- Build clone path
  local clone_path = git.build_pr_path(cfg.clone_root, owner, repo, number)

  -- Start session
  state.start({
    owner = owner,
    repo = repo,
    number = number,
    url = url,
    clone_path = clone_path,
  })

  notify_loading(string.format("Opening PR #%d from %s/%s...", number, owner, repo))

  -- First, fetch PR data to get the branch name
  api.get_pr(owner, repo, number, cfg.github_token, function(pr, pr_err)
    if pr_err then
      notify_error("Failed to fetch PR: " .. pr_err)
      state.reset()
      return
    end

    state.set_pr(pr)

    local branch = pr.head.ref
    -- Use token in URL for HTTPS authentication
    local repo_url = string.format("https://%s@github.com/%s/%s.git", cfg.github_token, owner, repo)

    -- Clone or update the repo
    prepare_repo(clone_path, repo_url, branch, function(repo_err)
      if repo_err then
        notify_error("Repository error: " .. repo_err)
        state.reset()
        return
      end

      -- Fetch files and comments
      fetch_pr_data(owner, repo, number, cfg.github_token, function(data_err)
        if data_err then
          notify_error("Failed to fetch PR data: " .. data_err)
          state.reset()
          return
        end

        -- Change to clone directory
        vim.cmd("cd " .. vim.fn.fnameescape(clone_path))

        -- Store initial SHA for change detection
        last_known_sha = pr.head.sha

        -- Start periodic sync timer (every 5 mins)
        start_sync_timer()

        -- Open the first file
        open_first_file()

        notify_success(string.format(
          "PR #%d: %s (%d files) - auto-sync enabled",
          number,
          pr.title:sub(1, 40),
          #state.get_files()
        ))
      end)
    end)
  end)
end

--- Close the current PR review session
function M.close_pr()
  if not state.is_active() then
    vim.notify("No active PR review session", vim.log.levels.WARN)
    return
  end

  -- Stop sync timer
  stop_sync_timer()
  last_known_sha = nil

  -- Clear all PR review keymaps
  keymaps.clear()

  state.stop()
  vim.notify("PR review session closed", vim.log.levels.INFO)
end

return M
