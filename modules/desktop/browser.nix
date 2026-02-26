{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.browser = {
    enable = lib.mkEnableOption "Firefox browser";
  };

  config = lib.mkIf config.services.hecate.desktop.browser.enable {
    programs.firefox.enable = true;
  };
}
