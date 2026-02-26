{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.launcher = {
    enable = lib.mkEnableOption "Rofi application launcher";
  };

  config = lib.mkIf config.services.hecate.desktop.launcher.enable {
    environment.systemPackages = with pkgs; [
      rofi-wayland
      rofimoji
    ];
  };
}
