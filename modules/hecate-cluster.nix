{ config, lib, ... }:

let
  cfg = config.services.hecate;
in
{
  options.services.hecate.cluster = {
    enable = lib.mkEnableOption "BEAM clustering (EPMD + Erlang distribution)";

    cookie = lib.mkOption {
      type = lib.types.str;
      default = "hecate_cluster_secret";
      description = "Erlang distribution cookie for BEAM clustering.";
    };

    peers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of peer hostnames or IPs for BEAM cluster formation.";
      example = [ "beam00.lab" "beam01.lab" "beam02.lab" "beam03.lab" ];
    };
  };

  # Cluster config is consumed by:
  # - hecate-gitops.nix (written to daemon .env as HECATE_ERLANG_COOKIE, HECATE_CLUSTER_PEERS)
  # - hecate-firewall.nix (opens EPMD 4369 + Erlang dist 9100)
  # No additional config needed here beyond declaring the options.
}
