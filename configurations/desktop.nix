{ config, lib, pkgs, ... }:

let
  cfg = config.services.hecate;
in
{
  imports = [
    ./standalone.nix
    ../modules/hecate-desktop.nix
  ];

  # ── Desktop user ──────────────────────────────────────────────────────
  # Override the default "rl" user for distributable ISOs
  services.hecate.user = lib.mkDefault "hecate";

  # Desktop hostname
  networking.hostName = lib.mkDefault "hecate-desktop";

  # Desktop doesn't use firstboot wizard — user configures interactively
  services.hecate.firstboot.enable = lib.mkForce false;

  # Enable the full desktop module tree
  services.hecate.desktop.enable = true;

  # ── Login Manager (greetd + tuigreet) ─────────────────────────────────
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --remember-session --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  # ── Networking: Desktop uses NetworkManager ───────────────────────────
  # Override base.nix systemd-networkd with NetworkManager for Wi-Fi
  networking.useNetworkd = lib.mkForce false;
  systemd.network.enable = lib.mkForce false;
  networking.networkmanager.enable = true;
  users.users.${cfg.user}.extraGroups = [ "wheel" "podman" "networkmanager" ];

  # ── Audio ─────────────────────────────────────────────────────────────
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # ── Bluetooth ─────────────────────────────────────────────────────────
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # ── XDG Desktop Portal (for screen sharing, file dialogs) ─────────────
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };

  # ── Fonts ─────────────────────────────────────────────────────────────
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      cantarell-fonts
      liberation_ttf
      font-awesome
    ];
    fontconfig.defaultFonts = {
      monospace = [ "FiraCode Nerd Font" ];
      sansSerif = [ "Cantarell" ];
      serif = [ "Liberation Serif" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  # ── Home Manager ──────────────────────────────────────────────────────
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${cfg.user} = import ../home;
  };

  # ── Security (polkit for privilege escalation) ────────────────────────
  security.polkit.enable = true;
  security.rtkit.enable = true;

  # ── Locale ────────────────────────────────────────────────────────────
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  time.timeZone = lib.mkDefault "Europe/Brussels";

  # Set the user's default shell to zsh (configured via desktop shell module)
  users.users.${cfg.user}.shell = pkgs.zsh;
}
