{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.idle-lock = {
    enable = lib.mkEnableOption "Hypridle + Hyprlock (idle/lock screen)";

    lockTimeout = lib.mkOption {
      type = lib.types.int;
      default = 600;
      description = "Seconds of inactivity before locking the screen.";
    };

    dpmsTimeout = lib.mkOption {
      type = lib.types.int;
      default = 660;
      description = "Seconds of inactivity before turning off displays.";
    };

    suspendTimeout = lib.mkOption {
      type = lib.types.int;
      default = 1800;
      description = "Seconds of inactivity before suspending.";
    };
  };

  config = lib.mkIf config.services.hecate.desktop.idle-lock.enable {
    # hypridle + hyprlock are installed via hyprland module
    security.pam.services.hyprlock = { };
  };
}
