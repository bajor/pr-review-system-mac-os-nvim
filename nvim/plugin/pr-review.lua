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
    vim.notify("Usage: :PRReview <list|open|comments|submit|sync|update|close>", vim.log.levels.WARN)
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
  elseif subcommand == "sync" or subcommand == "update" or subcommand == "refresh" then
    local pr_open = require("pr-review.open")
    pr_open.sync()
  elseif subcommand == "close" then
    local pr_open = require("pr-review.open")
    pr_open.close_pr()
  elseif subcommand == "config" then
    -- Open config file in current buffer
    local config_path = vim.fn.expand("~/.config/pr-review/config.json")
    -- Create directory if it doesn't exist
    local config_dir = vim.fn.expand("~/.config/pr-review")
    if vim.fn.isdirectory(config_dir) == 0 then
      vim.fn.mkdir(config_dir, "p")
    end
    -- Create default config if file doesn't exist
    if vim.fn.filereadable(config_path) == 0 then
      local default_config = [[{
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
    "sound": true
  }
}]]
      local file = io.open(config_path, "w")
      if file then
        file:write(default_config)
        file:close()
      end
    end
    vim.cmd("edit " .. config_path)
  else
    vim.notify("Unknown subcommand: " .. subcommand, vim.log.levels.ERROR)
  end
end, {
  nargs = "*",
  complete = function(_, cmdline, _)
    local args = vim.split(cmdline, "%s+")
    if #args == 2 then
      -- Complete subcommands
      return { "list", "open", "comments", "submit", "sync", "update", "refresh", "close", "config" }
    end
    return {}
  end,
  desc = "PR Review commands",
})
