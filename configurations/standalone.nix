{ config, lib, pkgs, ... }:

{
  imports = [
    ./base.nix
  ];

  # Standalone: full hecate stack on a single machine
  services.hecate = {
    daemon.enable = true;
    cli.enable = true;
    reconciler.enable = true;
    firstboot.enable = lib.mkDefault true;

    ollama = {
      enable = lib.mkDefault true;
      exposeNetwork = false;  # Local only
    };
  };
}
