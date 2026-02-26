return {
  {
    "stevearc/aerial.nvim",
    opts = {},
    -- Optional dependencies
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons"
    },
    keys = {
      { "<leader>a", "<cmd>AerialToggle!<CR>",        desc = "Aerial (Symbols)" },
      { "<leader>o", "<cmd>AerialToggleOutline!<CR>", desc = "Aerial (Outline)" },
      { "<leader>t", "<cmd>AerialToggle!<CR>",        desc = "Arial (Table of Contents)" },
    },
  },
}
