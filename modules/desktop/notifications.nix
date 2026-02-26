{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.notifications = {
    enable = lib.mkEnableOption "Dunst notification daemon";
  };

  config = lib.mkIf config.services.hecate.desktop.notifications.enable {
    environment.systemPackages = with pkgs; [
      dunst
      libnotify
    ];
  };
}
