{ config, lib, pkgs, ... }:

{
  imports = [
    ./hyprland.nix
    ./kitty.nix
    ./zsh.nix
    ./starship.nix
    ./waybar.nix
    ./rofi.nix
    ./dunst.nix
    ./neovim.nix
    ./gtk.nix
    ./idle-lock.nix
  ];

  home.stateVersion = "24.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
