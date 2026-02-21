{ pkgs, ... }:

pkgs.nixosTest {
  name = "hecate-boot-test";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../configurations/standalone.nix
    ];

    # Disable firstboot for testing (we want to test the steady state)
    services.hecate.firstboot.enable = false;

    # VM-specific overrides
    virtualisation = {
      memorySize = 2048;
      cores = 2;
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # Verify directories exist
    machine.succeed("test -d /home/rl/.hecate")
    machine.succeed("test -d /home/rl/.hecate/gitops/system")
    machine.succeed("test -d /home/rl/.hecate/gitops/apps")
    machine.succeed("test -d /home/rl/.hecate/hecate-daemon/sqlite")
    machine.succeed("test -d /home/rl/.hecate/hecate-daemon/sockets")
    machine.succeed("test -d /home/rl/.hecate/secrets")

    # Verify reconciler is running (user service)
    machine.succeed("su - rl -c 'systemctl --user is-active hecate-reconciler.service'")

    # Verify reconciler binary works
    machine.succeed("su - rl -c 'hecate-reconciler --status'")

    # Verify podman is available
    machine.succeed("su - rl -c 'podman --version'")

    # Verify gitops was seeded with daemon Quadlet
    machine.succeed("test -f /home/rl/.hecate/gitops/system/hecate-daemon.container")
    machine.succeed("test -f /home/rl/.hecate/gitops/system/hecate-daemon.env")

    # Verify Avahi/mDNS is running
    machine.succeed("systemctl is-active avahi-daemon.service")

    # Verify hecate CLI is available
    machine.succeed("su - rl -c 'hecate help'")

    # Verify firewall is configured
    machine.succeed("iptables -L -n | grep -q 4433")
  '';
}
