return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      -- Use the "night" style (darker than default)
      style = "night",

      -- Make the background even darker
      on_colors = function(colors)
        colors.bg = "#0f0f14"  -- Much darker background
        colors.bg_dark = "#0a0a0c"
        colors.bg_float = "#0f0f14"
        colors.bg_popup = "#0f0f14"
        colors.bg_sidebar = "#0f0f14"
        colors.bg_statusline = "#0f0f14"
      end,

      -- Additional styling options
      transparent = false,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
        functions = {},
        variables = {},
        sidebars = "dark",
        floats = "dark",
      },
      sidebars = { "qf", "help", "terminal", "packer" },
      day_brightness = 0.3,
      hide_inactive_statusline = false,
      dim_inactive = false,
      lualine_bold = true,
    },
  },

  -- Configure LazyVim to use tokyonight
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },
}
