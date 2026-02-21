{ config, lib, pkgs, ... }:

let
  cfg = config.services.hecate;
  reconcilerPkg = pkgs.callPackage ../packages/hecate-reconciler.nix { };
in
{
  options.services.hecate.reconciler = {
    enable = lib.mkEnableOption "hecate reconciler (watches gitops, manages Quadlet units)";
  };

  config = lib.mkIf cfg.reconciler.enable {
    # Reconciler + inotify-tools (runtime dep for watch mode)
    environment.systemPackages = [
      reconcilerPkg
      pkgs.inotify-tools
    ];

    systemd.user.services.hecate-reconciler = {
      description = "Hecate Reconciler (watches gitops, manages Quadlet units)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "default.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${reconcilerPkg}/bin/hecate-reconciler --watch";
        Restart = "on-failure";
        RestartSec = "10s";
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "hecate-reconciler";
      };

      environment = {
        HECATE_GITOPS_DIR = "%h/.hecate/gitops";
      };
    };
  };
}
