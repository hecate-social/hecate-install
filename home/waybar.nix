{ config, lib, pkgs, ... }:

{
  programs.waybar = {
    enable = true;
    # Don't use systemd — Hyprland exec-once handles waybar lifecycle
    systemd.enable = false;
  };

  # Ship config files from dotfiles/
  xdg.configFile."waybar/config".source = ../dotfiles/waybar/config;
  xdg.configFile."waybar/style.css".source = ../dotfiles/waybar/style.css;
}
