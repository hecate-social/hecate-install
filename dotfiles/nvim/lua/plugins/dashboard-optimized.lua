-- NOTE: Snacks.nvim dashboard is now available as an alternative
-- See lua/plugins/snacks.lua for the new dashboard configuration
-- To switch, disable this plugin and enable snacks dashboard

return {
  "goolord/alpha-nvim",
  enabled = true, -- Christmas theme enabled!
  event = "VimEnter",
  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")

    -- Define Christmas highlight groups
    vim.api.nvim_set_hl(0, "DashboardSnow", { fg = "#ffffff" })       -- White snow
    vim.api.nvim_set_hl(0, "DashboardBeam", { fg = "#7aa2f7" })       -- Blue BEAM
    vim.api.nvim_set_hl(0, "DashboardCampus", { fg = "#9ece6a" })     -- Green CAMPUS
    vim.api.nvim_set_hl(0, "DashboardChristmas", { fg = "#f7768e" })  -- Red Christmas
    vim.api.nvim_set_hl(0, "DashboardGold", { fg = "#e0af68" })       -- Gold stars

    -- Snowfall decoration
    local snow_section = {
      type = "text",
      val = {
        "          ❄  *  ❄     ✨     ❄  *  ❄          ",
        "     *    ❄    🎄    ★    🎄    ❄    *     ",
        "  ❄      *      ❄      *      ❄      *      ❄  ",
      },
      opts = {
        position = "center",
        hl = "DashboardSnow",
      },
    }

    -- BEAM letters (blue)
    local beam_section = {
      type = "text",
      val = {
        "   ██████╗ ███████╗ █████╗ ███╗   ███╗   ",
        "   ██╔══██╗██╔════╝██╔══██╗████╗ ████║   ",
        "   ██████╔╝█████╗  ███████║██╔████╔██║   ",
        "   ██╔══██╗██╔══╝  ██╔══██║██║╚██╔╝██║   ",
        "   ██████╔╝███████╗██║  ██║██║ ╚═╝ ██║   ",
        "   ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝   ",
      },
      opts = {
        position = "center",
        hl = "DashboardBeam",
      },
    }

    -- CAMPUS letters (green)
    local campus_section = {
      type = "text",
      val = {
        " ██████╗ █████╗ ███╗   ███╗██████╗ ██╗   ██╗███████╗ ",
        "██╔════╝██╔══██╗████╗ ████║██╔══██╗██║   ██║██╔════╝ ",
        "██║     ███████║██╔████╔██║██████╔╝██║   ██║███████╗ ",
        "██║     ██╔══██║██║╚██╔╝██║██╔═══╝ ██║   ██║╚════██║ ",
        "╚██████╗██║  ██║██║ ╚═╝ ██║██║     ╚██████╔╝███████║ ",
        " ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝      ╚═════╝ ╚══════╝ ",
      },
      opts = {
        position = "center",
        hl = "DashboardCampus",
      },
    }

    -- Christmas greeting (red)
    local christmas_section = {
      type = "text",
      val = {
        "                                                 ",
        "    🎅  M E R R Y   C H R I S T M A S  🎅    ",
      },
      opts = {
        position = "center",
        hl = "DashboardChristmas",
      },
    }

    -- Holiday tagline (gold)
    local tagline_section = {
      type = "text",
      val = {
        "      ✨ Happy Holidays & Happy Coding! ✨      ",
        "                                                 ",
      },
      opts = {
        position = "center",
        hl = "DashboardGold",
      },
    }

    -- Buttons
    dashboard.section.buttons.val = {
      dashboard.button("f", " " .. " Find file", function()
        require("lazy").load({ plugins = { "fzf-lua" } })
        vim.cmd("FzfLua files")
      end),
      dashboard.button("n", " " .. " New file", ":ene <BAR> startinsert <CR>"),
      dashboard.button("r", " " .. " Recent files", function()
        require("lazy").load({ plugins = { "fzf-lua" } })
        vim.cmd("FzfLua oldfiles")
      end),
      dashboard.button("g", " " .. " Find text", function()
        require("lazy").load({ plugins = { "fzf-lua" } })
        vim.cmd("FzfLua live_grep")
      end),
      dashboard.button("c", " " .. " Config", ":e $MYVIMRC <CR>"),
      dashboard.button("s", " " .. " Restore Session", function()
        require("persistence").load()
      end),
      dashboard.button("l", "󰒲 " .. " Lazy", ":Lazy<CR>"),
      dashboard.button("q", " " .. " Quit", ":qa<CR>"),
    }

    dashboard.section.footer.val = "🎄 Neovim"
    dashboard.section.footer.opts.hl = "DashboardSnow"
    dashboard.section.buttons.opts.hl = "Keyword"

    -- Christmas layout
    local config = {
      layout = {
        { type = "padding", val = 1 },
        snow_section,
        { type = "padding", val = 1 },
        beam_section,
        campus_section,
        { type = "padding", val = 1 },
        christmas_section,
        tagline_section,
        { type = "padding", val = 1 },
        dashboard.section.buttons,
        { type = "padding", val = 1 },
        dashboard.section.footer,
      },
      opts = {
        margin = 5,
      },
    }

    alpha.setup(config)
  end,
  dependencies = { "nvim-tree/nvim-web-devicons" },
}