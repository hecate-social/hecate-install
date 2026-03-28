{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.media = {
    enable = lib.mkEnableOption "Media apps (mpv, imv, cava)";
  };

  config = lib.mkIf config.services.hecate.desktop.media.enable {
    environment.systemPackages = with pkgs; [
      mpv                    # video player (keyboard-driven, lightweight)
      imv                    # Wayland-native image viewer
      cava                   # terminal audio visualizer
    ];
  };
}
