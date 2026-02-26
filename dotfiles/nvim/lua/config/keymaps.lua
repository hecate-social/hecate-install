-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Enhanced movement and editing
vim.keymap.set("n", "H", "^", { desc = "Go to first non-blank character" })
vim.keymap.set("n", "L", "$", { desc = "Go to end of line" })

-- Better window navigation
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Resize with arrows
vim.keymap.set("n", "<C-Up>", ":resize -2<CR>", { desc = "Decrease window height" })
vim.keymap.set("n", "<C-Down>", ":resize +2<CR>", { desc = "Increase window height" })
vim.keymap.set("n", "<C-Left>", ":vertical resize -2<CR>", { desc = "Decrease window width" })
vim.keymap.set("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "Increase window width" })

-- Better indenting
vim.keymap.set("v", "<", "<gv", { desc = "Indent left and reselect" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right and reselect" })

-- Move text up and down
vim.keymap.set("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Quick save and quit
vim.keymap.set("n", "<C-s>", "<cmd>w<cr>", { desc = "Save file" })
vim.keymap.set("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })
vim.keymap.set("n", "<leader>Q", "<cmd>qa<cr>", { desc = "Quit all" })

-- Clear search highlighting
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlights" })

-- Better paste
vim.keymap.set("v", "p", '"_dP', { desc = "Paste without yanking" })

-- Jump to beginning/end of file
vim.keymap.set("n", "<C-Home>", "gg", { desc = "Jump to beginning of file" })
vim.keymap.set("n", "<C-End>", "G", { desc = "Jump to end of file" })
vim.keymap.set("i", "<C-Home>", "<Esc>gg", { desc = "Jump to beginning of file" })
vim.keymap.set("i", "<C-End>", "<Esc>G", { desc = "Jump to end of file" })
vim.keymap.set("v", "<C-Home>", "gg", { desc = "Jump to beginning of file" })
vim.keymap.set("v", "<C-End>", "G", { desc = "Jump to end of file" })

-- Elixir-specific shortcuts
vim.keymap.set("n", "<leader>ep", "<cmd>!mix phx.server<cr>", { desc = "Start Phoenix server" })
vim.keymap.set("n", "<leader>ei", "<cmd>!iex -S mix<cr>", { desc = "Start IEx with mix" })
vim.keymap.set("n", "<leader>et", "<cmd>!mix test<cr>", { desc = "Run all tests" })
