{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # ── Intel Celeron J4105 (beam00-03) ──────────────────────────────────
  # Mini PCs with eMMC boot, HDD bulk storage, optional NVMe fast storage

  boot = {
    initrd.availableKernelModules = [
      "ahci" "xhci_pci" "usb_storage" "sd_mod" "sdhci_pci"
      "nvme" "mmc_block"
    ];
    kernelModules = [ "kvm-intel" ];

    # Low-memory tuning for 16-32GB nodes
    kernel.sysctl = {
      "vm.swappiness" = 10;
      "vm.dirty_ratio" = 15;
      "vm.dirty_background_ratio" = 5;
    };
  };

  # ── Filesystem layout ───────────────────────────────────────────────
  # eMMC boot (mmcblk0): /, /boot, /boot/efi
  # Override these per-node with the actual UUIDs/labels.

  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/boot";
    fsType = "ext4";
  };

  fileSystems."/boot/efi" = lib.mkDefault {
    device = "/dev/disk/by-label/EFI";
    fsType = "vfat";
  };

  # HDD bulk storage (override per-node based on actual disk count)
  fileSystems."/bulk0" = lib.mkDefault {
    device = "/dev/disk/by-label/bulk0";
    fsType = "xfs";
    options = [ "nofail" "x-systemd.device-timeout=10" ];
  };

  # Optional: second HDD (beam01-03 have 2x HDD)
  # fileSystems."/bulk1" = {
  #   device = "/dev/disk/by-label/bulk1";
  #   fsType = "xfs";
  #   options = [ "nofail" "x-systemd.device-timeout=10" ];
  # };

  # NVMe fast storage
  fileSystems."/fast" = lib.mkDefault {
    device = "/dev/disk/by-label/fast";
    fsType = "xfs";
    options = [ "nofail" "x-systemd.device-timeout=10" ];
  };

  # Swap (small, eMMC-friendly)
  swapDevices = lib.mkDefault [ ];

  # ── Hardware ─────────────────────────────────────────────────────────
  hardware.cpu.intel.updateMicrocode = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  # ── Networking ───────────────────────────────────────────────────────
  # beam00 uses enp2s0, beam01-03 use enp3s0 — override per-node
  networking.useDHCP = lib.mkDefault true;
}
