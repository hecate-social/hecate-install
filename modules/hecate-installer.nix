{ config, lib, pkgs, ... }:

let
  cfg = config.services.hecate.installer;

  hecate-install = pkgs.callPackage ../packages/hecate-install-script.nix { };
in
{
  options.services.hecate.installer = {
    enable = lib.mkEnableOption "hecatOS unattended installer (runs on TTY1 at boot)";

    mode = lib.mkOption {
      type = lib.types.enum [ "unattended" "interactive" ];
      default = "unattended";
      description = "Install mode: unattended (auto-detect, 10s countdown) or interactive (prompts).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Add install script to system PATH
    environment.systemPackages = [ hecate-install ];

    # Bake the entire flake source into the ISO at /etc/hecate-install/
    environment.etc."hecate-install".source = ../.;

    # Run the installer on TTY1 at boot
    systemd.services.hecate-installer = {
      description = "hecatOS Installer";
      after = [ "network-online.target" "systemd-udev-settle.service" ];
      wants = [ "network-online.target" "systemd-udev-settle.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;

        ExecStart = "${hecate-install}/bin/hecate-install --${cfg.mode}";

        StandardInput = "tty";
        StandardOutput = "tty";
        TTYPath = "/dev/tty1";
        TTYReset = true;
        TTYVHangup = true;
      };
    };

    # Auto-login to TTY1 is not needed — the service runs directly
    # Disable getty on TTY1 to avoid conflicts
    systemd.services."getty@tty1".enable = false;
  };
}
