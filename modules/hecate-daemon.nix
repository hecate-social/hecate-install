{ config, lib, pkgs, ... }:

let
  cfg = config.services.hecate;
in
{
  options.services.hecate.daemon = {
    enable = lib.mkEnableOption "hecate daemon (OCI container via Quadlet)";

    version = lib.mkOption {
      type = lib.types.str;
      default = "0.8.1";
      description = "Version tag for the hecate-daemon OCI image on ghcr.io.";
    };
  };

  config = lib.mkIf cfg.daemon.enable {
    # Podman is required for running the daemon container
    virtualisation.podman.enable = true;

    # Ensure gitops seeds the daemon Quadlet files
    services.hecate.gitops.seedDaemon = true;

    # Ensure reconciler is enabled to pick up the Quadlet files
    services.hecate.reconciler.enable = true;
  };
}
