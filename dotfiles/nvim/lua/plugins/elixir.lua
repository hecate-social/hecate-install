return {
  -- Enhanced Elixir support
  {
    "elixir-tools/elixir-tools.nvim",
    version = "*",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local elixir = require("elixir")
      local elixirls = require("elixir.elixirls")

      elixir.setup({
        nextls = {
          enable = true,
          init_options = {
            mix_env = "dev",
            mix_target = "host",
            experimental = {
              completions = {
                enable = true,
              },
            },
          },
        },
        elixirls = {
          enable = false, -- Disable in favor of NextLS
          settings = elixirls.settings({
            dialyzerEnabled = false,
            enableTestLenses = false,
          }),
        },
        projectionist = {
          enable = true,
        },
      })
    end,
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
  },

  -- Enhanced testing for Elixir (compatible with user's vim-test setup)
  {
    "jfpedroza/neotest-elixir",
    ft = "elixir",
    dependencies = {
      "nvim-neotest/neotest",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-elixir"),
        },
        status = { virtual_text = true },
        output = { open_on_run = true },
        quickfix = {
          open = function()
            if require("trouble").is_open() then
              vim.cmd("Trouble qflist")
            else
              vim.cmd("copen")
            end
          end,
        },
      })
    end,
    keys = {
      { "<leader>Tr", "<cmd>lua require('neotest').run.run()<cr>", desc = "Run nearest test" },
      { "<leader>Tf", "<cmd>lua require('neotest').run.run(vim.fn.expand('%'))<cr>", desc = "Run file tests" },
      { "<leader>Ts", "<cmd>lua require('neotest').summary.toggle()<cr>", desc = "Toggle test summary" },
      { "<leader>To", "<cmd>lua require('neotest').output.open({ enter = true })<cr>", desc = "Open test output" },
    },
  },

  -- IEx integration
  {
    "axelvc/template-string.nvim",
    ft = "elixir",
    config = function()
      require("template-string").setup({
        filetypes = { "elixir" },
        jsx_brackets = false,
        remove_template_string = false,
        restore_quotes = {
          normal = [["]],
          jsx = [["]],
        },
      })
    end,
  },

  -- Enhanced Phoenix/LiveView support
  -- TEMPORARILY DISABLED: elixir-extras.nvim has compatibility issues with newer nvim-treesitter
  -- {
  --   "emmanueltouzery/elixir-extras.nvim",
  --   ft = { "elixir", "eex", "heex", "surface" },
  --   dependencies = { "nvim-treesitter/nvim-treesitter" },
  --   config = function()
  --     require("elixir-extras").setup_multiple_clause_gutter()
  --   end,
  --   keys = {
  --     { "<leader>ep", "<cmd>lua require('elixir-extras').elixir_view_docs()<cr>", desc = "View Elixir docs" },
  --     { "<leader>em", "<cmd>lua require('elixir-extras').mix_task()<cr>", desc = "Run Mix task" },
  --   },
  -- },

  -- Better HEEX/Phoenix template support
  -- Note: phoenixframework/phoenix.nvim doesn't exist
  -- Using autocmd directly for HEEX comment support
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    opts = function(_, opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "heex",
        callback = function()
          vim.bo.commentstring = "<%!-- %s --%>"
        end,
      })
      return opts
    end,
  },
}