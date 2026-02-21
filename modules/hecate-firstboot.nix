{ config, lib, pkgs, ... }:

let
  cfg = config.services.hecate;

  firstbootScript = pkgs.writeShellScriptBin "hecate-firstboot" (builtins.readFile ../firstboot/firstboot.sh);
in
{
  options.services.hecate.firstboot = {
    enable = lib.mkEnableOption "hecate firstboot wizard (QR code pairing)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 80;
      description = "HTTP port for the firstboot pairing web UI.";
    };
  };

  config = lib.mkIf cfg.firstboot.enable {
    # Allow the firstboot HTTP port through firewall
    networking.firewall.allowedTCPPorts = [ cfg.firstboot.port ];

    # Firstboot runs only if the node has never been configured
    systemd.services.hecate-firstboot = {
      description = "Hecate Firstboot Wizard (pairing + initial config)";
      after = [ "network-online.target" "avahi-daemon.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      unitConfig = {
        # Only run if not yet configured
        ConditionPathExists = "!${cfg.dataDir}/.configured";
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${firstbootScript}/bin/hecate-firstboot";
        Restart = "on-failure";
        RestartSec = "5s";

        # Run as the hecate user
        User = cfg.user;
        Group = cfg.group;

        # Allow binding to port 80
        AmbientCapabilities = lib.mkIf (cfg.firstboot.port < 1024) "CAP_NET_BIND_SERVICE";
      };

      environment = {
        HECATE_DIR = cfg.dataDir;
        FIRSTBOOT_PORT = toString cfg.firstboot.port;
        FIRSTBOOT_HTML = "${../firstboot/index.html}";
      };
    };
  };
}
