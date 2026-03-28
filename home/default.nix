{ config, lib, pkgs, ... }:

{
  imports = [
    ./hyprland.nix
    ./kitty.nix
    ./zsh.nix
    ./starship.nix
    ./waybar.nix
    ./rofi.nix
    ./dunst.nix
    ./neovim.nix
    ./gtk.nix
    ./idle-lock.nix
    ./wayvnc.nix
    ./fastfetch.nix
  ];

  home.stateVersion = "24.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # ── Default applications ────────────────────────────────────────────────
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # PDF → zathura
      "application/pdf" = "org.pwmt.zathura.desktop";
      # Images → imv
      "image/png" = "imv.desktop";
      "image/jpeg" = "imv.desktop";
      "image/gif" = "imv.desktop";
      "image/webp" = "imv.desktop";
      "image/svg+xml" = "imv.desktop";
      # Video → mpv
      "video/mp4" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/x-msvideo" = "mpv.desktop";
      # Audio → mpv
      "audio/mpeg" = "mpv.desktop";
      "audio/flac" = "mpv.desktop";
      "audio/ogg" = "mpv.desktop";
      # Archives → file-roller
      "application/zip" = "org.gnome.FileRoller.desktop";
      "application/x-tar" = "org.gnome.FileRoller.desktop";
      "application/gzip" = "org.gnome.FileRoller.desktop";
      "application/x-7z-compressed" = "org.gnome.FileRoller.desktop";
    };
  };
}
