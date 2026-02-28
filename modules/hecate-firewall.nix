{ config, lib, ... }:

let
  cfg = config.services.hecate;
in
{
  options.services.hecate.firewall = {
    enable = lib.mkEnableOption "hecate role-aware firewall rules";
  };

  config = lib.mkIf cfg.firewall.enable {
    networking.firewall = {
      enable = true;

      allowedTCPPorts = lib.flatten [
        # SSH — remote management access; keeps you from being locked out
        # when the firewall activates
        22

        # Cluster only: BEAM nodes must discover each other (EPMD) and
        # communicate (distribution) to form a distributed Erlang cluster
        (lib.optionals cfg.cluster.enable [
          4369   # EPMD — lets Erlang nodes find each other for clustering
          9100   # Erlang distribution — inter-node communication for BEAM clustering
        ])

        # Inference role: lets other nodes send LLM inference requests
        (lib.optionals (cfg.ollama.enable && cfg.ollama.exposeNetwork) [
          11434  # Ollama API — serves LLM inference requests from the cluster
        ])
      ];

      allowedUDPPorts = [
        # Macula mesh — peer-to-peer discovery and communication between
        # Hecate nodes over QUIC
        4433

        # mDNS — local network service discovery
        5353
      ];
    };
  };
}
