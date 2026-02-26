-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Performance optimizations
vim.opt.lazyredraw = true -- Don't redraw while executing macros
vim.opt.synmaxcol = 240 -- Only syntax highlight first 240 columns
vim.opt.updatetime = 250 -- Faster completion and CursorHold events
vim.opt.timeoutlen = 300 -- Faster which-key popup
vim.opt.ttimeoutlen = 10 -- Faster key sequence timeout

-- Better defaults for Elixir development
vim.opt.expandtab = true -- Use spaces instead of tabs
vim.opt.shiftwidth = 2 -- Elixir standard
vim.opt.tabstop = 2 -- Elixir standard
vim.opt.softtabstop = 2 -- Elixir standard

-- Enhanced search and replace
vim.opt.gdefault = true -- Global replace by default
vim.opt.inccommand = "split" -- Live preview of :s command

-- Better file handling
vim.opt.confirm = true -- Confirm before quitting unsaved files
vim.opt.backup = false -- Disable backup files (use git instead)
vim.opt.swapfile = false -- Disable swap files (modern editors don't need them)
vim.opt.undofile = true -- Persistent undo history
vim.opt.undolevels = 10000 -- More undo levels

-- UI enhancements
vim.opt.pumheight = 10 -- Limit completion menu height
vim.opt.cmdheight = 1 -- Single line command area
vim.opt.showtabline = 0 -- Hide tab line when only one tab
vim.opt.laststatus = 3 -- Global statusline
