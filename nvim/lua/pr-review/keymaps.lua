---@class PRReviewKeymaps
---Keymap management for PR review sessions
---Only 3 shortcuts: nn (next), pp (previous), cc (comment)
local M = {}

local comments = require("pr-review.comments")
local diff = require("pr-review.diff")
local state = require("pr-review.state")

--- Default keymap options
local default_opts = { noremap = true, silent = true }

--- Get all points of interest (diffs and comments) for a file
---@param file table File data with filename and patch
---@return table[] points Sorted list of {line, type} where type is "diff" or "comment"
local function get_file_points(file)
  if not file then return {} end

  local points = {}
  local seen = {}

  -- Get diff hunks
  if file.patch then
    local changes = diff.get_changed_lines(file.patch)

    -- Group consecutive changed lines into hunks
    local all_lines = {}
    for _, line in ipairs(changes.added) do
      table.insert(all_lines, line)
    end
    for _, del in ipairs(changes.deleted) do
      if del.line_num then
        table.insert(all_lines, del.line_num)
      end
    end
    table.sort(all_lines)

    -- Get hunk start lines (first line of consecutive groups)
    local prev_line = nil
    for _, line in ipairs(all_lines) do
      if prev_line == nil or line > prev_line + 1 then
        if not seen[line] then
          table.insert(points, { line = line, type = "diff" })
          seen[line] = true
        end
      end
      prev_line = line
    end
  end

  -- Get comments
  local file_comments = state.get_comments(file.filename)
  for _, comment in ipairs(file_comments) do
    local line = comment.line or comment.original_line or comment.position
    if line and line > 0 and not seen[line] then
      table.insert(points, { line = line, type = "comment" })
      seen[line] = true
    end
  end

  -- Sort by line number
  table.sort(points, function(a, b) return a.line < b.line end)

  return points
end

--- Build a flat list of all points across all files
---@return table[] all_points List of {file_index, file, line, type}
local function get_all_points()
  local files = state.get_files()
  local all_points = {}

  for file_idx, file in ipairs(files) do
    local points = get_file_points(file)
    for _, point in ipairs(points) do
      table.insert(all_points, {
        file_index = file_idx,
        file = file,
        line = point.line,
        type = point.type,
      })
    end
  end

  return all_points
end

--- Get current position in the all_points list
---@param all_points table[]
---@return number|nil current_index
local function get_current_position(all_points)
  local current_file_idx = state.get_current_file_index()
  local current_line = vim.fn.line(".")

  -- Find the closest point at or before current position
  local best_idx = nil
  for i, point in ipairs(all_points) do
    if point.file_index == current_file_idx then
      if point.line <= current_line then
        best_idx = i
      elseif point.line > current_line then
        break
      end
    elseif point.file_index > current_file_idx then
      break
    end
  end

  return best_idx
end

--- Navigate to a point (opens file if needed)
---@param point table {file_index, file, line, type}
local function goto_point(point)
  local current_file_idx = state.get_current_file_index()

  -- Switch file if needed
  if point.file_index ~= current_file_idx then
    state.session.current_file = point.file_index
    local buf = diff.open_file(point.file)
    if buf then
      -- Show comments for new file
      local file_comments = state.get_comments(point.file.filename)
      if #file_comments > 0 then
        comments.show_comments(buf, file_comments)
      end
    end
  end

  -- Go to line
  vim.api.nvim_win_set_cursor(0, { point.line, 0 })
  vim.cmd("normal! zz")

  -- Show what we landed on
  local files = state.get_files()
  local type_str = point.type == "comment" and "comment" or "change"
  vim.notify(string.format("[%d/%d] %s:%d (%s)",
    point.file_index, #files, point.file.filename, point.line, type_str))
end

--- Go to next point of interest (diff or comment, across files)
function M.next_point()
  if not state.is_active() then
    vim.notify("No active PR session", vim.log.levels.WARN)
    return
  end

  local all_points = get_all_points()
  if #all_points == 0 then
    vim.notify("No changes or comments in this PR", vim.log.levels.INFO)
    return
  end

  local current_file_idx = state.get_current_file_index()
  local current_line = vim.fn.line(".")

  -- Find next point after current position
  for _, point in ipairs(all_points) do
    if point.file_index > current_file_idx or
       (point.file_index == current_file_idx and point.line > current_line) then
      goto_point(point)
      return
    end
  end

  -- Wrap around to first point
  vim.notify("Wrapped to first point", vim.log.levels.INFO)
  goto_point(all_points[1])
end

--- Go to previous point of interest (diff or comment, across files)
function M.prev_point()
  if not state.is_active() then
    vim.notify("No active PR session", vim.log.levels.WARN)
    return
  end

  local all_points = get_all_points()
  if #all_points == 0 then
    vim.notify("No changes or comments in this PR", vim.log.levels.INFO)
    return
  end

  local current_file_idx = state.get_current_file_index()
  local current_line = vim.fn.line(".")

  -- Find previous point before current position (iterate in reverse)
  for i = #all_points, 1, -1 do
    local point = all_points[i]
    if point.file_index < current_file_idx or
       (point.file_index == current_file_idx and point.line < current_line) then
      goto_point(point)
      return
    end
  end

  -- Wrap around to last point
  vim.notify("Wrapped to last point", vim.log.levels.INFO)
  goto_point(all_points[#all_points])
end

--- Open or create comment at current line
function M.comment_at_cursor()
  if not state.is_active() then
    vim.notify("No active PR session", vim.log.levels.WARN)
    return
  end

  -- Just delegate to show_comment_thread - it handles both cases
  comments.show_comment_thread()
end

--- All PR review keymaps (simplified)
M.keymaps = {
  { mode = "n", lhs = "nn", rhs = function() M.next_point() end, desc = "Next diff/comment" },
  { mode = "n", lhs = "pp", rhs = function() M.prev_point() end, desc = "Previous diff/comment" },
  { mode = "n", lhs = "cc", rhs = function() M.comment_at_cursor() end, desc = "Comment at cursor" },
}

--- Setup all keymaps for PR review mode
function M.setup()
  for _, km in ipairs(M.keymaps) do
    local opts = vim.tbl_extend("force", default_opts, { desc = km.desc })
    vim.keymap.set(km.mode, km.lhs, km.rhs, opts)
  end
end

--- Clear all PR review keymaps
function M.clear()
  for _, km in ipairs(M.keymaps) do
    pcall(vim.keymap.del, km.mode, km.lhs)
  end
end

--- Setup buffer-local keymaps for a specific buffer
---@param buf number Buffer ID
function M.setup_buffer(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  for _, km in ipairs(M.keymaps) do
    local opts = vim.tbl_extend("force", default_opts, { desc = km.desc, buffer = buf })
    vim.keymap.set(km.mode, km.lhs, km.rhs, opts)
  end
end

return M
