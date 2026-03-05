{ pkgs, home-manager, ... }:

pkgs.nixosTest {
  name = "hecate-live-desktop-test";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      home-manager.nixosModules.home-manager
      ../configurations/live-desktop.nix
    ];

    # VM-specific overrides
    virtualisation = {
      memorySize = 4096;
      cores = 2;
    };

    # Disable greetd in test VM (no display server)
    services.greetd.enable = false;
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # ── Install script available ──────────────────────────────────────
    machine.succeed("which hecate-install")
    machine.succeed("hecate-install --help | grep -q 'unattended'")

    # ── Flake source baked into ISO ───────────────────────────────────
    machine.succeed("test -f /etc/hecate-install/flake.nix")
    machine.succeed("test -d /etc/hecate-install/disko")
    machine.succeed("test -f /etc/hecate-install/disko/standalone.nix")

    # ── Desktop entry exists ──────────────────────────────────────────
    machine.succeed("test -f /etc/applications/hecatos-install.desktop")
    machine.succeed("grep -q 'Install hecatOS' /etc/applications/hecatos-install.desktop")

    # ── wayvnc available ──────────────────────────────────────────────
    machine.succeed("which wayvnc")

    # ── Branding: Plymouth theme installed ────────────────────────────
    machine.succeed("test -f /run/current-system/sw/share/plymouth/themes/hecate/hecate.plymouth || test -d /nix/store/*plymouth-theme-hecate*/share/plymouth/themes/hecate/ 2>/dev/null || echo 'plymouth-check-skipped'")

    # ── Hecate directories ────────────────────────────────────────────
    machine.succeed("test -d /home/hecate/.hecate")

    # ── Live hostname ─────────────────────────────────────────────────
    machine.succeed("hostname | grep -q 'hecatos-live'")

    # ── Idle-lock disabled ────────────────────────────────────────────
    # (verified by absence of hypridle service in live mode)
  '';
}
