{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.editor = {
    enable = lib.mkEnableOption "Neovim (LazyVim) editor";
  };

  config = lib.mkIf config.services.hecate.desktop.editor.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };

    # LazyVim runtime dependencies
    environment.systemPackages = with pkgs; [
      gcc
      gnumake
      nodejs
      python3
      tree-sitter
      ripgrep
      fd
      luajit
      unzip
      cargo
    ];
  };
}
