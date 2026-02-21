{ config, lib, pkgs, ... }:

{
  imports = [
    ./base.nix
  ];

  # Cluster: BEAM clustering with peers
  services.hecate = {
    daemon.enable = true;
    cli.enable = true;
    reconciler.enable = true;
    firstboot.enable = lib.mkDefault true;

    cluster = {
      enable = true;
      # Override these per-node:
      #   cookie = "your_erlang_cookie";
      #   peers = [ "beam00.lab" "beam01.lab" "beam02.lab" "beam03.lab" ];
    };

    ollama = {
      enable = lib.mkDefault false;
      exposeNetwork = false;
    };
  };
}
