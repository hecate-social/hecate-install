{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.browser = {
    enable = lib.mkEnableOption "Web browsers (Firefox + Zen)";
  };

  config = lib.mkIf config.services.hecate.desktop.browser.enable {
    # Firefox — always available as fallback
    programs.firefox.enable = true;

    # Zen Browser — installed via flake overlay (see flake.nix)
    # If the zen-browser overlay is not present, this is a no-op
    environment.systemPackages = lib.optionals (pkgs ? zen-browser) [
      pkgs.zen-browser
    ];
  };
}
