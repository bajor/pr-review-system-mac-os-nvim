---@class PRReviewConfig
---@field github_token string GitHub personal access token
---@field github_username string GitHub username
---@field repos string[] List of repos to watch (format: "owner/repo")
---@field clone_root string Root directory for cloned PR repos
---@field poll_interval_seconds number Polling interval in seconds
---@field ghostty_path string Path to Ghostty.app
---@field nvim_path string Path to nvim binary
---@field notifications? PRReviewNotificationConfig Notification settings

---@class PRReviewNotificationConfig
---@field new_commits? boolean Notify on new commits
---@field new_comments? boolean Notify on new comments
---@field sound? boolean Play sound with notifications

local M = {}

--- Default configuration values
M.defaults = {
  github_token = "",
  github_username = "",
  repos = {},
  clone_root = "~/.local/share/pr-review/repos",
  poll_interval_seconds = 300,
  ghostty_path = "/Applications/Ghostty.app",
  nvim_path = "/opt/homebrew/bin/nvim",
  notifications = {
    new_commits = true,
    new_comments = true,
    sound = true,
  },
}

--- Config file path
M.config_path = vim.fn.expand("~/.config/pr-review/config.json")

--- Expand tilde in paths
---@param path string
---@return string
local function expand_path(path)
  if path:sub(1, 1) == "~" then
    return vim.fn.expand(path)
  end
  return path
end

--- Validate required fields in config
---@param config table
---@return boolean, string?
local function validate_config(config)
  if not config.github_token or config.github_token == "" then
    return false, "github_token is required"
  end

  if not config.github_username or config.github_username == "" then
    return false, "github_username is required"
  end

  if not config.repos or type(config.repos) ~= "table" or #config.repos == 0 then
    return false, "repos must be a non-empty array"
  end

  -- Validate repo format (owner/repo)
  for _, repo in ipairs(config.repos) do
    if not repo:match("^[%w%-_.]+/[%w%-_.]+$") then
      return false, string.format("Invalid repo format: '%s' (expected 'owner/repo')", repo)
    end
  end

  return true, nil
end

--- Load configuration from JSON file
--- GitHub token is read from GITHUB_TOKEN_PR_REVIEW_SYSTEM env var (required)
---@return PRReviewConfig?, string?
function M.load()
  -- Get token from environment variable (required)
  local github_token = os.getenv("GITHUB_TOKEN_PR_REVIEW_SYSTEM")
  if not github_token or github_token == "" then
    return nil, "GITHUB_TOKEN_PR_REVIEW_SYSTEM environment variable is required"
  end

  local path = M.config_path

  -- Check if file exists
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return nil, string.format("Config file not found: %s", path)
  end

  -- Read file
  local file = io.open(path, "r")
  if not file then
    return nil, string.format("Cannot open config file: %s", path)
  end

  local content = file:read("*a")
  file:close()

  -- Parse JSON
  local ok, parsed = pcall(vim.json.decode, content)
  if not ok then
    return nil, string.format("Invalid JSON in config file: %s", parsed)
  end

  -- Merge with defaults
  local config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), parsed)

  -- Override token from env var (never from config file)
  config.github_token = github_token

  -- Expand paths
  config.clone_root = expand_path(config.clone_root)
  config.ghostty_path = expand_path(config.ghostty_path)
  config.nvim_path = expand_path(config.nvim_path)

  -- Validate
  local valid, err = validate_config(config)
  if not valid then
    return nil, err
  end

  return config, nil
end

--- Create a default config file if it doesn't exist
---@return boolean, string?
function M.create_default()
  local dir = vim.fn.fnamemodify(M.config_path, ":h")

  -- Create directory if needed
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  -- Check if file already exists
  if vim.fn.filereadable(M.config_path) == 1 then
    return false, "Config file already exists"
  end

  -- Create default config (token comes from GITHUB_TOKEN env var)
  local default = {
    github_username = "your-username",
    repos = { "owner/repo1", "owner/repo2" },
    clone_root = "~/.local/share/pr-review/repos",
    poll_interval_seconds = 300,
    ghostty_path = "/Applications/Ghostty.app",
    nvim_path = "/opt/homebrew/bin/nvim",
    notifications = {
      new_commits = true,
      new_comments = true,
      sound = true,
    },
  }

  local json = vim.json.encode(default)
  -- Pretty print JSON
  local formatted = json:gsub(",", ",\n  "):gsub("{", "{\n  "):gsub("}", "\n}")

  local file = io.open(M.config_path, "w")
  if not file then
    return false, "Cannot create config file"
  end

  file:write(formatted)
  file:close()

  return true, nil
end

return M
