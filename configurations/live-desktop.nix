{ config, lib, pkgs, ... }:

let
  cfg = config.services.hecate;
  hecate-install = pkgs.callPackage ../packages/hecate-install-script.nix { };
in
{
  imports = [
    ./desktop.nix
    ../modules/hecate-branding.nix
    ../modules/hecate-installer.nix
  ];

  # ── Live desktop overrides ──────────────────────────────────────────────

  # Branding: Plymouth + GRUB + quiet boot
  services.hecate.branding.enable = true;

  # Remote desktop: wayvnc for VNC access
  services.hecate.desktop.remote-desktop.enable = true;

  # Installer script available (but not auto-running — this is "Try + Install")
  services.hecate.installer.enable = lib.mkForce false;
  environment.systemPackages = [ hecate-install ];

  # Bake the flake source into the ISO for nixos-install
  environment.etc."hecate-install".source = ../.;

  # ── Desktop entry for "Install hecatOS" ─────────────────────────────────
  environment.etc."xdg/autostart/hecatos-install.desktop".text = "";
  xdg.mime.enable = true;

  environment.etc."applications/hecatos-install.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Install hecatOS
    Comment=Install hecatOS to disk
    Exec=kitty --title "hecatOS Installer" -e sudo hecate-install --interactive
    Icon=system-software-install
    Terminal=false
    Categories=System;
    Keywords=install;setup;
  '';

  # ── Auto-login (no greeter for live ISO) ─────────────────────────────────
  services.greetd = {
    enable = lib.mkForce true;
    settings = {
      default_session = {
        command = lib.mkForce "Hyprland";
        user = lib.mkForce cfg.user;
      };
    };
  };

  # ── Disable idle-lock on live ISO ───────────────────────────────────────
  services.hecate.desktop.idle-lock.enable = lib.mkForce false;

  # ── Pre-load Ollama + daemon ────────────────────────────────────────────
  services.hecate.ollama.enable = lib.mkForce true;
  services.hecate.daemon.enable = lib.mkForce true;
  services.hecate.firstboot.enable = lib.mkForce false;

  # ── Live ISO hostname ──────────────────────────────────────────────────
  networking.hostName = lib.mkForce "hecatos-live";
}
