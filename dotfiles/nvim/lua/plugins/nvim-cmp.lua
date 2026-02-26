return {
  {
    "hrsh7th/nvim-cmp",
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      local cmp = require("cmp")

      -- Disable auto-popup for smoother experience with Supermaven
      opts.completion = vim.tbl_deep_extend("force", opts.completion or {}, {
        autocomplete = false, -- Disable automatic popup
      })

      -- Optimize mappings for Supermaven + cmp harmony
      opts.mapping = vim.tbl_deep_extend("force", opts.mapping or {}, {
        ["<C-Space>"] = cmp.mapping.complete(), -- Manually trigger with Ctrl+Space
        ["<CR>"] = cmp.mapping.confirm({ select = true }),
        -- Tab handled by Supermaven for inline suggestions
        ["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
        ["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
      })

      -- Reduce visual clutter
      opts.window = opts.window or {}
      opts.window.completion = cmp.config.window.bordered({
        winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
      })

      return opts
    end,
  },
}
