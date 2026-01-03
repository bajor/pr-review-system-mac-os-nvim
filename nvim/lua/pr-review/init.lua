---@class PRReview
---@field config table Configuration options
---@field state table Current review session state
local M = {}

--- Default configuration
M.config = {
  -- Config will be loaded from ~/.config/pr-review/config.json
}

--- Setup highlight groups for diff display
--- Uses blue/orange for colorblind accessibility (works well with gruvbox)
local function setup_highlights()
  -- Blue background for added lines (gruvbox-friendly)
  vim.api.nvim_set_hl(0, "PRReviewAdd", {
    bg = "#1d3b53", -- Dark blue background
    fg = nil,
    default = true,
  })

  -- Orange/yellow background for deleted lines (gruvbox-friendly)
  vim.api.nvim_set_hl(0, "PRReviewDelete", {
    bg = "#3d2a1a", -- Dark orange/brown background
    fg = "#fe8019", -- Gruvbox orange text
    default = true,
  })

  -- Sign column colors (colorblind-friendly)
  vim.api.nvim_set_hl(0, "PRReviewAddSign", {
    fg = "#83a598", -- Gruvbox blue
    default = true,
  })

  vim.api.nvim_set_hl(0, "PRReviewDeleteSign", {
    fg = "#fe8019", -- Gruvbox orange
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
