{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.remote-desktop = {
    enable = lib.mkEnableOption "Remote desktop access via wayvnc";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5900;
      description = "VNC listen port for wayvnc.";
    };
  };

  config = lib.mkIf config.services.hecate.desktop.remote-desktop.enable {
    environment.systemPackages = with pkgs; [
      wayvnc
    ];

    # Open VNC port in firewall
    networking.firewall.allowedTCPPorts = [
      config.services.hecate.desktop.remote-desktop.port
    ];
  };
}
