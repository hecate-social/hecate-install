-- Core plugins for enhanced development workflow
return {
  -- Testing framework with optimized loading
  {
    "vim-test/vim-test",
    cmd = { "TestFile", "TestNearest", "TestLast", "TestSuite", "TestVisit" },
    config = function()
      vim.cmd([[
        function! BufferTermStrategy(cmd)
          exec 'te ' . a:cmd
        endfunction

        let g:test#custom_strategies = {'bufferterm': function('BufferTermStrategy')}
        let g:test#strategy = 'bufferterm'
        let g:test#preserve_screen = 1
        let g:test#echo_command = 0
      ]])
    end,
    keys = {
      { "<leader>Tf", "<cmd>TestFile<cr>", silent = true, desc = "Run this file" },
      { "<leader>Tn", "<cmd>TestNearest<cr>", silent = true, desc = "Run nearest test" },
      { "<leader>Tl", "<cmd>TestLast<cr>", silent = true, desc = "Run last test" },
      { "<leader>Ts", "<cmd>TestSuite<cr>", silent = true, desc = "Run test suite" },
    },
  },

  -- Enhanced linting with better configuration
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require("lint")

      lint.linters_by_ft = {
        elixir = { "credo" },
        javascript = { "eslint_d" },
        typescript = { "eslint_d" },
        python = { "pylint" },
        lua = { "luacheck" },
      }

      -- Optimize linting triggers
      local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })
      
      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
        group = lint_augroup,
        callback = function()
          -- Only lint if file is not too large
          local max_filesize = 100 * 1024 -- 100 KB
          local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(0))
          if ok and stats and stats.size > max_filesize then
            return
          end
          lint.try_lint()
        end,
      })
    end,
  },

  -- Git integration with lazy loading
  {
    "kdheepak/lazygit.nvim",
    cmd = "LazyGit",
    keys = {
      { "<leader>gg", "<cmd>LazyGit<cr>", desc = "Open LazyGit" },
    },
  },
}
