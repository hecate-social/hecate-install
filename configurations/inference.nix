{ config, lib, pkgs, ... }:

{
  imports = [
    ./base.nix
  ];

  # Inference: Ollama-only node (GPU server for the cluster)
  services.hecate = {
    # No daemon — this is a pure inference server
    daemon.enable = false;
    reconciler.enable = false;
    gitops.seedDaemon = false;

    ollama = {
      enable = true;
      exposeNetwork = true;  # Accessible from cluster nodes
      models = lib.mkDefault [ "llama3.2" ];
    };
  };
}
