# Beam node disko layout for nixos-anywhere deployment.
# Same physical layout as beam-node.nix but designed for fresh NixOS install:
# - eMMC: wipe LVM, fresh GPT → 512M ESP + rest ext4 root
# - HDD/NVMe: reformat as XFS → /bulk0, /bulk1, /fast
#
# nixos-anywhere runs disko to partition before installing.
# All existing data is wiped.
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

      # ── Bulk HDD 1 (beam01-03 only, beam00 has 1 HDD) ────────────
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
