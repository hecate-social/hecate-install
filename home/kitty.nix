{ config, lib, pkgs, ... }:

{
  programs.kitty = {
    enable = true;

    font = {
      name = "FiraCode Nerd Font";
      size = 12;
    };

    settings = {
      # Window
      remember_window_size = "no";
      initial_window_width = 950;
      initial_window_height = 500;
      hide_window_decorations = "yes";
      background_opacity = "0.9";
      dynamic_background_opacity = "yes";
      confirm_os_window_close = 0;
      window_padding_width = 10;

      # Cursor
      cursor_blink_interval = "0.5";
      cursor_stop_blinking_after = 1;

      # Scrollback
      scrollback_lines = 2000;
      wheel_scroll_min_lines = 1;

      # Audio
      enable_audio_bell = "no";

      # Emoji
      "symbol_map U+1F300-U+1FAF8" = "Noto Color Emoji";

      # ── Tokyo Night colors ────────────────────────────────────────
      foreground = "#c0caf5";
      background = "#0f0f14";
      selection_foreground = "#0f0f14";
      selection_background = "#33467c";

      cursor = "#c0caf5";
      cursor_text_color = "#0f0f14";

      url_color = "#7dcfff";

      active_border_color = "#7aa2f7";
      inactive_border_color = "#414868";
      bell_border_color = "#e0af68";

      wayland_titlebar_color = "system";

      active_tab_foreground = "#0f0f14";
      active_tab_background = "#7aa2f7";
      inactive_tab_foreground = "#c0caf5";
      inactive_tab_background = "#0a0a0c";
      tab_bar_background = "#0f0f14";

      # Marks
      mark1_foreground = "#0f0f14";
      mark1_background = "#7aa2f7";
      mark2_foreground = "#0f0f14";
      mark2_background = "#bb9af7";
      mark3_foreground = "#0f0f14";
      mark3_background = "#7dcfff";

      # 16 terminal colors
      color0 = "#15161e";
      color8 = "#414868";
      color1 = "#f7768e";
      color9 = "#f7768e";
      color2 = "#9ece6a";
      color10 = "#9ece6a";
      color3 = "#e0af68";
      color11 = "#e0af68";
      color4 = "#7aa2f7";
      color12 = "#7aa2f7";
      color5 = "#bb9af7";
      color13 = "#bb9af7";
      color6 = "#7dcfff";
      color14 = "#7dcfff";
      color7 = "#a9b1d6";
      color15 = "#c0caf5";
    };
  };
}
