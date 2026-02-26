{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.shell = {
    enable = lib.mkEnableOption "Zsh shell with plugins";
  };

  config = lib.mkIf config.services.hecate.desktop.shell.enable {
    programs.zsh = {
      enable = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
    };

    environment.systemPackages = with pkgs; [
      oh-my-zsh
      fastfetch
    ];
  };
}
