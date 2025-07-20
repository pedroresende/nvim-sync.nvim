# nvim-sync.nvim

🔄 A Neovim plugin for syncing your configuration across multiple devices using GitHub.

## ✨ Features

- 🚀 **One-time setup**: Ask for GitHub repository once and store configuration locally
- 🔄 **Auto-sync on startup**: Automatically sync your configuration when Neovim starts
- 📱 **Multi-device support**: Keep your configuration in sync across all your machines
- ⚙️ **Configurable**: Customize sync behavior, commit messages, and more
- 🔧 **Easy management**: Simple commands for manual sync operations
- 🔒 **Privacy-focused**: Repository settings stored locally (not synced)

## 📦 Installation

### Using [Lazy.nvim](https://github.com/folke/lazy.nvim) (Recommended)

Add to your plugin configuration:

```lua
{
  "pedroresende/nvim-sync.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    -- Optional configuration
    auto_sync = false,        -- Set to true for automatic sync on save
    sync_on_startup = true,   -- Sync on Neovim startup
    branch = "main",          -- Git branch to use
  },
}
```

### Using [Packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'pedroresende/nvim-sync.nvim',
  config = function()
    require('nvim-sync').setup({
      -- your configuration here
    })
  end
}
```

### Manual Installation

```bash
git clone https://github.com/pedroresende/nvim-sync.nvim.git ~/.local/share/nvim/site/pack/packer/start/nvim-sync.nvim
```

## 🚀 Quick Start

1. **Install the plugin** using your preferred method above
2. **Restart Neovim** 
3. **First-time setup**: You'll be prompted for:
   - GitHub username
   - Repository name (defaults to "nvim-config")
4. **Done!** Your configuration will now sync automatically

## 📖 Usage

### Commands

| Command | Description |
|---------|-------------|
| `:NvimSyncStatus` | Show Git status of your configuration |
| `:NvimSyncPull` | Pull changes from remote repository |
| `:NvimSyncPush` | Push local changes to remote repository |
| `:NvimSync` | Full sync (pull then push) |
| `:NvimSyncConfigure` | Reconfigure GitHub repository settings |
| `:NvimSyncInit` | Initialize a new Git repository |

### Key Mappings

| Key | Action |
|-----|--------|
| `<leader>gs` | Git Status |
| `<leader>gpl` | Git Pull |
| `<leader>gps` | Git Push |
| `<leader>gy` | Git Sync (Pull + Push) |

### Workflow Example

#### Setting up on a new machine:
```bash
# 1. Clone your nvim config
git clone https://github.com/yourusername/nvim-config ~/.config/nvim

# 2. Start Neovim (plugin will be installed via your package manager)
nvim

# 3. Plugin automatically syncs your latest configuration
```

#### Daily workflow:
1. Make changes to your configuration
2. Restart Neovim → automatic sync
3. Or manually run `:NvimSync`

## ⚙️ Configuration

```lua
require('nvim-sync').setup({
  auto_sync = false,                              -- Auto-sync on file save
  sync_on_startup = true,                         -- Sync when Neovim starts
  commit_message_template = "Auto-sync - %s",     -- Commit message template
  branch = "main",                                -- Git branch to use
  config_file_name = "sync-config.lua",           -- Local config file name
})
```

## 🔧 Advanced Usage

### Changing Repository

To switch to a different repository:

```vim
:NvimSyncConfigure
```

This will prompt for new GitHub username and repository name.

### Manual Git Operations

The plugin provides direct access to git operations:

```vim
:NvimSyncStatus    " Check what files have changed
:NvimSyncPull      " Pull latest changes
:NvimSyncPush      " Push your changes
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.
