{ pkgs, ... }:

pkgs.nixosTest {
  name = "hecate-installer-test";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../configurations/installer.nix
    ];

    # Disable firstboot for testing
    services.hecate.firstboot.enable = false;

    # Don't actually run the installer service (it expects real disks)
    services.hecate.installer.enable = false;

    # VM-specific overrides
    virtualisation = {
      memorySize = 2048;
      cores = 2;
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # Verify the install script is available
    machine.succeed("which hecate-install")

    # Verify help flag works
    machine.succeed("hecate-install --help")

    # Verify the flake source is baked in (from installer module)
    # Note: flake source is only baked when installer.enable = true,
    # so we verify the script itself works standalone
    machine.succeed("hecate-install --help | grep -q 'unattended'")

    # Verify disk tools are available
    machine.succeed("which parted")
    machine.succeed("which mkfs.ext4")
    machine.succeed("which mkfs.xfs")
    machine.succeed("which lsblk")
    machine.succeed("which lspci")

    # Verify non-installer services are disabled
    machine.fail("systemctl is-active hecate-reconciler.service 2>/dev/null || true")
  '';
}
