{ pkgs, home-manager, ... }:

pkgs.nixosTest {
  name = "hecate-desktop-test";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      home-manager.nixosModules.home-manager
      ../configurations/desktop.nix
    ];

    # VM-specific overrides
    virtualisation = {
      memorySize = 4096;
      cores = 2;
    };

    # Disable firstboot for testing
    services.hecate.firstboot.enable = false;

    # Disable greetd in test (no display server in VM test)
    services.greetd.enable = false;
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # ── Hecate directories ──────────────────────────────────────────
    machine.succeed("test -d /home/hecate/.hecate")
    machine.succeed("test -d /home/hecate/.hecate/gitops/system")
    machine.succeed("test -d /home/hecate/.hecate/hecate-daemon/sqlite")
    machine.succeed("test -d /home/hecate/.hecate/hecate-daemon/sockets")
    machine.succeed("test -d /home/hecate/.hecate/secrets")

    # ── User exists with correct shell ──────────────────────────────
    machine.succeed("getent passwd hecate | grep -q zsh")

    # ── System packages present ─────────────────────────────────────
    machine.succeed("which kitty")
    machine.succeed("which waybar")
    machine.succeed("which nvim")
    machine.succeed("which firefox")
    machine.succeed("which lazygit")
    machine.succeed("which bat")
    machine.succeed("which eza")
    machine.succeed("which fzf")
    machine.succeed("which zoxide")
    machine.succeed("which yazi")
    machine.succeed("which fd")
    machine.succeed("which rg")
    machine.succeed("which starship")
    machine.succeed("which rofi")
    machine.succeed("which dunst")
    machine.succeed("which grim")
    machine.succeed("which slurp")
    machine.succeed("which hyprlock")
    machine.succeed("which hypridle")
    machine.succeed("which hyprpaper")
    machine.succeed("which wl-copy")
    machine.succeed("which brightnessctl")
    machine.succeed("which playerctl")

    # ── Home Manager configs deployed ───────────────────────────────
    machine.succeed("test -f /home/hecate/.config/starship.toml")
    machine.succeed("test -f /home/hecate/.config/hypr/hypridle.conf")
    machine.succeed("test -f /home/hecate/.config/hypr/hyprlock.conf")
    machine.succeed("test -f /home/hecate/.config/hypr/hyprpaper.conf")
    machine.succeed("test -f /home/hecate/.config/hypr/wallpaper.png")
    machine.succeed("test -d /home/hecate/.config/nvim")
    machine.succeed("test -f /home/hecate/.config/nvim/init.lua")
    machine.succeed("test -f /home/hecate/.config/waybar/config")
    machine.succeed("test -f /home/hecate/.config/waybar/style.css")
    machine.succeed("test -f /home/hecate/.config/rofi/config.rasi")
    machine.succeed("test -f /home/hecate/.config/rofi/tokyo-night.rasi")

    # ── Fonts installed ─────────────────────────────────────────────
    machine.succeed("fc-list | grep -qi firacode")

    # ── PipeWire active ─────────────────────────────────────────────
    machine.succeed("systemctl is-active pipewire.service")

    # ── Bluetooth service active ────────────────────────────────────
    machine.succeed("systemctl is-active bluetooth.service")

    # ── Hecate reconciler running ───────────────────────────────────
    machine.succeed("su - hecate -c 'systemctl --user is-active hecate-reconciler.service'")

    # ── Hecate CLI available ────────────────────────────────────────
    machine.succeed("su - hecate -c 'hecate help'")

    # ── Gitops seeded ───────────────────────────────────────────────
    machine.succeed("test -f /home/hecate/.hecate/gitops/system/hecate-daemon.container")
    machine.succeed("test -f /home/hecate/.hecate/gitops/system/hecate-daemon.env")
  '';
}
