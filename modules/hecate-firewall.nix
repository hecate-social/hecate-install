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
        # SSH is always allowed
        22

        # EPMD + Erlang distribution (cluster only)
        (lib.optionals cfg.cluster.enable [
          4369   # EPMD
          9100   # Erlang distribution
        ])

        # Ollama API (inference role or when ollama is enabled and exposed)
        (lib.optionals (cfg.ollama.enable && cfg.ollama.exposeNetwork) [
          11434
        ])
      ];

      allowedUDPPorts = [
        # Macula mesh QUIC
        4433

        # mDNS
        5353
      ];
    };
  };
}
