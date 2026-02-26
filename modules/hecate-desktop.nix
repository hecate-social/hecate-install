{ config, lib, pkgs, ... }:

{
  imports = [
    ./desktop/hyprland.nix
    ./desktop/terminal.nix
    ./desktop/shell.nix
    ./desktop/prompt.nix
    ./desktop/editor.nix
    ./desktop/bar.nix
    ./desktop/launcher.nix
    ./desktop/notifications.nix
    ./desktop/browser.nix
    ./desktop/idle-lock.nix
    ./desktop/theming.nix
    ./desktop/dev-tools.nix
    ./desktop/optional-apps.nix
  ];

  options.services.hecate.desktop = {
    enable = lib.mkEnableOption "HecateOS desktop environment (Hyprland + full tool stack)";
  };

  config = lib.mkIf config.services.hecate.desktop.enable {
    # Enable all desktop sub-modules by default — users can disable individually
    services.hecate.desktop = {
      hyprland.enable = lib.mkDefault true;
      terminal.enable = lib.mkDefault true;
      shell.enable = lib.mkDefault true;
      prompt.enable = lib.mkDefault true;
      editor.enable = lib.mkDefault true;
      bar.enable = lib.mkDefault true;
      launcher.enable = lib.mkDefault true;
      notifications.enable = lib.mkDefault true;
      browser.enable = lib.mkDefault true;
      idle-lock.enable = lib.mkDefault true;
      theming.enable = lib.mkDefault true;
      dev-tools.enable = lib.mkDefault true;
    };
  };
}
