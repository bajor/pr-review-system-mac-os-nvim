---@class PRReviewComments
---Comment management and display
local M = {}

local api = require("pr-review.api")
local config = require("pr-review.config")
local state = require("pr-review.state")

--- Namespace for comment highlights and extmarks
local ns_id = vim.api.nvim_create_namespace("pr_review_comments")

--- Sign group for comments
local sign_group = "PRReviewComment"

--- Define signs for comments
local function setup_signs()
  vim.fn.sign_define("PRReviewComment", {
    text = "●",
    texthl = "DiagnosticInfo",
    numhl = "",
  })
  vim.fn.sign_define("PRReviewCommentResolved", {
    text = "✓",
    texthl = "DiagnosticOk",
    numhl = "",
  })
  vim.fn.sign_define("PRReviewCommentPending", {
    text = "○",
    texthl = "DiagnosticWarn",
    numhl = "",
  })
end

-- Initialize signs
setup_signs()

--- Get the current file path relative to clone root
---@return string|nil
local function get_current_file_path()
  local clone_path = state.get_clone_path()
  if not clone_path then
    return nil
  end

  local current_file = vim.fn.expand("%:p")
  if current_file:sub(1, #clone_path) == clone_path then
    return current_file:sub(#clone_path + 2) -- +2 to skip the trailing /
  end
  return nil
end

--- Show comments in the sign column and as virtual text
---@param buf number Buffer ID
---@param comments table[] Comments for this file
function M.show_comments(buf, comments)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  -- Clear existing comment displays
  M.clear_comments(buf)

  for _, comment in ipairs(comments or {}) do
    local line = comment.line or comment.original_line or comment.position
    if line and line > 0 then
      -- Place sign
      local sign_name = "PRReviewComment"
      if comment.resolved then
        sign_name = "PRReviewCommentResolved"
      elseif comment.pending then
        sign_name = "PRReviewCommentPending"
      end

      pcall(vim.fn.sign_place, 0, sign_group, sign_name, buf, { lnum = line, priority = 10 })

      -- Add virtual text preview
      local preview = comment.body or ""
      preview = preview:gsub("\n", " "):sub(1, 50)
      if #(comment.body or "") > 50 then
        preview = preview .. "..."
      end

      pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, line - 1, 0, {
        virt_text = { { "  💬 " .. preview, "Comment" } },
        virt_text_pos = "eol",
      })
    end
  end
end

--- Clear comment displays from a buffer
---@param buf number Buffer ID
function M.clear_comments(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.fn.sign_unplace(sign_group, { buffer = buf })
    vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
  end
end

--- Get comments for the current buffer
---@return table[] comments
function M.get_buffer_comments()
  local path = get_current_file_path()
  if not path then
    return {}
  end
  return state.get_comments(path)
end

--- Find the next comment after the current line
---@return table|nil comment
---@return number|nil line
function M.find_next_comment()
  local comments = M.get_buffer_comments()
  local current_line = vim.fn.line(".")

  local next_comment = nil
  local next_line = math.huge

  for _, comment in ipairs(comments) do
    local line = comment.line or comment.original_line or comment.position
    if line and line > current_line and line < next_line then
      next_comment = comment
      next_line = line
    end
  end

  if next_comment then
    return next_comment, next_line
  end
  return nil, nil
end

--- Find the previous comment before the current line
---@return table|nil comment
---@return number|nil line
function M.find_prev_comment()
  local comments = M.get_buffer_comments()
  local current_line = vim.fn.line(".")

  local prev_comment = nil
  local prev_line = 0

  for _, comment in ipairs(comments) do
    local line = comment.line or comment.original_line or comment.position
    if line and line < current_line and line > prev_line then
      prev_comment = comment
      prev_line = line
    end
  end

  if prev_comment then
    return prev_comment, prev_line
  end
  return nil, nil
end

--- Jump to next comment
---@return boolean success
function M.next_comment()
  local comment, line = M.find_next_comment()
  if comment and line then
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    M.show_comment_popup(comment)
    return true
  end
  vim.notify("No more comments below", vim.log.levels.INFO)
  return false
end

--- Jump to previous comment
---@return boolean success
function M.prev_comment()
  local comment, line = M.find_prev_comment()
  if comment and line then
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    M.show_comment_popup(comment)
    return true
  end
  vim.notify("No more comments above", vim.log.levels.INFO)
  return false
end

--- Show a comment in a floating window
---@param comment table Comment data
function M.show_comment_popup(comment)
  if not comment then
    return
  end

  local lines = {}
  table.insert(lines, "Author: " .. (comment.user and comment.user.login or "unknown"))
  table.insert(lines, "")

  -- Split body into lines
  for line in (comment.body or ""):gmatch("[^\n]+") do
    table.insert(lines, line)
  end

  -- Calculate window dimensions
  local max_width = 60
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, #line)
  end
  width = math.min(width + 2, max_width)
  local height = math.min(#lines, 15)

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

  -- Create floating window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Comment ",
    title_pos = "center",
  })

  -- Close on any key
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, noremap = true, silent = true })

  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, noremap = true, silent = true })
end

--- Create a new comment at the current line
function M.create_comment()
  if not state.is_active() then
    vim.notify("No active PR review session", vim.log.levels.WARN)
    return
  end

  local path = get_current_file_path()
  if not path then
    vim.notify("Not in a PR file", vim.log.levels.WARN)
    return
  end

  local line = vim.fn.line(".")

  -- Create input buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

  -- Create floating window for comment input
  local width = 60
  local height = 10
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " New Comment (:w save, :q cancel) ",
    title_pos = "center",
  })

  -- Start in insert mode
  vim.cmd("startinsert")

  -- Track if saved (to distinguish :q from :wq)
  local saved = false

  -- Save function
  local function save_comment()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local body = table.concat(lines, "\n")

    if body:match("^%s*$") then
      vim.notify("Empty comment, not saved", vim.log.levels.WARN)
      return false
    end

    -- Add to pending comments (will be submitted with review)
    local pending_comment = {
      path = path,
      line = line,
      body = body,
      pending = true,
      user = { login = "you" },
    }

    -- Add to state
    local comments = state.get_comments(path)
    table.insert(comments, pending_comment)
    state.set_comments(path, comments)

    saved = true
    vim.notify("Comment added (pending submission)", vim.log.levels.INFO)

    -- Refresh display
    M.show_comments(vim.api.nvim_get_current_buf(), state.get_comments(path))
    return true
  end

  -- Override :w to save comment
  vim.api.nvim_buf_create_user_command(buf, "w", function()
    if save_comment() then
      vim.api.nvim_win_close(win, true)
    end
  end, {})

  -- Override :wq to save and close
  vim.api.nvim_buf_create_user_command(buf, "wq", function()
    if save_comment() then
      vim.api.nvim_win_close(win, true)
    end
  end, {})

  -- Override :q to cancel (close without saving)
  vim.api.nvim_buf_create_user_command(buf, "q", function()
    if not saved then
      vim.notify("Comment cancelled", vim.log.levels.INFO)
    end
    vim.api.nvim_win_close(win, true)
  end, { bang = true })

  -- Also handle :q!
  vim.api.nvim_buf_create_user_command(buf, "q!", function()
    vim.notify("Comment cancelled", vim.log.levels.INFO)
    vim.api.nvim_win_close(win, true)
  end, {})
end

--- List all comments in the current file
function M.list_comments()
  local comments = M.get_buffer_comments()
  if #comments == 0 then
    vim.notify("No comments in this file", vim.log.levels.INFO)
    return
  end

  local lines = {}
  for i, comment in ipairs(comments) do
    local line = comment.line or comment.original_line or comment.position or 0
    local author = comment.user and comment.user.login or "unknown"
    local preview = (comment.body or ""):gsub("\n", " "):sub(1, 40)
    local status = comment.pending and " [pending]" or (comment.resolved and " [resolved]" or "")
    table.insert(lines, string.format("%d. L%d %s: %s%s", i, line, author, preview, status))
  end

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  -- Create floating window
  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(#lines + 2, 20)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = (vim.o.lines - height) / 2,
    col = (vim.o.columns - width) / 2,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Comments (" .. #comments .. ") ",
    title_pos = "center",
  })

  -- Jump to comment on Enter
  vim.keymap.set("n", "<CR>", function()
    local cursor_line = vim.fn.line(".")
    local comment = comments[cursor_line]
    if comment then
      vim.api.nvim_win_close(win, true)
      local target_line = comment.line or comment.original_line or comment.position
      if target_line then
        vim.api.nvim_win_set_cursor(0, { target_line, 0 })
        M.show_comment_popup(comment)
      end
    end
  end, { buffer = buf, noremap = true, silent = true })

  -- Close on q
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, noremap = true, silent = true })
end

--- Toggle resolved status of comment at current line
function M.toggle_resolved()
  local comments = M.get_buffer_comments()
  local current_line = vim.fn.line(".")

  for _, comment in ipairs(comments) do
    local line = comment.line or comment.original_line or comment.position
    if line == current_line then
      comment.resolved = not comment.resolved
      vim.notify(
        comment.resolved and "Comment marked resolved" or "Comment marked unresolved",
        vim.log.levels.INFO
      )
      -- Refresh display
      M.show_comments(vim.api.nvim_get_current_buf(), comments)
      return
    end
  end

  vim.notify("No comment on this line", vim.log.levels.INFO)
end

--- Get pending comments for submission
---@return table[] pending_comments
function M.get_pending_comments()
  local all_pending = {}
  local files = state.get_files()

  for _, file in ipairs(files) do
    local comments = state.get_comments(file.filename)
    for _, comment in ipairs(comments) do
      if comment.pending then
        table.insert(all_pending, {
          path = file.filename,
          line = comment.line,
          body = comment.body,
        })
      end
    end
  end

  return all_pending
end

--- Submit pending comments to GitHub
---@param callback fun(err: string|nil)
function M.submit_comments(callback)
  local cfg, cfg_err = config.load()
  if cfg_err then
    callback("Config error: " .. cfg_err)
    return
  end

  local pending = M.get_pending_comments()
  if #pending == 0 then
    callback(nil) -- No comments to submit
    return
  end

  local owner = state.get_owner()
  local repo = state.get_repo()
  local number = state.get_number()

  -- Submit each comment
  local submitted = 0
  local errors = {}

  for _, comment in ipairs(pending) do
    api.create_comment(owner, repo, number, cfg.github_token, {
      path = comment.path,
      line = comment.line,
      body = comment.body,
    }, function(result, err)
      submitted = submitted + 1
      if err then
        table.insert(errors, err)
      else
        -- Mark comment as no longer pending
        local file_comments = state.get_comments(comment.path)
        for _, fc in ipairs(file_comments) do
          if fc.line == comment.line and fc.pending then
            fc.pending = false
            fc.id = result and result.id
            break
          end
        end
      end

      if submitted == #pending then
        if #errors > 0 then
          callback("Some comments failed: " .. table.concat(errors, "; "))
        else
          callback(nil)
        end
      end
    end)
  end
end

--- Get the namespace ID
---@return number
function M.get_namespace()
  return ns_id
end

return M
