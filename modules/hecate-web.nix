{ config, lib, pkgs, ... }:

let
  cfg = config.services.hecate;
in
{
  options.services.hecate.web = {
    enable = lib.mkEnableOption "hecate-web desktop application (Tauri/WebKitGTK)";

    version = lib.mkOption {
      type = lib.types.str;
      default = "0.1.0";
      description = "Version of hecate-web to install from GitHub releases.";
    };
  };

  config = lib.mkIf cfg.web.enable {
    # WebKitGTK runtime dependency for Tauri v2
    environment.systemPackages = with pkgs; [
      webkitgtk_4_1
      gtk3
      glib
    ];

    # Desktop entry so it shows up in app launchers
    environment.etc."xdg/autostart/hecate-web.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Hecate
      Comment=Hecate Node Management
      Exec=hecate-web
      Icon=hecate
      Terminal=false
      Categories=System;Utility;
    '';
  };
}
