return {
  {
    "supermaven-inc/supermaven-nvim",
    event = "InsertEnter",
    config = function()
      require("supermaven-nvim").setup({
        keymaps = {
          accept_suggestion = "<Tab>",
          clear_suggestion = "<C-]>",
          accept_word = "<C-j>",
        },
        ignore_filetypes = { "help", "alpha", "dashboard" },
        color = {
          suggestion_color = "#808080",
          cterm = 244,
        },
      })
    end,
  },
}
