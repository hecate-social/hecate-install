{ config, lib, pkgs, ... }:

{
  services.dunst = {
    enable = true;

    settings = {
      global = {
        monitor = 0;
        follow = "none";
        width = 300;
        height = "(0, 300)";
        origin = "top-center";
        offset = "30x30";
        notification_limit = 20;
        progress_bar = true;
        progress_bar_height = 10;
        progress_bar_corner_radius = 10;
        indicate_hidden = true;
        transparency = 30;
        separator_height = 2;
        padding = 8;
        horizontal_padding = 8;
        frame_width = 1;
        frame_color = "#ffffff";
        gap_size = 0;
        separator_color = "frame";
        sort = true;
        font = "Fira Sans Semibold 9";
        line_height = 1;
        markup = "full";
        format = "<b>%s</b>\\n%b";
        alignment = "left";
        vertical_alignment = "center";
        show_age_threshold = 60;
        ellipsize = "middle";
        stack_duplicates = true;
        hide_duplicate_count = false;
        show_indicators = true;
        enable_recursive_icon_lookup = true;
        icon_theme = "Papirus-Dark,Adwaita";
        icon_position = "left";
        min_icon_size = 32;
        max_icon_size = 128;
        sticky_history = true;
        history_length = 20;
        corner_radius = 10;
        force_xwayland = false;
        mouse_left_click = "close_current";
        mouse_middle_click = "do_action, close_current";
        mouse_right_click = "close_all";
      };

      urgency_low = {
        background = "#000000CC";
        foreground = "#888888";
        timeout = 6;
      };

      urgency_normal = {
        background = "#000000CC";
        foreground = "#ffffff";
        timeout = 6;
      };

      urgency_critical = {
        background = "#900000CC";
        foreground = "#ffffff";
        frame_color = "#ffffff";
        timeout = 6;
      };
    };
  };
}
