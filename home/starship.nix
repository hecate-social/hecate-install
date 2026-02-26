{ config, lib, pkgs, ... }:

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  # Ship the full starship.toml verbatim — too complex to translate to Nix
  xdg.configFile."starship.toml".source = ../dotfiles/starship.toml;
}
