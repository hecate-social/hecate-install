{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.dev-tools = {
    enable = lib.mkEnableOption "Developer CLI tools bundle";
  };

  config = lib.mkIf config.services.hecate.desktop.dev-tools.enable {
    # Podman for container development
    virtualisation.podman.enable = true;

    environment.systemPackages = with pkgs; [
      # File & directory
      bat
      eza
      fd
      ripgrep
      fzf
      zoxide
      yazi
      ncdu
      duf
      tree

      # Git
      git
      delta
      lazygit

      # Containers
      lazydocker

      # System monitoring
      htop
      btop
      gping

      # Data processing
      jq
      yq-go

      # Multiplexer
      tmux

      # Network
      curl
      wget

      # File manager (GUI)
      nautilus
    ];
  };
}
