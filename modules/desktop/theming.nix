{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.theming = {
    enable = lib.mkEnableOption "GTK/Qt theming (Tokyo Night / Adwaita-dark)";
  };

  config = lib.mkIf config.services.hecate.desktop.theming.enable {
    environment.systemPackages = with pkgs; [
      # GTK theming
      adwaita-icon-theme
      papirus-icon-theme
      bibata-cursors

      # Qt theming
      libsForQt5.qt5ct
      qt6Packages.qt6ct
      libsForQt5.qtstyleplugin-kvantum
      qt6Packages.qtstyleplugin-kvantum
    ];

    # Qt platform theme
    qt = {
      enable = true;
      platformTheme = "qt5ct";
    };
  };
}
