{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop = {
    libreoffice.enable = lib.mkEnableOption "LibreOffice suite";
    obs.enable = lib.mkEnableOption "OBS Studio screen recording";
    thunderbird.enable = lib.mkEnableOption "Thunderbird email client";
    hacking-tools.enable = lib.mkEnableOption "Network analysis tools (nmap, wireshark, tcpdump)";
  };

  config = lib.mkMerge [
    (lib.mkIf config.services.hecate.desktop.libreoffice.enable {
      environment.systemPackages = [ pkgs.libreoffice ];
    })
    (lib.mkIf config.services.hecate.desktop.obs.enable {
      environment.systemPackages = [ pkgs.obs-studio ];
    })
    (lib.mkIf config.services.hecate.desktop.thunderbird.enable {
      environment.systemPackages = [ pkgs.thunderbird ];
    })
    (lib.mkIf config.services.hecate.desktop.hacking-tools.enable {
      environment.systemPackages = with pkgs; [
        nmap
        wireshark
        tcpdump
      ];
    })
  ];
}
