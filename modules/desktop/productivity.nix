{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.productivity = {
    enable = lib.mkEnableOption "Productivity apps (zathura, qalculate, file-roller)";
  };

  config = lib.mkIf config.services.hecate.desktop.productivity.enable {
    environment.systemPackages = with pkgs; [
      zathura                # keyboard-driven PDF viewer
      qalculate-gtk          # powerful calculator
      file-roller            # archive manager (integrates with Nautilus)
    ];
  };
}
