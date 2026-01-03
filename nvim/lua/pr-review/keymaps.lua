---@class PRReviewKeymaps
---Keymap management for PR review sessions
local M = {}

local comments = require("pr-review.comments")
local diff = require("pr-review.diff")
local review = require("pr-review.review")

--- Default keymap options
local default_opts = { noremap = true, silent = true }

--- All PR review keymaps
M.keymaps = {
  -- File navigation
  { mode = "n", lhs = "]f", rhs = function() diff.next_file() end, desc = "Next PR file" },
  { mode = "n", lhs = "[f", rhs = function() diff.prev_file() end, desc = "Previous PR file" },

  -- Diff navigation (within file)
  { mode = "n", lhs = "<leader>nd", rhs = function() diff.next_diff() end, desc = "Next diff change" },
  { mode = "n", lhs = "<leader>pd", rhs = function() diff.prev_diff() end, desc = "Previous diff change" },

  -- Comment navigation
  { mode = "n", lhs = "<leader>nc", rhs = function() comments.next_comment() end, desc = "Next comment" },
  { mode = "n", lhs = "<leader>pc", rhs = function() comments.prev_comment() end, desc = "Previous comment" },

  -- Comment actions
  { mode = "n", lhs = "<leader>cc", rhs = function() comments.create_comment() end, desc = "Create comment" },
  { mode = "n", lhs = "<leader>lc", rhs = function() comments.list_comments() end, desc = "List comments" },
  { mode = "n", lhs = "<leader>rc", rhs = function() comments.toggle_resolved() end, desc = "Toggle resolved" },

  -- Review actions
  { mode = "n", lhs = "<leader>rs", rhs = function() review.show_submit_ui() end, desc = "Submit review" },
  { mode = "n", lhs = "<leader>ra", rhs = function() review.quick_approve() end, desc = "Quick approve" },
  { mode = "n", lhs = "<leader>ri", rhs = function() review.show_status() end, desc = "Review status" },
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

--- Get a description of all keymaps for help display
---@return string[]
function M.get_help()
  local lines = {
    "PR Review Keymaps:",
    "",
  }

  local categories = {
    { name = "File Navigation", keys = { "]f", "[f" } },
    { name = "Diff Navigation", keys = { "<leader>nd", "<leader>pd" } },
    { name = "Comment Navigation", keys = { "<leader>nc", "<leader>pc" } },
    { name = "Comment Actions", keys = { "<leader>cc", "<leader>lc", "<leader>rc" } },
    { name = "Review Actions", keys = { "<leader>rs", "<leader>ra", "<leader>ri" } },
  }

  for _, cat in ipairs(categories) do
    table.insert(lines, cat.name .. ":")
    for _, km in ipairs(M.keymaps) do
      for _, key in ipairs(cat.keys) do
        if km.lhs == key then
          table.insert(lines, string.format("  %s - %s", km.lhs, km.desc))
        end
      end
    end
    table.insert(lines, "")
  end

  return lines
end

--- Show help in a floating window
function M.show_help()
  local lines = M.get_help()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local width = 40
  local height = #lines

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = (vim.o.lines - height) / 2,
    col = (vim.o.columns - width) / 2,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " PR Review Help ",
    title_pos = "center",
  })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, noremap = true, silent = true })

  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, noremap = true, silent = true })
end

return M
