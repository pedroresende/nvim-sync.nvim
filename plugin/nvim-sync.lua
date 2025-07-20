-- plugin/nvim-sync.lua - Auto-load plugin entry point
-- This file is automatically loaded by Neovim when the plugin is installed

-- Only load the plugin once
if vim.g.loaded_nvim_sync then
  return
end
vim.g.loaded_nvim_sync = 1

-- Setup the plugin with default options
require('nvim-sync').setup({})
