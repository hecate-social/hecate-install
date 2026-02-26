{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.terminal = {
    enable = lib.mkEnableOption "Kitty terminal emulator";
  };

  config = lib.mkIf config.services.hecate.desktop.terminal.enable {
    environment.systemPackages = [ pkgs.kitty ];
  };
}
