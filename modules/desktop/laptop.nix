{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.laptop = {
    enable = lib.mkEnableOption "Laptop optimizations (power management, battery, lid)";
  };

  config = lib.mkIf config.services.hecate.desktop.laptop.enable {
    # ── CPU frequency scaling ───────────────────────────────────────────
    services.auto-cpufreq = {
      enable = true;
      settings = {
        battery = {
          governor = "powersave";
          turbo = "never";
        };
        charger = {
          governor = "performance";
          turbo = "auto";
        };
      };
    };

    # ── Power profiles (performance / balanced / power-saver) ───────────
    services.power-profiles-daemon.enable = false; # conflicts with auto-cpufreq

    # ── Thermal management ──────────────────────────────────────────────
    services.thermald.enable = true;

    # ── Lid switch behavior ─────────────────────────────────────────────
    services.logind = {
      lidSwitch = "suspend";
      lidSwitchExternalPower = "lock";
      lidSwitchDocked = "ignore";
    };

    # ── Backlight persistence ───────────────────────────────────────────
    hardware.brillo.enable = true;

    # ── Battery charge thresholds (where supported) ─────────────────────
    # Most ThinkPads and some ASUS/Dell support this
    # Uncomment and adjust per-hardware:
    # services.upower.enable = true;

    environment.systemPackages = with pkgs; [
      powertop               # power consumption analyzer
      acpi                   # battery status CLI
    ];
  };
}
