{ config, lib, pkgs, ... }:

{
  imports = [
    ./standalone.nix
  ];

  # Workstation: standalone + desktop app
  services.hecate = {
    web.enable = true;
    firstboot.enable = false;  # Workstations are configured interactively
  };

  # Desktop environment basics (user can override with full DE)
  services.xserver.enable = lib.mkDefault true;

  # Audio (for notification sounds)
  services.pipewire = {
    enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
  };
}
