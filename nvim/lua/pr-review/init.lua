---@class PRReview
---@field config table Configuration options
---@field state table Current review session state
local M = {}

--- Default configuration
M.config = {
  -- Config will be loaded from ~/.config/pr-review/config.json
}

--- Setup highlight groups for diff display
--- Uses dark green/red backgrounds for added/deleted lines
local function setup_highlights()
  -- Dark green background for added lines
  vim.api.nvim_set_hl(0, "PRReviewAdd", {
    bg = "#1a2f1a", -- Dark green background
    fg = nil,
    default = true,
  })

  -- Dark red background for deleted lines
  vim.api.nvim_set_hl(0, "PRReviewDelete", {
    bg = "#3d1a1a", -- Dark red background
    fg = "#cc6666", -- Light red text
    default = true,
  })

  -- Sign column colors
  vim.api.nvim_set_hl(0, "PRReviewAddSign", {
    fg = "#98c379", -- Green
    default = true,
  })

  vim.api.nvim_set_hl(0, "PRReviewDeleteSign", {
    fg = "#e06c75", -- Red
    default = true,
  })
end

--- Setup the PR Review plugin
---@param opts? table Optional configuration overrides
function M.setup(opts)
  opts = opts or {}

  -- Merge user options with defaults
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  -- Setup highlight groups
  setup_highlights()

  -- Re-apply highlights when colorscheme changes
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("PRReviewHighlights", { clear = true }),
    callback = setup_highlights,
  })
end

return M
