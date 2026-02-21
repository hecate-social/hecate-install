{ config, lib, pkgs, ... }:

{
  imports = [
    ../modules/hecate-directories.nix
    ../modules/hecate-cluster.nix
    ../modules/hecate-mesh.nix
    ../modules/hecate-reconciler.nix
    ../modules/hecate-gitops.nix
    ../modules/hecate-firewall.nix
    ../modules/hecate-daemon.nix
    ../modules/hecate-cli.nix
    ../modules/hecate-ollama.nix
    ../modules/hecate-secrets.nix
    ../modules/hecate-firstboot.nix
    ../modules/hecate-web.nix
  ];

  # ── Nix ──────────────────────────────────────────────────────────────
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Allow the rl user to manage nix
    trusted-users = [ "root" "@wheel" ];
  };

  # ── Podman ───────────────────────────────────────────────────────────
  virtualisation.podman = {
    enable = true;
    # Quadlet support (generates systemd units from .container files)
    defaultNetwork.settings.dns_enabled = true;
  };

  # ── Users ────────────────────────────────────────────────────────────
  users.users.rl = {
    isNormalUser = true;
    extraGroups = [ "wheel" "podman" ];
    # Enable lingering so user services run without login
    linger = true;
  };

  # ── Networking ───────────────────────────────────────────────────────
  networking = {
    # Default hostname; overridden per-node via hardware profiles
    hostName = lib.mkDefault "hecate-node";

    # Enable resolved for DNS
    useNetworkd = true;
  };

  systemd.network.enable = true;

  # ── mDNS / Avahi ────────────────────────────────────────────────────
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  # ── Firewall (role-aware, enabled by default) ───────────────────────
  services.hecate.firewall.enable = lib.mkDefault true;

  # ── SSH ──────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = lib.mkDefault true;
      PermitRootLogin = lib.mkDefault "prohibit-password";
    };
  };

  # ── System packages ─────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    curl
    htop
    vim
    jq
  ];

  # ── Locale & Time ───────────────────────────────────────────────────
  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Boot ─────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  # NixOS release version
  system.stateVersion = "24.11";
}
