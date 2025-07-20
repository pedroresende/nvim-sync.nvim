-- Main plugin entry point for lazy.nvim
return {
  "pedroresende/nvim-sync.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    -- Configuration options (users can override these)
    auto_sync = false, -- Set to true for automatic sync on save
    sync_on_startup = true, -- Set to true to sync on Neovim startup
    commit_message_template = "Auto-sync nvim config - %s", -- %s will be replaced with timestamp
    branch = "main", -- Default branch to sync with
  },
  config = function(_, opts)
    require('nvim-sync').setup(opts)
  end,
}
