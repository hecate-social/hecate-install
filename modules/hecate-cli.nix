{ config, lib, pkgs, ... }:

let
  cfg = config.services.hecate;

  # The CLI is a bash script that talks to the daemon unix socket
  hecateCli = pkgs.callPackage ../packages/hecate-cli.nix { };
in
{
  options.services.hecate.cli = {
    enable = lib.mkEnableOption "hecate CLI";
  };

  config = lib.mkIf cfg.cli.enable {
    environment.systemPackages = [ hecateCli ];
  };
}
