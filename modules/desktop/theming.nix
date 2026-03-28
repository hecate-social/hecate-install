{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.theming = {
    enable = lib.mkEnableOption "GTK/Qt theming (Tokyo Night)";
  };

  config = lib.mkIf config.services.hecate.desktop.theming.enable {
    environment.systemPackages = with pkgs; [
      # GTK theming
      tokyonight-gtk-theme
      adwaita-icon-theme
      papirus-icon-theme
      bibata-cursors

      # Qt theming (Kvantum for Tokyo Night consistency)
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
