{ config, lib, pkgs, ... }:

let
  cfg = config.services.hecate.xrdp;
in
{
  options.services.hecate.xrdp = {
    enable = lib.mkEnableOption "XFCE desktop with xrdp remote access";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3389;
      description = "TCP port for xrdp connections.";
    };
  };

  config = lib.mkIf cfg.enable {
    # ── X11 + XFCE ──────────────────────────────────────────────────────
    services.xserver = {
      enable = true;
      desktopManager.xfce.enable = true;
      displayManager.lightdm.enable = true;
    };

    # ── xrdp ─────────────────────────────────────────────────────────────
    services.xrdp = {
      enable = true;
      defaultWindowManager = "xfce4-session";
      port = cfg.port;
      openFirewall = true;
    };

    # ── Useful desktop packages ──────────────────────────────────────────
    environment.systemPackages = with pkgs; [
      xfce.xfce4-terminal
      firefox
    ];
  };
}
