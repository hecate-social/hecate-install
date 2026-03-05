{ config, lib, pkgs, ... }:

{
  imports = [
    ./base.nix
    ../modules/hecate-installer.nix
  ];

  # ── Installer role ─────────────────────────────────────────────────────────
  # Minimal headless ISO that boots straight into the installer.
  # No desktop, no daemon — just the install engine.

  # Installer service runs on TTY1
  services.hecate.installer = {
    enable = true;
    mode = "unattended";
  };

  # Disable services that aren't needed during installation
  services.hecate.daemon.enable = lib.mkForce false;
  services.hecate.reconciler.enable = lib.mkForce false;
  services.hecate.cli.enable = lib.mkForce false;
  services.hecate.firstboot.enable = lib.mkForce false;
  services.hecate.ollama.enable = lib.mkForce false;
  services.hecate.web.enable = lib.mkForce false;
  services.hecate.secrets.enable = lib.mkForce false;

  # Installer hostname
  networking.hostName = lib.mkForce "hecatos-installer";

  # Add tools useful during installation
  environment.systemPackages = with pkgs; [
    parted
    dosfstools
    e2fsprogs
    xfsprogs
    pciutils
    usbutils
    lsof
  ];
}
