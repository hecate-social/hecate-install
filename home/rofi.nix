{ config, lib, pkgs, ... }:

{
  # Use rofi-wayland but manage config manually (Tokyo Night theme)
  home.packages = [ pkgs.rofi-wayland ];

  xdg.configFile."rofi/config.rasi".source = ../dotfiles/rofi/config.rasi;
  xdg.configFile."rofi/tokyo-night.rasi".source = ../dotfiles/rofi/tokyo-night.rasi;
}
