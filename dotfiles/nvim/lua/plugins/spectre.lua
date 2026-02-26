-- In your LazyVim plugin spec file (e.g., lua/plugins/editor.lua)
return {
  "nvim-pack/nvim-spectre",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    { "<leader>ss", function() require("spectre").open() end,                              desc = "Open Spectre (Project)" },
    { "<leader>sw", function() require("spectre").open_visual({ select_word = true }) end, desc = "Search Current Word" },
  },
}
