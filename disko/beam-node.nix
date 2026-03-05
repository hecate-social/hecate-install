# Beam node: boot disk (eMMC) + bulk HDDs + NVMe fast storage
# Designed for Intel Celeron J4105 mini PCs (beam00-03).
#
# Usage: set device paths for boot, bulk0, bulk1, fast disks.
#   disko.devices.disk.boot.device   = "/dev/mmcblk0"   (eMMC)
#   disko.devices.disk.bulk0.device  = "/dev/sda"       (HDD)
#   disko.devices.disk.bulk1.device  = "/dev/sdb"       (HDD, optional)
#   disko.devices.disk.fast.device   = "/dev/nvme0n1"   (NVMe)
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

      # ── Bulk HDD 1 (optional — beam01-03 have 2 HDDs) ───────────────
      bulk1 = {
        device = lib.mkDefault "/dev/sdb";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            bulk = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/bulk1";
                mountOptions = [ "nofail" "x-systemd.device-timeout=10" ];
              };
            };
          };
        };
      };

      # ── NVMe fast storage ───────────────────────────────────────────
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
