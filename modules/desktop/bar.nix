{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.bar = {
    enable = lib.mkEnableOption "Waybar status bar";
  };

  config = lib.mkIf config.services.hecate.desktop.bar.enable {
    environment.systemPackages = [ pkgs.waybar ];
  };
}
