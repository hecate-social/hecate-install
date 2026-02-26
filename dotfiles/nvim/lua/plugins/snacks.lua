return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  init = function()
    -- Define Christmas-themed highlight groups
    vim.api.nvim_set_hl(0, "DashboardSnow", { fg = "#89dceb" })      -- Cyan snowflakes
    vim.api.nvim_set_hl(0, "DashboardBeam", { fg = "#7aa2f7" })      -- Blue BEAM
    vim.api.nvim_set_hl(0, "DashboardCampus", { fg = "#9ece6a" })    -- Green CAMPUS
    vim.api.nvim_set_hl(0, "DashboardChristmas", { fg = "#f7768e" }) -- Red Christmas greeting
    vim.api.nvim_set_hl(0, "DashboardStar", { fg = "#e0af68" })      -- Gold stars
  end,
  opts = {
    -- Powerful dashboard with startup time optimization
    dashboard = {
      enabled = false, -- Using alpha-nvim for multi-colored Christmas banner
      preset = {
        header = "", -- We use custom sections instead
      },
      sections = {
        -- Snowfall decoration
        {
          text = {
            { "              ❄  *  ❄     ", hl = "DashboardSnow" },
            { "✨", hl = "DashboardStar" },
            { "     ❄  *  ❄              \n", hl = "DashboardSnow" },
            { "         *    ❄    ", hl = "DashboardSnow" },
            { "🎄    ★    🎄", hl = "DashboardCampus" },
            { "    ❄    *         \n", hl = "DashboardSnow" },
            { "    ❄      *      ❄      *      ❄      *      ❄    \n", hl = "DashboardSnow" },
          },
          padding = 1,
          align = "center",
        },
        -- BEAM with snow (blue)
        {
          text = {
            { "   ░░░░░░░ ░░░░░░░░ ░░░░░░ ░░░░   ░░░░░   \n", hl = "DashboardSnow" },
            { "   ██████╗ ███████╗ █████╗ ███╗   ███╗   \n", hl = "DashboardBeam" },
            { "   ██╔══██╗██╔════╝██╔══██╗████╗ ████║   \n", hl = "DashboardBeam" },
            { "   ██████╔╝█████╗  ███████║██╔████╔██║   \n", hl = "DashboardBeam" },
            { "   ██╔══██╗██╔══╝  ██╔══██║██║╚██╔╝██║   \n", hl = "DashboardBeam" },
            { "   ██████╔╝███████╗██║  ██║██║ ╚═╝ ██║   \n", hl = "DashboardBeam" },
            { "   ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝   \n", hl = "DashboardBeam" },
          },
          padding = 0,
          align = "center",
        },
        -- CAMPUS with snow (green)
        {
          text = {
            { " ░░░░░░░░ ░░░░░░ ░░░░   ░░░░░ ░░░░░░░░ ░░░   ░░░ ░░░░░░░░ \n", hl = "DashboardSnow" },
            { " ██████╗ █████╗ ███╗   ███╗██████╗ ██╗   ██╗███████╗ \n", hl = "DashboardCampus" },
            { "██╔════╝██╔══██╗████╗ ████║██╔══██╗██║   ██║██╔════╝ \n", hl = "DashboardCampus" },
            { "██║     ███████║██╔████╔██║██████╔╝██║   ██║███████╗ \n", hl = "DashboardCampus" },
            { "██║     ██╔══██║██║╚██╔╝██║██╔═══╝ ██║   ██║╚════██║ \n", hl = "DashboardCampus" },
            { "╚██████╗██║  ██║██║ ╚═╝ ██║██║     ╚██████╔╝███████║ \n", hl = "DashboardCampus" },
            { " ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝      ╚═════╝ ╚══════╝ \n", hl = "DashboardCampus" },
          },
          padding = 1,
          align = "center",
        },
        -- Christmas greeting
        {
          text = {
            { "    🎅  ", hl = "DashboardChristmas" },
            { "M E R R Y   C H R I S T M A S", hl = "DashboardChristmas" },
            { "  🎅    \n", hl = "DashboardChristmas" },
            { "       ", hl = "DashboardStar" },
            { "✨ Happy Holidays & Happy Coding! ✨", hl = "DashboardStar" },
            { "       \n", hl = "DashboardStar" },
          },
          padding = 1,
          align = "center",
        },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      },
    },

    -- Beautiful notifications with history
    notifier = {
      enabled = true,
      timeout = 3000,
      width = { min = 40, max = 0.4 },
      height = { min = 1, max = 0.6 },
      margin = { top = 0, right = 1, bottom = 0 },
      padding = true,
      sort = { "level", "added" },
      level = vim.log.levels.INFO,
      icons = {
        error = " ",
        warn = " ",
        info = " ",
        debug = " ",
        trace = " ",
      },
      style = "compact",
    },

    -- Enhanced terminal management
    terminal = {
      enabled = true,
      win = {
        position = "float",
        border = "rounded",
        width = 0.9,
        height = 0.9,
        backdrop = 60,
      },
    },

    -- Quick scratch buffers for notes/testing
    scratch = {
      enabled = true,
      name = "scratch",
      ft = function()
        if vim.bo.buftype == "" and vim.bo.filetype == "" then
          return "markdown"
        end
        return vim.bo.filetype
      end,
      icon = "󰃀",
      root = vim.fn.stdpath("data") .. "/scratch",
      autowrite = true,
      win = {
        position = "float",
        width = 0.8,
        height = 0.8,
      },
    },

    -- Fast file opening
    quickfile = {
      enabled = true,
    },

    -- Git integration for current line blame and more
    git = {
      enabled = true,
    },

    -- Better statuscolumn with git signs, diagnostics, folds
    statuscolumn = {
      enabled = true,
      left = { "mark", "sign" },
      right = { "fold", "git" },
      folds = {
        open = true,
        git_hl = false,
      },
      git = {
        patterns = { "GitSign", "MiniDiffSign" },
      },
      refresh = 50,
    },

    -- Smooth scrolling (DISABLED - was interfering with gg/G navigation)
    scroll = {
      enabled = false,
      animate = {
        duration = { step = 15, total = 250 },
        easing = "linear",
      },
      spamming = 10,
    },

    -- Word highlighting under cursor
    words = {
      enabled = true,
      debounce = 200,
      notify_jump = false,
      notify_end = false,
      foldopen = true,
      jumplist = true,
      modes = { "n" },
    },

    -- Zen mode for distraction-free writing
    zen = {
      enabled = true,
      toggles = {
        dim = true,
        git_signs = false,
        mini_diff_signs = false,
        diagnostics = false,
        inlay_hints = false,
      },
      show = {
        statusline = false,
        tabline = false,
      },
      win = {
        width = 120,
      },
      zoom = {
        toggles = {
          dim = false,
          git_signs = true,
          mini_diff_signs = true,
          diagnostics = true,
          inlay_hints = true,
        },
        show = {
          statusline = true,
          tabline = true,
        },
        win = {
          width = 0,
        },
      },
    },

    -- Useful input dialogs
    input = {
      enabled = true,
      icon = " ",
      win = {
        border = "rounded",
        relative = "cursor",
        row = 1,
        col = 0,
      },
    },

    -- Toggle UI elements quickly
    toggle = {
      enabled = true,
      which_key = true,
      notify = true,
      icon = { enabled = " ", disabled = " " },
      map = vim.keymap.set,
    },

    -- Indent guides
    indent = {
      enabled = true,
      char = "│",
      blank = " ",
      priority = 1,
      only_scope = false,
      only_current = false,
      hl = "SnacksIndent",
      scope = {
        enabled = true,
        hl = "SnacksIndentScope",
        char = "│",
      },
    },

    -- Scope visualization
    scope = {
      enabled = true,
      cursor = true,
      treesitter = {
        enabled = true,
      },
    },

    -- Bigfile handling for performance
    bigfile = {
      enabled = true,
      notify = true,
      size = 1.5 * 1024 * 1024, -- 1.5MB
      setup = function(ctx)
        vim.cmd([[NoMatchParen]])
        vim.schedule(function()
          vim.bo[ctx.buf].syntax = ctx.ft
        end)
      end,
    },

    -- Rename with preview
    rename = {
      enabled = true,
      notify = true,
    },

    -- Debugging helpers
    debug = {
      enabled = false,
    },

    -- Picker (alternative to telescope/fzf)
    picker = {
      enabled = false, -- Disabled since you're using fzf-lua
    },

    -- Animated windows
    win = {
      enabled = true,
      backdrop = {
        transparent = false,
        blend = 60,
      },
      border = "rounded",
    },

    styles = {
      notification = {
        border = "rounded",
        zindex = 100,
        ft = "markdown",
        wo = {
          winblend = 5,
          wrap = true,
          conceallevel = 2,
        },
        bo = { filetype = "snacks_notif" },
      },
      notification_history = {
        border = "rounded",
        zindex = 100,
        width = 0.6,
        height = 0.6,
        minimal = false,
        title = "Notification History",
        title_pos = "center",
        ft = "markdown",
        bo = { filetype = "snacks_notif_history" },
        wo = { winhighlight = "Normal:SnacksNotifierHistory" },
        keys = { q = "close" },
      },
    },
  },

  keys = {
    -- Terminal
    {
      "<leader>tt",
      function()
        Snacks.terminal()
      end,
      desc = "Toggle Terminal",
    },
    {
      "<leader>tg",
      function()
        Snacks.terminal("lazygit")
      end,
      desc = "Lazygit Terminal",
    },
    {
      "<leader>tG",
      function()
        Snacks.terminal("gitui")
      end,
      desc = "GitUI Terminal",
    },

    -- Scratch buffers
    {
      "<leader>.",
      function()
        Snacks.scratch()
      end,
      desc = "Toggle Scratch Buffer",
    },
    {
      "<leader>S",
      function()
        Snacks.scratch.select()
      end,
      desc = "Select Scratch Buffer",
    },

    -- Notifications
    {
      "<leader>un",
      function()
        Snacks.notifier.hide()
      end,
      desc = "Dismiss Notifications",
    },
    {
      "<leader>nh",
      function()
        Snacks.notifier.show_history()
      end,
      desc = "Notification History",
    },

    -- Git
    {
      "<leader>gb",
      function()
        Snacks.git.blame_line()
      end,
      desc = "Git Blame Line",
    },
    {
      "<leader>gB",
      function()
        Snacks.gitbrowse()
      end,
      desc = "Git Browse",
    },
    {
      "<leader>gf",
      function()
        Snacks.lazygit.log_file()
      end,
      desc = "Lazygit Log (current file)",
    },
    {
      "<leader>gl",
      function()
        Snacks.lazygit.log()
      end,
      desc = "Lazygit Log",
    },

    -- Zen mode
    {
      "<leader>z",
      function()
        Snacks.zen()
      end,
      desc = "Toggle Zen Mode",
    },
    {
      "<leader>Z",
      function()
        Snacks.zen.zoom()
      end,
      desc = "Toggle Zoom",
    },

    -- LSP Rename
    {
      "<leader>rn",
      function()
        Snacks.rename.rename_file()
      end,
      desc = "Rename File",
    },

    -- Words
    {
      "]]",
      function()
        Snacks.words.jump(vim.v.count1)
      end,
      desc = "Next Reference",
      mode = { "n", "t" },
    },
    {
      "[[",
      function()
        Snacks.words.jump(-vim.v.count1)
      end,
      desc = "Prev Reference",
      mode = { "n", "t" },
    },

    -- Buffers
    {
      "<leader>bd",
      function()
        Snacks.bufdelete()
      end,
      desc = "Delete Buffer",
    },
    {
      "<leader>bD",
      function()
        Snacks.bufdelete.other()
      end,
      desc = "Delete Other Buffers",
    },
  },

  init = function()
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      callback = function()
        -- Setup some globals for easier access
        _G.dd = function(...)
          Snacks.debug.inspect(...)
        end
        _G.bt = function()
          Snacks.debug.backtrace()
        end
        vim.print = _G.dd

        -- Create toggle shortcuts
        Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
        Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
        Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
        Snacks.toggle.diagnostics():map("<leader>ud")
        Snacks.toggle.line_number():map("<leader>ul")
        Snacks.toggle
          .option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 })
          :map("<leader>uc")
        Snacks.toggle.treesitter():map("<leader>uT")
        Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map("<leader>ub")
        Snacks.toggle.inlay_hints():map("<leader>uh")
        Snacks.toggle.indent():map("<leader>ug")
        Snacks.toggle.dim():map("<leader>uD")
      end,
    })
  end,
}
