{ config, lib, pkgs, ... }:

{
  # ── Hypridle ──────────────────────────────────────────────────────────
  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
        lock_cmd = pidof hyprlock || hyprlock
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on
    }

    # Screen lock
    listener {
        timeout = 600
        on-timeout = loginctl lock-session
    }

    # DPMS off
    listener {
        timeout = 660
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
    }

    # Suspend
    listener {
        timeout = 1800
        on-timeout = systemctl suspend
    }
  '';

  # ── Hyprlock ──────────────────────────────────────────────────────────
  xdg.configFile."hypr/hyprlock.conf".text = ''
    general {
        ignore_empty_input = true
    }

    background {
        monitor =
        path = ~/.config/hypr/wallpaper.png
        blur_passes = 3
        blur_size = 8
    }

    input-field {
        monitor =
        size = 200, 50
        outline_thickness = 3
        dots_size = 0.33
        dots_spacing = 0.15
        dots_center = true
        dots_rounding = -1
        outer_color = rgb(7aa2f7)
        inner_color = rgb(1a1b26)
        font_color = rgb(c0caf5)
        fade_on_empty = true
        fade_timeout = 1000
        placeholder_text = <i>Password...</i>
        hide_input = false
        rounding = -1
        check_color = rgb(9ece6a)
        fail_color = rgb(f7768e)
        fail_text = <i>$FAIL <b>($ATTEMPTS)</b></i>
        fail_transition = 300
        position = 0, -20
        halign = center
        valign = center
    }

    # Clock
    label {
        monitor =
        text = cmd[update:1000] echo "$TIME"
        color = rgba(c0caf5, 1.0)
        font_size = 55
        font_family = FiraCode Nerd Font
        position = -100, 70
        halign = right
        valign = bottom
        shadow_passes = 5
        shadow_size = 10
    }

    # Username
    label {
        monitor =
        text = $USER
        color = rgba(c0caf5, 1.0)
        font_size = 20
        font_family = FiraCode Nerd Font
        position = -100, 160
        halign = right
        valign = bottom
        shadow_passes = 5
        shadow_size = 10
    }
  '';
}
