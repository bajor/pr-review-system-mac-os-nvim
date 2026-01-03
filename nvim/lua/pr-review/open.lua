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

      -- Fetch comments
      api.get_pr_comments(owner, repo, number, token, function(comments, comments_err)
        if comments_err then
          -- Non-fatal, just log
          vim.notify("Warning: Could not fetch comments: " .. comments_err, vim.log.levels.WARN)
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

        callback(nil)
      end)
    end)
  end)
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

        -- Open the first file
        open_first_file()

        notify_success(string.format(
          "PR #%d: %s (%d files)",
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

  -- Clear all PR review keymaps
  keymaps.clear()

  state.stop()
  vim.notify("PR review session closed", vim.log.levels.INFO)
end

return M
