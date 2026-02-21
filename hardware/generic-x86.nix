{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # ── Generic x86_64 ──────────────────────────────────────────────────
  # Works for most x86_64 hardware: desktops, laptops, mini PCs, servers

  boot = {
    initrd.availableKernelModules = [
      "ahci" "xhci_pci" "usb_storage" "sd_mod" "nvme"
      "virtio_pci" "virtio_blk" "virtio_scsi"  # VM support
    ];
    kernelModules = [ "kvm-intel" "kvm-amd" ];
  };

  # Filesystem: override per-node with actual disk layout
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  # Hardware detection
  hardware.enableRedistributableFirmware = true;
  networking.useDHCP = lib.mkDefault true;
}
