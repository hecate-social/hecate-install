{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.prompt = {
    enable = lib.mkEnableOption "Starship prompt";
  };

  config = lib.mkIf config.services.hecate.desktop.prompt.enable {
    environment.systemPackages = [ pkgs.starship ];
  };
}
