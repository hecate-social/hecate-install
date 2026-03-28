{ config, lib, pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;

    settings = {
      "$mainMod" = "SUPER";

      monitor = [ ", preferred, auto, 1" ];

      input = {
        kb_layout = "us"; # Overridden at NixOS level via xkb.layout
        kb_options = "caps:escape";
        numlock_by_default = true;
        mouse_refocus = false;
        follow_mouse = 1;
        sensitivity = 0;

        touchpad = {
          natural_scroll = true;
          middle_button_emulation = true;
          disable_while_typing = true;
          scroll_factor = "1.0";
        };
      };

      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        "col.active_border" = "rgba(f97316ee) rgba(fbbf24ee) 45deg";
        "col.inactive_border" = "rgba(414868aa)";
        layout = "dwindle";
      };

      decoration = {
        rounding = 8;
        blur = {
          enabled = true;
          size = 5;
          passes = 3;
          new_optimizations = true;
        };
        shadow = {
          enabled = true;
          range = 8;
          render_power = 2;
          color = "rgba(1a1a1aee)";
        };
      };

      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };

      # ── Autostart ───────────────────────────────────────────────────
      exec-once = [
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
        "dunst"
        "hypridle"
        "waybar"
        "hyprpaper"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "nm-applet --indicator"
        "udiskie --automount --notify --tray"
      ];

      # ── Keybindings ─────────────────────────────────────────────────
      bind = let s = "~/.config/hypr/scripts"; in [
        # ── Applications ─────────────────────────────────────────────
        "$mainMod, Return, exec, kitty"                                          # Terminal
        "$mainMod, B, exec, zen-browser || firefox"                              # Browser
        "$mainMod, E, exec, nautilus"                                            # File manager
        "$mainMod CTRL, E, exec, rofimoji"                                       # Emoji picker
        "$mainMod CTRL, Return, exec, pkill rofi || rofi -show drun -replace -i" # App launcher
        "$mainMod, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy" # Clipboard

        # ── Windows ──────────────────────────────────────────────────
        "$mainMod, Q, killactive"                          # Kill active window
        "$mainMod, F, fullscreen"                          # Fullscreen
        "$mainMod, T, togglefloating"                      # Toggle floating
        "$mainMod SHIFT, T, exec, ${s}/toggleallfloat.sh"  # Toggle ALL floating
        "$mainMod, J, togglesplit"                         # Toggle split
        "$mainMod, K, swapsplit"                           # Swap split
        "$mainMod, G, togglegroup"                         # Toggle group

        # ── Focus ────────────────────────────────────────────────────
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"

        # ── Resize ───────────────────────────────────────────────────
        "$mainMod SHIFT, right, resizeactive, 100 0"
        "$mainMod SHIFT, left, resizeactive, -100 0"
        "$mainMod SHIFT, down, resizeactive, 0 100"
        "$mainMod SHIFT, up, resizeactive, 0 -100"

        # ── Screenshots ──────────────────────────────────────────────
        "$mainMod SHIFT, S, exec, grim -g \"$(slurp)\" - | wl-copy"              # Area → clipboard
        "$mainMod, PRINT, exec, grim - | wl-copy"                                # Full → clipboard
        "$mainMod SHIFT, PRINT, exec, grim -g \"$(slurp)\" - | satty --filename -" # Area → annotate

        # ── Screen Recording ─────────────────────────────────────────
        "$mainMod, R, exec, ${s}/toggle-recording.sh"                    # Toggle recording (rofi menu)

        # ── Utilities ────────────────────────────────────────────────
        "$mainMod SHIFT, C, exec, hyprpicker -a"                                 # Color picker
        "$mainMod, C, exec, qalculate-gtk"                                       # Calculator
        "$mainMod, Z, exec, kitty --title btop -e btop"                          # System monitor
        "$mainMod, M, exec, kitty --title cava -e cava"                          # Audio visualizer
        "$mainMod CTRL, K, exec, ${s}/keybindings.sh"                    # Show keybindings
        "$mainMod CTRL, Q, exec, wlogout"                                        # Logout menu
        "$mainMod CTRL, R, exec, hyprctl reload"                                 # Reload config
        "$mainMod SHIFT, A, exec, ${s}/toggle-animations.sh"             # Toggle animations
        "$mainMod ALT, G, exec, ${s}/gamemode.sh"                        # Toggle game mode
        "$mainMod SHIFT, I, exec, kitty --title 'hecatOS Installer' -e sudo hecate-install --interactive"

        # ── Waybar ───────────────────────────────────────────────────
        "$mainMod SHIFT, B, exec, ~/.config/waybar/launch.sh"                    # Reload waybar
        "$mainMod CTRL, B, exec, ~/.config/waybar/toggle.sh"                     # Toggle waybar
        "$mainMod CTRL, T, exec, ~/.config/waybar/themeswitcher.sh"              # Waybar themes

        # ── Workspaces ───────────────────────────────────────────────
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"

        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"

        # Move ALL windows to workspace
        "$mainMod CTRL, 1, exec, ${s}/moveTo.sh 1"
        "$mainMod CTRL, 2, exec, ${s}/moveTo.sh 2"
        "$mainMod CTRL, 3, exec, ${s}/moveTo.sh 3"
        "$mainMod CTRL, 4, exec, ${s}/moveTo.sh 4"
        "$mainMod CTRL, 5, exec, ${s}/moveTo.sh 5"
        "$mainMod CTRL, 6, exec, ${s}/moveTo.sh 6"
        "$mainMod CTRL, 7, exec, ${s}/moveTo.sh 7"
        "$mainMod CTRL, 8, exec, ${s}/moveTo.sh 8"
        "$mainMod CTRL, 9, exec, ${s}/moveTo.sh 9"
        "$mainMod CTRL, 0, exec, ${s}/moveTo.sh 10"

        "$mainMod, Tab, workspace, m+1"
        "$mainMod SHIFT, Tab, workspace, m-1"
        "$mainMod CTRL, down, workspace, empty"

        # ── Fn Keys ──────────────────────────────────────────────────
        ", XF86MonBrightnessUp, exec, brightnessctl -q s +10%"
        ", XF86MonBrightnessDown, exec, brightnessctl -q s 10%-"
        ", XF86AudioRaiseVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ +5%"
        ", XF86AudioLowerVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ -5%"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPause, exec, playerctl pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
        ", XF86AudioMicMute, exec, pactl set-source-mute @DEFAULT_SOURCE@ toggle"
        ", XF86Lock, exec, hyprlock"
        ", XF86Calculator, exec, qalculate-gtk"

        # Mouse scroll workspaces
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
      ];

      # Mouse bindings
      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];
    };
  };

  # ── Hyprland scripts ──────────────────────────────────────────────────
  xdg.configFile."hypr/scripts/toggle-recording.sh" = {
    source = ../dotfiles/hypr/scripts/toggle-recording.sh;
    executable = true;
  };
  xdg.configFile."hypr/scripts/keybindings.sh" = {
    source = ../dotfiles/hypr/scripts/keybindings.sh;
    executable = true;
  };
  xdg.configFile."hypr/scripts/toggleallfloat.sh" = {
    source = ../dotfiles/hypr/scripts/toggleallfloat.sh;
    executable = true;
  };
  xdg.configFile."hypr/scripts/gamemode.sh" = {
    source = ../dotfiles/hypr/scripts/gamemode.sh;
    executable = true;
  };
  xdg.configFile."hypr/scripts/moveTo.sh" = {
    source = ../dotfiles/hypr/scripts/moveTo.sh;
    executable = true;
  };
  xdg.configFile."hypr/scripts/toggle-animations.sh" = {
    source = ../dotfiles/hypr/scripts/toggle-animations.sh;
    executable = true;
  };

  # ── Hyprpaper (wallpaper) ─────────────────────────────────────────────
  xdg.configFile."hypr/hyprpaper.conf".text = ''
    preload = ~/.config/hypr/wallpaper.png
    wallpaper = , ~/.config/hypr/wallpaper.png
    splash = false
  '';

  # Ship the default wallpaper
  xdg.configFile."hypr/wallpaper.png".source = ../dotfiles/wallpapers/default.png;
}
