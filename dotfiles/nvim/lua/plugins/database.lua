return {
  {
    "tpope/vim-dadbod",
    lazy = true,
    dependencies = {
      "kristijanhusak/vim-dadbod-ui",
      "kristijanhusak/vim-dadbod-completion",
    },
    cmd = {
      "DB",
      "DBUI",
      "DBUIToggle",
      "DBUIAddConnection",
      "DBUIFindBuffer",
    },
    init = function()
      -- Your DBUI configuration
      vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/db_ui"
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_show_database_icon = 1
      vim.g.db_ui_force_echo_notifications = 1
      vim.g.db_ui_win_position = "left"
      vim.g.db_ui_winwidth = 40

      -- Add an example SQLite connection (you can add more in DBUI)
      vim.g.dbs = {
        sample_app = "sqlite:" .. vim.fn.getcwd() .. "/priv/sample_app.db",
      }
    end,
    keys = {
      { "<leader>td", "<cmd>DBUIToggle<cr>", desc = "Toggle Database UI" },
      { "<leader>tf", "<cmd>DBUIFindBuffer<cr>", desc = "Find DB Buffer" },
    },
  },
}
