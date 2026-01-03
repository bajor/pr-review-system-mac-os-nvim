---@class PRReview
---@field config table Configuration options
---@field state table Current review session state
local M = {}

--- Default configuration
M.config = {
  -- Config will be loaded from ~/.config/pr-review/config.json
}

--- Setup the PR Review plugin
---@param opts? table Optional configuration overrides
function M.setup(opts)
  opts = opts or {}

  -- Merge user options with defaults
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  -- Load configuration from file (will be implemented in Phase 2)
  -- local config = require("pr-review.config")
  -- M.config = config.load()
end

return M
