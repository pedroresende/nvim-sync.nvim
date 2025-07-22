-- nvim-sync/init.lua - A plugin to sync Neovim configuration with GitHub
local M = {}

M.setup = function(opts)
	opts = opts or {}

	-- Default configuration
	local config = {
		-- Configuration options
		auto_sync = opts.auto_sync or false, -- Set to true for automatic sync on save
		sync_on_startup = opts.sync_on_startup or true, -- Set to true to sync on Neovim startup
		commit_message_template = opts.commit_message_template or "Auto-sync nvim config - %s", -- %s will be replaced with timestamp
		exclude_files = opts.exclude_files or { ".git", "lazy-lock.json", "sync-config.lua" }, -- Files to exclude from sync
		branch = opts.branch or "main", -- Default branch to sync with
		config_file_name = opts.config_file_name or "sync-config.lua", -- Name of the config file
	}

	-- Get the nvim config directory
	local config_dir = vim.fn.stdpath("config")

	local function read_config_file()
		local config_file = config_dir .. "/" .. config.config_file_name
		local f = io.open(config_file, "r")
		if f then
			local content = f:read("*a")
			f:close()
			local chunk = load(content)
			if chunk then
				return chunk()
			end
		end
		return nil
	end

	local function write_config_file(user_config)
		local config_file = config_dir .. "/" .. config.config_file_name
		local f = io.open(config_file, "w")
		if f then
			f:write("return " .. vim.inspect(user_config))
			f:close()
		end
	end

	local user_config = read_config_file()
	if not user_config or not user_config.username or not user_config.repo_name then
		user_config = {}
		user_config.username = vim.fn.input("GitHub username: ")
		if user_config.username == "" then
			vim.notify("Username required to setup sync", vim.log.levels.ERROR, { title = "Nvim Sync" })
			return
		end

		user_config.repo_name = vim.fn.input("Repository name (default: nvim-config): ")
		if user_config.repo_name == "" then
			user_config.repo_name = "nvim-config"
		end

		write_config_file(user_config)
		vim.notify(
			"Nvim Sync configuration saved! Repository: " .. user_config.username .. "/" .. user_config.repo_name,
			vim.log.levels.INFO,
			{ title = "Nvim Sync" }
		)
	end

	local sync_module = {}

	-- Function to clean up git lock files
	local function cleanup_git_locks()
		local lock_files = {
			config_dir .. "/.git/config.lock",
			config_dir .. "/.git/index.lock",
			config_dir .. "/.git/HEAD.lock",
			config_dir .. "/.git/refs/heads/main.lock",
			config_dir .. "/.git/refs/heads/master.lock",
			config_dir .. "/.git/refs/remotes/origin/main.lock",
		}

		for _, lock_file in ipairs(lock_files) do
			if vim.fn.filereadable(lock_file) == 1 then
				vim.fn.delete(lock_file)
				vim.notify(
					"Cleaned up git lock file: " .. vim.fn.fnamemodify(lock_file, ":t"),
					vim.log.levels.INFO,
					{ title = "Nvim Sync" }
				)
			end
		end

		-- Also check for any other .lock files in the git directory
		local handle = io.popen("find " .. config_dir .. "/.git -name '*.lock' 2>/dev/null")
		if handle then
			local locks = handle:read("*a")
			handle:close()
			if locks and locks ~= "" then
				for lock_file in locks:gmatch("[^\n]+") do
					if vim.fn.filereadable(lock_file) == 1 then
						vim.fn.delete(lock_file)
						vim.notify(
							"Cleaned up git lock file: " .. vim.fn.fnamemodify(lock_file, ":t"),
							vim.log.levels.INFO,
							{ title = "Nvim Sync" }
						)
					end
				end
			end
		end
	end

	-- Function to detect the correct remote to use
	local function get_tracking_remote()
		local handle =
			io.popen("cd " .. config_dir .. " && git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null")
		if handle then
			local result = handle:read("*a")
			handle:close()
			if result and result ~= "" then
				local remote_name = result:match("^refs/remotes/([^/]+)/")
				if remote_name then
					return remote_name:gsub("%s+", "") -- trim whitespace
				end
			end
		end
		return "origin" -- fallback to origin
	end

	-- Function to check and fix git repository issues
	local function fix_git_issues()
		-- Clean up any lock files first
		cleanup_git_locks()

		-- Check if git is available
		if vim.fn.executable("git") == 0 then
			vim.notify("Git is not available. Please install git.", vim.log.levels.ERROR, { title = "Nvim Sync" })
			return false
		end

		return true
	end

	-- Helper function to run git commands
	local function run_git_cmd(cmd, callback)
		local full_cmd = string.format("cd %s && git %s", config_dir, cmd)
		vim.fn.jobstart(full_cmd, {
			stdout_buffered = true,
			stderr_buffered = true,
			on_exit = function(_, code)
				if callback then
					callback(code == 0, code)
				end
			end,
			on_stdout = function(_, data)
				if callback and data then
					local output = table.concat(data, "\n")
					if output ~= "" then
						vim.notify(output, vim.log.levels.INFO, { title = "Nvim Sync" })
					end
				end
			end,
			on_stderr = function(_, data)
				if data then
					local error_output = table.concat(data, "\n")
					if error_output ~= "" then
						vim.notify(error_output, vim.log.levels.ERROR, { title = "Nvim Sync Error" })
					end
				end
			end,
		})
	end

	-- Function to check if we're in a git repository
	local function is_git_repo()
		local git_dir = config_dir .. "/.git"
		return vim.fn.isdirectory(git_dir) == 1
	end

	-- Function to check git status
	sync_module.status = function()
		if not fix_git_issues() then
			return
		end

		if not is_git_repo() then
			vim.notify("Config directory is not a git repository", vim.log.levels.ERROR, { title = "Nvim Sync" })
			return
		end

		-- Just run git status directly
		local handle = io.popen("cd " .. config_dir .. " && git status")
		if handle then
			local result = handle:read("*a")
			handle:close()
			if result and result ~= "" then
				vim.notify(result, vim.log.levels.INFO, { title = "Git Status" })
			else
				vim.notify("No git status output", vim.log.levels.WARN, { title = "Nvim Sync" })
			end
		else
			vim.notify("Failed to get git status", vim.log.levels.ERROR, { title = "Nvim Sync" })
		end
	end

	-- Function to pull changes from remote
	sync_module.pull = function()
		if not fix_git_issues() then
			return
		end

		if not is_git_repo() then
			vim.notify("Config directory is not a git repository", vim.log.levels.ERROR, { title = "Nvim Sync" })
			return
		end

		local remote = get_tracking_remote()
		vim.notify("Pulling changes from remote " .. remote .. "...", vim.log.levels.INFO, { title = "Nvim Sync" })
		run_git_cmd("pull " .. remote .. " " .. config.branch, function(success, code)
			if success then
				vim.notify("Successfully pulled changes", vim.log.levels.INFO, { title = "Nvim Sync" })
				-- Ask user if they want to restart Neovim
				local choice = vim.fn.confirm("Restart Neovim to apply changes?", "&Yes\n&No", 2)
				if choice == 1 then
					vim.cmd("qa!")
				end
			else
				vim.notify("Failed to pull changes", vim.log.levels.ERROR, { title = "Nvim Sync" })
			end
		end)
	end

  -- Function to push changes to remote
  sync_module.push = function()
    if not fix_git_issues() then
      return
    end
    
    if not is_git_repo() then
      vim.notify("Config directory is not a git repository", vim.log.levels.ERROR, { title = "Nvim Sync" })
      return
    end
    
    local remote = get_tracking_remote()
    
    -- Check if there are unpushed commits first
    run_git_cmd("log " .. remote .. "/" .. config.branch .. "..HEAD --oneline", function(has_unpushed, code)
      if has_unpushed then
        -- There are unpushed commits, push them
        vim.notify("Found unpushed commits, pushing to remote " .. remote .. "...", vim.log.levels.INFO, { title = "Nvim Sync" })
        run_git_cmd("push " .. remote .. " " .. config.branch, function(push_success)
          if push_success then
            vim.notify("Successfully pushed commits to GitHub!", vim.log.levels.INFO, { title = "Nvim Sync" })
          else
            vim.notify("Failed to push to remote", vim.log.levels.ERROR, { title = "Nvim Sync" })
          end
        end)
        return
      end
      
      -- No unpushed commits, check for uncommitted changes
      run_git_cmd("add .", function(add_success)
        if not add_success then
          vim.notify("Failed to stage changes", vim.log.levels.ERROR, { title = "Nvim Sync" })
          return
        end
        
        -- Check if there are changes to commit
        run_git_cmd("diff --cached --quiet", function(no_staged_changes)
          if no_staged_changes then
            vim.notify("No changes to commit or push", vim.log.levels.INFO, { title = "Nvim Sync" })
            return
          end
          
          -- Commit with timestamp
          local timestamp = os.date("%Y-%m-%d %H:%M:%S")
          local commit_msg = string.format(config.commit_message_template, timestamp)
          local commit_cmd = string.format('commit -m "%s"', commit_msg)
          
          run_git_cmd(commit_cmd, function(commit_success)
            if not commit_success then
              vim.notify("Failed to commit changes", vim.log.levels.ERROR, { title = "Nvim Sync" })
              return
            end
            
            -- Push to remote
            vim.notify("Pushing new commit to remote " .. remote .. "...", vim.log.levels.INFO, { title = "Nvim Sync" })
            run_git_cmd("push " .. remote .. " " .. config.branch, function(push_success)
              if push_success then
                vim.notify("Successfully synced to GitHub!", vim.log.levels.INFO, { title = "Nvim Sync" })
              else
                vim.notify("Failed to push to remote", vim.log.levels.ERROR, { title = "Nvim Sync" })
              end
            end)
          end)
        end)
      end)
    end)
  end

	-- Function to sync (pull then push)
	sync_module.sync = function()
		if not fix_git_issues() then
			return
		end

		local remote = get_tracking_remote()
		vim.notify(
			"Starting sync process with remote " .. remote .. "...",
			vim.log.levels.INFO,
			{ title = "Nvim Sync" }
		)

		-- First pull, then push
		run_git_cmd("pull " .. remote .. " " .. config.branch, function(pull_success)
			if pull_success then
				vim.notify("Pull completed, now pushing...", vim.log.levels.INFO, { title = "Nvim Sync" })
				sync_module.push()
			else
				vim.notify("Pull failed, aborting sync", vim.log.levels.ERROR, { title = "Nvim Sync" })
			end
		end)
	end

	-- Function to initialize git repository if it doesn't exist
	sync_module.init = function()
		if not fix_git_issues() then
			return
		end

		if is_git_repo() then
			vim.notify("Already a git repository", vim.log.levels.INFO, { title = "Nvim Sync" })
			return
		end

		-- Get GitHub username/repo from user
		local username = vim.fn.input("GitHub username: ")
		if username == "" then
			vim.notify("Username required", vim.log.levels.ERROR, { title = "Nvim Sync" })
			return
		end

		local repo_name = vim.fn.input("Repository name (default: nvim-config): ")
		if repo_name == "" then
			repo_name = "nvim-config"
		end

		local remote_url = string.format("https://github.com/%s/%s.git", username, repo_name)

		-- Initialize git repository
		local init_commands = {
			"init",
			string.format("remote add origin %s", remote_url),
			"add .",
			'commit -m "Initial nvim configuration"',
			string.format("branch -M %s", config.branch),
			string.format("push -u origin %s", config.branch),
		}

		local function run_next_command(index)
			if index > #init_commands then
				vim.notify("Git repository initialized successfully!", vim.log.levels.INFO, { title = "Nvim Sync" })
				return
			end

			run_git_cmd(init_commands[index], function(success)
				if success then
					run_next_command(index + 1)
				else
					vim.notify(
						string.format("Failed at step: %s", init_commands[index]),
						vim.log.levels.ERROR,
						{ title = "Nvim Sync" }
					)
				end
			end)
		end

		run_next_command(1)
	end

	-- Function to reset/reconfigure the repository settings
	sync_module.configure = function()
		if not fix_git_issues() then
			return
		end

		local username = vim.fn.input("GitHub username: ")
		if username == "" then
			vim.notify("Username required", vim.log.levels.ERROR, { title = "Nvim Sync" })
			return
		end

		local repo_name = vim.fn.input("Repository name (default: nvim-config): ")
		if repo_name == "" then
			repo_name = "nvim-config"
		end

		-- Update the stored configuration
		user_config.username = username
		user_config.repo_name = repo_name
		write_config_file(user_config)

		-- Update the git remote (use the tracking remote, not just origin)
		local remote = get_tracking_remote()
		local remote_url = string.format("https://github.com/%s/%s.git", username, repo_name)
		run_git_cmd(string.format("remote set-url %s %s", remote, remote_url), function(success)
			if success then
				vim.notify(
					string.format("Repository updated to %s/%s (remote: %s)", username, repo_name, remote),
					vim.log.levels.INFO,
					{ title = "Nvim Sync" }
				)
			else
				vim.notify(
					string.format("Failed to update %s remote", remote),
					vim.log.levels.ERROR,
					{ title = "Nvim Sync" }
				)
			end
		end)
	end

	-- Function to commit changes automatically
	sync_module.commit = function()
		if not fix_git_issues() then
			return
		end
		
		if not is_git_repo() then
			vim.notify("Config directory is not a git repository", vim.log.levels.ERROR, { title = "Nvim Sync" })
			return
		end
		
		-- First, add all changes
		run_git_cmd("add .", function(add_success)
			if not add_success then
				vim.notify("Failed to stage changes", vim.log.levels.ERROR, { title = "Nvim Sync" })
				return
			end
			
			-- Check if there are changes to commit
			run_git_cmd("diff --cached --quiet", function(no_staged_changes)
				if no_staged_changes then
					vim.notify("No changes to commit", vim.log.levels.INFO, { title = "Nvim Sync" })
					return
				end
				
				-- Commit with timestamp
				local timestamp = os.date("%Y-%m-%d %H:%M:%S")
				local commit_msg = string.format(config.commit_message_template, timestamp)
				local commit_cmd = string.format('commit -m "%s"', commit_msg)
				
				run_git_cmd(commit_cmd, function(commit_success)
					if commit_success then
						vim.notify("Successfully committed changes!", vim.log.levels.INFO, { title = "Nvim Sync" })
					else
						vim.notify("Failed to commit changes", vim.log.levels.ERROR, { title = "Nvim Sync" })
					end
				end)
			end)
		end)
	end

	-- Function to manually clean up git issues
	sync_module.cleanup = function()
		cleanup_git_locks()
		vim.notify("Git cleanup completed", vim.log.levels.INFO, { title = "Nvim Sync" })
	end

	-- Auto-sync on save if enabled
	if config.auto_sync then
		vim.api.nvim_create_autocmd("BufWritePost", {
			pattern = config_dir .. "/*",
			callback = function()
				sync_module.push()
			end,
			desc = "Auto-sync nvim config on save",
		})
	end

	-- Function to setup repository on startup
	local function setup_repo_on_startup()
		vim.schedule(function()
			-- Use stored username and repo_name
			local username = user_config.username
			local repo_name = user_config.repo_name

			local remote_url = string.format("https://github.com/%s/%s.git", username, repo_name)

			-- Set or update the remote origin
			if not is_git_repo() then
				run_git_cmd("init", function(init_success)
					if init_success then
						run_git_cmd(string.format("remote add origin %s", remote_url), function(remote_success)
							if remote_success then
								vim.notify(
									string.format("Repository %s/%s configured", username, repo_name),
									vim.log.levels.INFO,
									{ title = "Nvim Sync" }
								)
								-- Start sync after setup
								vim.defer_fn(function()
									sync_module.sync()
								end, 1000)
							end
						end)
					end
				end)
			else
				-- Just notify, don't try to change remote or sync automatically
				vim.notify(
					string.format("Using repository %s/%s", username, repo_name),
					vim.log.levels.INFO,
					{ title = "Nvim Sync" }
				)
				-- Let user manually sync if needed
			end
		end)
	end

	-- Setup repository and sync on startup every time
	if config.sync_on_startup then
		vim.api.nvim_create_autocmd("VimEnter", {
			callback = function()
				setup_repo_on_startup()
			end,
			desc = "Setup repository and auto-sync nvim config on startup",
		})
	end

	-- Create user commands
	vim.api.nvim_create_user_command("NvimSyncStatus", sync_module.status, { desc = "Show git status of nvim config" })
	vim.api.nvim_create_user_command("NvimSyncPull", sync_module.pull, { desc = "Pull changes from remote" })
	vim.api.nvim_create_user_command("NvimSyncPush", sync_module.push, { desc = "Push changes to remote" })
	vim.api.nvim_create_user_command("NvimSync", sync_module.sync, { desc = "Sync nvim config (pull then push)" })
	vim.api.nvim_create_user_command(
		"NvimSyncInit",
		sync_module.init,
		{ desc = "Initialize git repository for nvim config" }
	)
	vim.api.nvim_create_user_command(
		"NvimSyncConfigure",
		sync_module.configure,
		{ desc = "Configure GitHub repository settings" }
	)
	vim.api.nvim_create_user_command(
		"NvimSyncCommit",
		sync_module.commit,
		{ desc = "Commit changes with timestamp" }
	)
	vim.api.nvim_create_user_command(
		"NvimSyncCleanup",
		sync_module.cleanup,
		{ desc = "Clean up git lock files and issues" }
	)

	-- Create keymaps (optional - users can customize these)
	vim.keymap.set("n", "<leader>gs", sync_module.status, { desc = "Git Status (nvim config)" })
	vim.keymap.set("n", "<leader>gpl", sync_module.pull, { desc = "Git Pull (nvim config)" })
	vim.keymap.set("n", "<leader>gps", sync_module.push, { desc = "Git Push (nvim config)" })
	vim.keymap.set("n", "<leader>gy", sync_module.sync, { desc = "Git Sync (nvim config)" })

	-- Store functions globally for access from other parts of config
	_G.NvimSync = sync_module
end

return M
