return {
  {
    "kevinhwang91/rnvimr",
    config = function()
      vim.g.rnvimr_enable_ex = 1
      vim.g.rnvimr_enable_picker = 1
      vim.g.rnvimr_enable_bw = 1
      vim.api.nvim_set_keymap('n', '<leader>r', ':RnvimrToggle<CR>', { noremap = true, silent = true })
    end,
  }
}
