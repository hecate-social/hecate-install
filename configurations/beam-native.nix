{ config, lib, pkgs, ... }:

{
  imports = [
    ../modules/hecate-directories.nix
    ../modules/hecate-cluster.nix
    ../modules/hecate-mesh.nix
    ../modules/hecate-firewall.nix
    ../modules/hecate-daemon-native.nix
    ../modules/hecate-cli.nix
    ../modules/hecate-ollama.nix
    ../modules/hecate-secrets.nix
    ../modules/hecate-xrdp.nix
  ];

  # ── Nix ──────────────────────────────────────────────────────────────
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" ];
  };

  # ── No containers — native Erlang release ──────────────────────────
  services.hecate = {
    daemonNative.enable = true;
    cli.enable = true;
    xrdp.enable = true;

    cluster.enable = true;

    firewall.enable = lib.mkDefault true;

    ollama = {
      enable = lib.mkDefault false;
      exposeNetwork = false;
    };
  };

  # ── Users ──────────────────────────────────────────────────────────
  users.users.${config.services.hecate.user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    linger = true;
    # Allow password login for RDP
    initialPassword = "rl";
  };

  # ── Networking ─────────────────────────────────────────────────────
  networking = {
    hostName = lib.mkDefault "hecate-node";
    useNetworkd = true;
  };

  systemd.network.enable = true;

  # ── mDNS / Avahi ──────────────────────────────────────────────────
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  # ── SSH ────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = lib.mkDefault true;
      PermitRootLogin = lib.mkDefault "prohibit-password";
    };
  };

  # ── System packages ───────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    curl
    htop
    vim
    jq
  ];

  # ── Locale & Time ─────────────────────────────────────────────────
  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Boot ───────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  # NixOS release version
  system.stateVersion = "24.11";
}
