{ config, lib, pkgs, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    terminal = "kitty";
  };

  # Ship Tokyo Night theme
  xdg.configFile."rofi/config.rasi".source = ../dotfiles/rofi/config.rasi;
  xdg.configFile."rofi/tokyo-night.rasi".source = ../dotfiles/rofi/tokyo-night.rasi;
}
