return {
  { -- Autoformat
    "stevearc/conform.nvim",
    lazy = false,
    keys = {
      {
        "<leader>f",
        function()
          require("conform").format({ async = true, lsp_fallback = true })
        end,
        mode = "",
        desc = "[F]ormat buffer",
      },
    },
    opts = {
      notify_on_error = false,
      -- LazyVim will automatically use conform for format on save
      -- No need to set format_on_save here
      formatters_by_ft = {
        lua = { "stylua" },
        -- Conform can also run multiple formatters sequentially
        python = { "isort", "black" },
        --
        -- Use stop_after_first to run the first available formatter
        javascript = { "prettierd", "prettier", stop_after_first = true },
        elixir = { "mix_format" },
        heex = { "mix_format" },
        eex = { "mix_format" },
      },
    },
  },
}
