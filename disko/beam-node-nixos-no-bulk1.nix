# Beam node disko layout WITHOUT bulk1 (for beam00 — only 1 HDD).
# eMMC: GPT → 512M ESP + rest ext4 root
# HDD:  GPT → XFS /bulk0
# NVMe: GPT → XFS /fast
{ lib, ... }:

{
  disko.devices = {
    disk = {
      # ── Boot disk (eMMC) ─────────────────────────────────────────────
      boot = {
        device = lib.mkDefault "/dev/mmcblk0";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };

      # ── Bulk HDD 0 ──────────────────────────────────────────────────
      bulk0 = {
        device = lib.mkDefault "/dev/sda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            bulk = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/bulk0";
                mountOptions = [ "nofail" "x-systemd.device-timeout=10" ];
              };
            };
          };
        };
      };

      # No bulk1 — beam00 has only 1 HDD

      # ── NVMe fast storage ─────────────────────────────────────────
      fast = {
        device = lib.mkDefault "/dev/nvme0n1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            fast = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/fast";
                mountOptions = [ "nofail" "x-systemd.device-timeout=10" ];
              };
            };
          };
        };
      };
    };
  };
}
