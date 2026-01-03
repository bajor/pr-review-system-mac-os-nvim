---@class PRReviewGit
---Git operations using vim.fn.jobstart for async execution
local M = {}

--- Run a git command asynchronously
---@param args string[] Git command arguments
---@param opts table Options: cwd, on_exit(code, stdout, stderr)
---@return number job_id
local function run_git(args, opts)
  local stdout_data = {}
  local stderr_data = {}

  local job_id = vim.fn.jobstart({ "git", unpack(args) }, {
    cwd = opts.cwd,
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stdout_data, line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stderr_data, line)
          end
        end
      end
    end,
    on_exit = function(_, code)
      if opts.on_exit then
        vim.schedule(function()
          opts.on_exit(code, stdout_data, stderr_data)
        end)
      end
    end,
  })

  return job_id
end

--- Clone a repository
---@param url string Repository URL
---@param path string Destination path
---@param branch string|nil Branch to checkout (optional)
---@param callback fun(success: boolean, err: string|nil)
function M.clone(url, path, branch, callback)
  -- Ensure parent directory exists
  local parent = vim.fn.fnamemodify(path, ":h")
  if vim.fn.isdirectory(parent) == 0 then
    vim.fn.mkdir(parent, "p")
  end

  local args = { "clone", "--depth", "1" }
  if branch then
    table.insert(args, "--branch")
    table.insert(args, branch)
  end
  table.insert(args, url)
  table.insert(args, path)

  run_git(args, {
    on_exit = function(code, _, stderr)
      if code == 0 then
        callback(true, nil)
      else
        local err_msg = table.concat(stderr, "\n")
        if err_msg == "" then
          err_msg = "Git clone failed with code " .. code
        end
        callback(false, err_msg)
      end
    end,
  })
end

--- Update the remote URL (useful for adding/updating auth tokens)
---@param path string Repository path
---@param url string New remote URL
---@param callback fun(success: boolean, err: string|nil)
function M.set_remote_url(path, url, callback)
  run_git({ "remote", "set-url", "origin", url }, {
    cwd = path,
    on_exit = function(code, _, stderr)
      if code == 0 then
        callback(true, nil)
      else
        local err_msg = table.concat(stderr, "\n")
        callback(false, err_msg)
      end
    end,
  })
end

--- Fetch and reset to a remote branch (hard reset to match remote)
---@param path string Repository path
---@param branch string Branch name
---@param url string|nil Optional: update remote URL before fetching (for auth)
---@param callback fun(success: boolean, err: string|nil)
function M.fetch_reset(path, branch, url, callback)
  -- Handle optional url parameter (backwards compatibility)
  if type(url) == "function" then
    callback = url
    url = nil
  end

  local function do_fetch()
    run_git({ "fetch", "origin", branch }, {
      cwd = path,
      on_exit = function(fetch_code, _, fetch_stderr)
        if fetch_code ~= 0 then
          local err_msg = table.concat(fetch_stderr, "\n")
          if err_msg == "" then
            err_msg = "Git fetch failed with code " .. fetch_code
          end
          callback(false, err_msg)
          return
        end

        -- Then checkout the branch
        run_git({ "checkout", branch }, {
          cwd = path,
          on_exit = function(checkout_code, _, _)
            if checkout_code ~= 0 then
              -- Branch might not exist locally, try creating it
              run_git({ "checkout", "-b", branch, "origin/" .. branch }, {
                cwd = path,
                on_exit = function(create_code, _, _)
                  if create_code ~= 0 then
                    -- Already exists, just reset
                    run_git({ "reset", "--hard", "origin/" .. branch }, {
                      cwd = path,
                      on_exit = function(reset_code, _, reset_stderr)
                        if reset_code == 0 then
                          callback(true, nil)
                        else
                          local err_msg = table.concat(reset_stderr, "\n")
                          callback(false, err_msg)
                        end
                      end,
                    })
                  else
                    callback(true, nil)
                  end
                end,
              })
            else
              -- Reset to remote
              run_git({ "reset", "--hard", "origin/" .. branch }, {
                cwd = path,
                on_exit = function(reset_code, _, reset_stderr)
                  if reset_code == 0 then
                    callback(true, nil)
                  else
                    local err_msg = table.concat(reset_stderr, "\n")
                    callback(false, err_msg)
                  end
                end,
              })
            end
          end,
        })
      end,
    })
  end

  -- Update remote URL first if provided (to include auth token)
  if url then
    M.set_remote_url(path, url, function(success, err)
      if not success then
        -- Non-fatal, try fetching anyway
        vim.schedule(function()
          vim.notify("Warning: Could not update remote URL: " .. (err or ""), vim.log.levels.WARN)
        end)
      end
      do_fetch()
    end)
  else
    do_fetch()
  end
end

--- Get the current branch name
---@param path string Repository path
---@param callback fun(branch: string|nil, err: string|nil)
function M.get_current_branch(path, callback)
  run_git({ "rev-parse", "--abbrev-ref", "HEAD" }, {
    cwd = path,
    on_exit = function(code, stdout, stderr)
      if code == 0 and #stdout > 0 then
        callback(stdout[1], nil)
      else
        local err_msg = table.concat(stderr, "\n")
        if err_msg == "" then
          err_msg = "Failed to get current branch"
        end
        callback(nil, err_msg)
      end
    end,
  })
end

--- Get the current commit SHA
---@param path string Repository path
---@param callback fun(sha: string|nil, err: string|nil)
function M.get_current_sha(path, callback)
  run_git({ "rev-parse", "HEAD" }, {
    cwd = path,
    on_exit = function(code, stdout, stderr)
      if code == 0 and #stdout > 0 then
        callback(stdout[1], nil)
      else
        local err_msg = table.concat(stderr, "\n")
        if err_msg == "" then
          err_msg = "Failed to get current SHA"
        end
        callback(nil, err_msg)
      end
    end,
  })
end

--- Check if a path is a git repository
---@param path string Path to check
---@return boolean
function M.is_git_repo(path)
  local git_dir = path .. "/.git"
  return vim.fn.isdirectory(git_dir) == 1
end

--- Get the remote URL for a repository
---@param path string Repository path
---@param callback fun(url: string|nil, err: string|nil)
function M.get_remote_url(path, callback)
  run_git({ "remote", "get-url", "origin" }, {
    cwd = path,
    on_exit = function(code, stdout, stderr)
      if code == 0 and #stdout > 0 then
        callback(stdout[1], nil)
      else
        local err_msg = table.concat(stderr, "\n")
        if err_msg == "" then
          err_msg = "Failed to get remote URL"
        end
        callback(nil, err_msg)
      end
    end,
  })
end

--- Build the clone path for a PR
---@param clone_root string Root directory for clones
---@param owner string Repository owner
---@param repo string Repository name
---@param pr_number number PR number
---@return string
function M.build_pr_path(clone_root, owner, repo, pr_number)
  return string.format("%s/%s/%s/pr-%d", clone_root, owner, repo, pr_number)
end

return M
