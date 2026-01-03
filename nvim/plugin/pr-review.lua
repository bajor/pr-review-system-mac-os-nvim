-- Prevent loading twice
if vim.g.loaded_pr_review then
  return
end
vim.g.loaded_pr_review = 1

-- Create the PRReview command
vim.api.nvim_create_user_command("PRReview", function(opts)
  local args = opts.fargs
  local subcommand = args[1]

  if not subcommand then
    vim.notify("Usage: :PRReview <list|open|comments|submit|close>", vim.log.levels.WARN)
    return
  end

  if subcommand == "list" then
    local ui = require("pr-review.ui")
    ui.pr_list()
  elseif subcommand == "open" then
    local url = args[2]
    if not url then
      vim.notify("Usage: :PRReview open <url>", vim.log.levels.WARN)
      return
    end
    local pr_open = require("pr-review.open")
    pr_open.open_pr(url)
  elseif subcommand == "comments" then
    local pr_comments = require("pr-review.comments")
    pr_comments.list_comments()
  elseif subcommand == "submit" then
    local pr_review = require("pr-review.review")
    pr_review.show_submit_ui()
  elseif subcommand == "close" then
    local pr_open = require("pr-review.open")
    pr_open.close_pr()
  else
    vim.notify("Unknown subcommand: " .. subcommand, vim.log.levels.ERROR)
  end
end, {
  nargs = "*",
  complete = function(_, cmdline, _)
    local args = vim.split(cmdline, "%s+")
    if #args == 2 then
      -- Complete subcommands
      return { "list", "open", "comments", "submit", "close" }
    end
    return {}
  end,
  desc = "PR Review commands",
})
