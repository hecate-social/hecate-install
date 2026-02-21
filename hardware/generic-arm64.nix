{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # ── Generic ARM64 (RPi4, etc.) ──────────────────────────────────────

  boot = {
    initrd.availableKernelModules = [
      "usbhid" "usb_storage" "vc4" "pcie_brcmstb"
      "reset-raspberrypi" "mmc_block"
    ];

    # Use the RPi4 kernel if available
    kernelPackages = lib.mkDefault pkgs.linuxPackages_rpi4;

    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  # SD card filesystem layout
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  # RPi4 hardware
  hardware.enableRedistributableFirmware = true;
  networking.useDHCP = lib.mkDefault true;

  # GPU for video output
  hardware.graphics.enable = lib.mkDefault true;
}
