{ pkgs, ... }:

pkgs.nixosTest {
  name = "hecate-plugin-test";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../configurations/standalone.nix
    ];

    services.hecate.firstboot.enable = false;

    virtualisation = {
      memorySize = 2048;
      cores = 2;
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # Wait for reconciler to be ready
    machine.succeed("su - rl -c 'systemctl --user is-active hecate-reconciler.service'")

    # Drop a test .container file into gitops/apps
    machine.succeed("""
      cat > /home/rl/.hecate/gitops/apps/test-plugin.container << 'EOF'
      [Unit]
      Description=Test Plugin

      [Container]
      Image=docker.io/library/alpine:3.19
      ContainerName=test-plugin
      Exec=sleep infinity

      [Service]
      Restart=on-failure

      [Install]
      WantedBy=default.target
      EOF
      chown rl:users /home/rl/.hecate/gitops/apps/test-plugin.container
    """)

    # Trigger reconciler manually (don't wait for inotify)
    machine.succeed("su - rl -c 'hecate-reconciler --once'")

    # Verify the symlink was created in Quadlet dir
    machine.succeed("test -L /home/rl/.config/containers/systemd/test-plugin.container")

    # Remove the plugin
    machine.succeed("rm /home/rl/.hecate/gitops/apps/test-plugin.container")

    # Reconcile again
    machine.succeed("su - rl -c 'hecate-reconciler --once'")

    # Verify the symlink was removed
    machine.fail("test -L /home/rl/.config/containers/systemd/test-plugin.container")
  '';
}
