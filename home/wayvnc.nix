{ config, lib, pkgs, ... }:

{
  # wayvnc configuration file
  xdg.configFile."wayvnc/config".text = ''
    address=0.0.0.0
    port=5900
    enable_auth=false
  '';

  # Systemd user service — starts wayvnc after graphical session is ready
  systemd.user.services.wayvnc = {
    Unit = {
      Description = "wayvnc — VNC server for Wayland";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.wayvnc}/bin/wayvnc --config=%h/.config/wayvnc/config 0.0.0.0 5900";
      Restart = "on-failure";
      RestartSec = "5s";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
