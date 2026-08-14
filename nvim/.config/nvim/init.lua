---@diagnostic disable: missing-fields

-- INFO: introduction
-- this is a minimal neovim configuration written in lua. this is not meant to
-- be a distribution, but rather a template for you to build upon and/or a
-- reference for how to configure neovim using lua in the latest version.
--
-- TUTOR:
-- if you're completely new to neovim and/or vim, consider going through
-- `:Tutor` inside neovim to get a basic idea of how it works.
--     if you don't know what this means, type the following:
--       - <escape key>
--       - :
--       - Tutor
--       - <enter key>
--
-- LUA:
-- some level of familiarity with lua/programming languages are also expected.
-- if you're new to lua, consider going through the official reference:
--    https://www.lua.org/manual
-- or a more friendly tutorial like:
--    https://learnxinyminutes.com/docs/lua/
-- you can also check out `:h lua-guide` inside neovim for a neovim-specific
-- lua guide.
--
-- DEPENDENCIES:
-- this configuration assumes you have the following tools installed on your
-- system:
--    `git` - for vim builtin package manager. (see `:h vim.pack`)
--    `ripgrep` - for fuzzy finding
--    clipboard tool: xclip/xsel/win32yank - for clipboard sharing between OS and neovim (see `h: clipboard-tool`)
--    a nerdfont (ensure the terminal running neovim is using it)
-- run `:checkhealth` inside neovim to see if your system is missing anything.
--
-- MINIMAL:
-- to say that something is 'minimal' you have to define what variable you're
-- minimizing. this configuration minimizes for lines of code and concepts.
-- to some, this configuration may have too many plugins. for example, using
-- mason.nvim to manage lsp servers will be an unnecessary dependency if the
-- user is already familiar with lsps and is comfortable managing them through
-- their OS package manager. but to someone that isn't familiar with lsp servers
-- this approach wouldn't cover everything needed to have the 'minimum' necessary
-- for lsp + completion + fuzzy finding. to some, fuzzy finding is also a bloated
-- dependency.
-- this configuration is only a starting point/reference. it is expected that
-- the user will change the configuration to suit their needs.

-- INFO: options
-- these change the default neovim behaviours using the 'vim.opt' API.
-- see `:h vim.opt` for more details.
-- run `:h '{option_name}'` to see what they do and what values they can take.
-- for example, `:h 'number'` for `vim.opt.number`.

-- set <space> as the leader key
-- must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- enable true color support
vim.opt.termguicolors = true

-- Alacritty 0.13 + nvim 0.11+: kitty key-event reporting makes Enter/Tab/BS
-- fire twice (press + release) in every mode. Keep disambiguate, drop events.
-- vim.api.nvim_create_autocmd("UIEnter", {
-- 	callback = function()
-- 		vim.schedule(function()
-- 			io.stdout:write("\27[>1u")
-- 		end)
-- 	end,
-- })
-- vim.api.nvim_create_autocmd("VimLeavePre", {
-- 	callback = function()
-- 		io.stdout:write("\27[<1u")
-- 	end,
-- })

-- make line numbers default
vim.opt.number = true
vim.opt.relativenumber = true

-- enable mouse mode, can be useful for resizing splits
vim.opt.mouse = "a"

-- Local: wl-copy/xclip. Remote/container: no display, so yank with OSC 52
-- (escape sequence over SSH/tmux to the host terminal clipboard).
if
	vim.fn.executable("wl-copy") == 0
	and vim.fn.executable("xclip") == 0
	and vim.fn.executable("xsel") == 0
	and vim.fn.executable("pbcopy") == 0
then
	local osc52 = require("vim.ui.clipboard.osc52")
	vim.g.clipboard = {
		name = "OSC 52",
		copy = {
			["+"] = osc52.copy("+"),
			["*"] = osc52.copy("*"),
		},
		paste = {
			["+"] = function()
				return { vim.split(vim.fn.getreg('"'), "\n", { plain = true }), vim.fn.getregtype('"') }
			end,
			["*"] = function()
				return { vim.split(vim.fn.getreg('"'), "\n", { plain = true }), vim.fn.getregtype('"') }
			end,
		},
	}
end
vim.opt.clipboard = "unnamedplus"

-- save undo history
vim.opt.undofile = true

-- keep signcolumn on by default
vim.opt.signcolumn = "yes"

-- sets how neovim will display certain whitespace characters in the editor.
--  see `:help 'list'`
--  and `:help 'listchars'`
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- enable live preview of substitutions
vim.opt.inccommand = "split"

-- show which line your cursor is on
vim.opt.cursorline = true

-- set highlight on search, but clear on pressing <Esc> in normal mode
vim.opt.hlsearch = true

-- enable break indent
vim.opt.breakindent = true

-- enable line wrapping
vim.opt.wrap = true

-- formatting
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = false
vim.opt.textwidth = 80

vim.diagnostic.config({
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = " ",
			[vim.diagnostic.severity.WARN] = " ",
			[vim.diagnostic.severity.INFO] = " ",
			[vim.diagnostic.severity.HINT] = " ",
		},
	},
	virtual_text = true, -- show inline diagnostics
})

-- clear search highlights with <Esc>
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

vim.keymap.set({ 'n', 'v' }, ';', ':')
vim.keymap.set({ 'n', 'v' }, ':', ';')

-- INFO: colorscheme
vim.cmd.colorscheme("catppuccin")

-- INFO: plugins
-- we install plugins with neovim's builtin package manager: vim.pack
-- and then enable/configure them by calling their setup functions.
--
-- (see `:h vim.pack` for more details on how it works)
-- you can press `gx` on any of the plugin urls below to open them in your
-- browser and check out their documentation and functionality.
-- alternatively, you can run `:h {plugin-name}` to read their documentation.
--
-- plugins are then loaded and configured with a call to `setup` functions
-- provided by each plugin. this is not a rule of neovim but rather a convention
-- followed by the community.
-- these setup calls take a table as an agument and their expected contents can
-- vary wildly. refer to each plugin's documentation for details.

-- INFO: formatting and syntax highlighting
-- vim.pack.del({'nvim-treesitter'})
-- vim.pack.add({ "https://github.com/nvim-treesitter/nvim-treesitter" }, { confirm = false })
--
-- -- equivalent to :TSUpdate
-- require("nvim-treesitter.install").install({ "c" })
--
-- require("nvim-treesitter.config").setup({
-- 	auto_install = true, -- autoinstall languages that are not installed yet
-- 	ensure_installed = {
-- 		"lua",
-- 		"c",
-- 	},
-- })
--
-- vim.api.nvim_create_autocmd("FileType", {
-- 	pattern= { "<filetype>" },
-- 	callback = function()
-- 		vim.treesitter.start()
-- 	end,
-- })

vim.pack.add({ "https://github.com/saghen/blink.cmp" }, { confirm = false })

require("blink.cmp").setup({
	completion = {
		documentation = {
			auto_show = true,
		},
	},

	-- default blink keymaps
	keymap = {
		["<C-p>"] = { "select_prev", "fallback_to_mappings" },
		["<C-n>"] = { "select_next", "fallback_to_mappings" },

		["<C-y>"] = { "select_and_accept", "fallback" },
		["<C-e>"] = { "cancel", "fallback" },
		["<C-space>"] = { "show", "show_documentation", "hide_documentation" },

		["<Tab>"] = { "snippet_forward", "fallback" },
		["<S-Tab>"] = { "snippet_backward", "fallback" },

		["<C-b>"] = { "scroll_documentation_up", "fallback" },
		["<C-f>"] = { "scroll_documentation_down", "fallback" },

		["<C-k>"] = { "show_signature", "hide_signature", "fallback" },
	},

	-- Cmdline ghost text looks like zsh-autosuggestions; Enter was accepting
	-- the ghost first and only running the command on a second press.
	cmdline = {
		keymap = {
			preset = "cmdline",
			["<CR>"] = { "accept_and_enter", "fallback" },
		},
		completion = {
			ghost_text = { enabled = false },
		},
	},

	fuzzy = {
		implementation = "lua",
	},
})

-- INFO: lsp server installation and configuration

-- Colcon workspaces are typically:
--   <ws>/src/<repo>   git root / nvim cwd
--   <ws>/install      ament prefixes (headers + python)
local function is_colcon_ws(dir)
	return vim.fn.isdirectory(dir .. "/install") == 1
		and (
			vim.fn.isdirectory(dir .. "/src") == 1
			or vim.fn.filereadable(dir .. "/install/setup.bash") == 1
		)
end

local function colcon_workspace_root(start)
	local dir = vim.fs.normalize(start or vim.fn.getcwd())
	while dir and dir ~= "/" do
		if is_colcon_ws(dir) then
			return dir
		end
		if vim.fn.fnamemodify(dir, ":t") == "src" and is_colcon_ws(vim.fs.dirname(dir)) then
			return vim.fs.dirname(dir)
		end
		dir = vim.fs.dirname(dir)
	end
	return nil
end

-- extraPaths for ROS 2: source package dirs first (grd → src), then install/.
local function ros_python_extra_paths(root_dir)
	local paths, seen = {}, {}

	local function add(path)
		if not path or path == "" then
			return
		end
		path = vim.fs.normalize(path)
		if seen[path] or vim.fn.isdirectory(path) == 0 then
			return
		end
		seen[path] = true
		table.insert(paths, path)
	end

	local function add_glob(pattern)
		for _, path in ipairs(vim.fn.glob(pattern, true, true)) do
			add(path)
		end
	end

	local function add_prefix_python(prefix)
		add_glob(prefix .. "/lib/python*/site-packages")
		add_glob(prefix .. "/lib/python*/dist-packages")
		add_glob(prefix .. "/local/lib/python*/dist-packages")
	end

	local function is_generated(path)
		return path:find("/install/", 1, true)
			or path:find("/build/", 1, true)
			or vim.endswith(path, "/install")
			or vim.endswith(path, "/build")
	end

	local scan_root = vim.fs.root(root_dir or vim.fn.getcwd(), { ".git" })
		or root_dir
		or vim.fn.getcwd()
	local ws_root = colcon_workspace_root(scan_root)
		or colcon_workspace_root(vim.fn.getcwd())

	add(scan_root .. "/src")
	if ws_root then
		add(ws_root .. "/src")
	end

	local search_roots = { scan_root }
	if ws_root then
		table.insert(search_roots, ws_root .. "/src")
		table.insert(search_roots, ws_root)
	end
	local searched = {}
	for _, search in ipairs(search_roots) do
		if search and not searched[search] and vim.fn.isdirectory(search) == 1 then
			searched[search] = true
			for _, xml in ipairs(vim.fs.find("package.xml", { path = search, type = "file", limit = 400 })) do
				local pkg_dir = vim.fs.dirname(xml)
				if not is_generated(pkg_dir) then
					add(pkg_dir)
				end
			end
		end
	end

	add_glob("/opt/ros/*/lib/python*/site-packages")
	add_glob("/opt/ros/*/lib/python*/dist-packages")
	add_glob("/opt/ros/*/local/lib/python*/dist-packages")

	-- generated msgs/srvs + installed copies; keep after source so grd prefers src
	if ws_root then
		add_prefix_python(ws_root .. "/install")
		add_glob(ws_root .. "/install/*/lib/python*/site-packages")
		add_glob(ws_root .. "/install/*/lib/python*/dist-packages")
		add_glob(ws_root .. "/install/*/local/lib/python*/dist-packages")
	end
	add_glob("/ros2_ws/install/*/lib/python*/site-packages")
	add_glob("/ros2_ws/install/*/lib/python*/dist-packages")
	add_glob("/ros2_ws/install/*/local/lib/python*/dist-packages")

	for prefix in string.gmatch(vim.env.AMENT_PREFIX_PATH or "", "[^:]+") do
		add_prefix_python(prefix)
	end
	for prefix in string.gmatch(vim.env.COLCON_PREFIX_PATH or "", "[^:]+") do
		add_prefix_python(prefix)
	end
	for path in string.gmatch(vim.env.PYTHONPATH or "", "[^:]+") do
		add(path)
	end

	return paths
end

-- lsp servers we want to use and their configuration
-- see `:h lspconfig-all` for available servers and their settings
local lsp_servers = {
	lua_ls = {
		settings = {
			-- https://luals.github.io/wiki/settings/ | `:h nvim_get_runtime_file`
			Lua = { workspace = { library = vim.api.nvim_get_runtime_file("lua", true) } },
		},
	},
	clangd = {},
	rust_analyzer = {},
	basedpyright = {
		settings = {
			python = {
				pythonPath = vim.fn.exepath("python3"),
			},
			basedpyright = {
				analysis = {
					autoSearchPaths = true,
					diagnosticMode = "openFilesOnly",
					exclude = {
						"**/node_modules",
						"**/__pycache__",
						".git",
						"**/install",
						"**/build",
						"**/log",
					},
				},
			},
		},
		before_init = function(_, config)
			local extra = ros_python_extra_paths(config.root_dir)
			config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
				python = {
					analysis = { extraPaths = extra },
				},
				basedpyright = {
					analysis = {
						extraPaths = extra,
					},
				},
			})
		end,
	},
}

vim.pack.add({
	"https://github.com/neovim/nvim-lspconfig", -- default configs for lsps

	-- NOTE: if you'd rather install the lsps through your OS package manager you
	-- can delete the next three mason-related lines and their setup calls below.
	-- see `:h lsp-quickstart` for more details.
	"https://github.com/mason-org/mason.nvim", -- package manager
	"https://github.com/mason-org/mason-lspconfig.nvim", -- lspconfig bridge
	"https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim", -- auto installer
}, { confirm = false })

require("mason").setup()
require("mason-lspconfig").setup()
require("mason-tool-installer").setup({
	ensure_installed = vim.tbl_keys(lsp_servers),
})

-- configure each lsp server on the table
-- to check what clients are attached to the current buffer, use
-- `:checkhealth vim.lsp`. to view default lsp keybindings, use `:h lsp-defaults`.
for server, config in pairs(lsp_servers) do
	vim.lsp.config(server, config)
end

-- bind on LspAttach so every server gets the maps (including mason-enabled ones)
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(ev)
		local bufnr = ev.buf
		vim.keymap.set("n", "grd", vim.lsp.buf.definition, { buffer = bufnr, desc = "vim.lsp.buf.definition()" })
		vim.keymap.set("n", "grf", vim.lsp.buf.format, { buffer = bufnr, desc = "vim.lsp.buf.format()" })
	end,
})

-- INFO: fuzzy finder
vim.pack.add({
	"https://github.com/nvim-lua/plenary.nvim", -- library dependency
	"https://github.com/nvim-tree/nvim-web-devicons", -- icons (nerd font)
	"https://github.com/nvim-telescope/telescope.nvim", -- the fuzzy finder
}, { confirm = false })

require("telescope").setup({})

local pickers = require("telescope.builtin")

vim.keymap.set("n", "<leader>sp", pickers.builtin, { desc = "[S]earch Builtin [P]ickers" })
vim.keymap.set("n", "<leader>sb", pickers.buffers, { desc = "[S]earch [B]uffers" })
vim.keymap.set("n", "<leader>sf", pickers.find_files, { desc = "[S]earch [F]iles" })
vim.keymap.set("n", "<leader>sw", pickers.grep_string, { desc = "[S]earch Current [W]ord" })
vim.keymap.set("n", "<leader>sg", pickers.live_grep, { desc = "[S]earch by [G]rep" })
vim.keymap.set("n", "<leader>sr", pickers.resume, { desc = "[S]earch [R]esume" })

vim.keymap.set("n", "<leader>sh", pickers.help_tags, { desc = "[S]earch [H]elp" })
vim.keymap.set("n", "<leader>sm", pickers.man_pages, { desc = "[S]earch [M]anuals" })

-- INFO: keybinding helper
vim.pack.add({ "https://github.com/folke/which-key.nvim" }, { confirm = false })

require("which-key").setup({
	spec = {
		{ "<leader>s", group = "[S]earch", icon = { icon = "", color = "green" } },
	},
})

-- INFO: better statusline
vim.pack.add({ "https://github.com/nvim-lualine/lualine.nvim" }, { confirm = false })

require("lualine").setup({
	options = {
		section_separators = { left = "", right = "" },
		component_separators = { left = "", right = "" },
	},
})

-- uncomment to enable automatic plugin updates
-- vim.pack.update()
