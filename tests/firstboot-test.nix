{ pkgs, ... }:

pkgs.nixosTest {
  name = "hecate-firstboot-test";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../configurations/standalone.nix
    ];

    # Enable firstboot for this test
    services.hecate.firstboot = {
      enable = true;
      port = 8080;  # Non-privileged port for testing
    };

    # Need ncat for the firstboot HTTP server
    environment.systemPackages = [ pkgs.nmap ];

    virtualisation = {
      memorySize = 2048;
      cores = 2;
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # Ensure .configured does NOT exist (firstboot should run)
    machine.fail("test -f /home/rl/.hecate/.configured")

    # Verify firstboot service started
    machine.succeed("systemctl is-active hecate-firstboot.service")

    # Verify pairing API responds
    machine.succeed("curl -sf http://localhost:8080/api/pairing-code | jq -r .code")

    # Verify the web UI is served
    machine.succeed("curl -sf http://localhost:8080/ | grep -q 'Hecate'")

    # Simulate invalid pairing (should get 403)
    machine.succeed(
      "curl -sf -o /dev/null -w '%{http_code}' "
      "-X POST http://localhost:8080/api/configure "
      "-H 'Content-Type: application/json' "
      "-d '{\"code\":\"WRONG\"}' | grep -q 403"
    )

    # Get the real pairing code
    code = machine.succeed("curl -sf http://localhost:8080/api/pairing-code | jq -r .code").strip()

    # Simulate valid pairing
    machine.succeed(
      f"curl -sf -X POST http://localhost:8080/api/configure "
      f"-H 'Content-Type: application/json' "
      f"-d '{{\"code\":\"{code}\"}}'"
    )

    # Verify .configured was created
    machine.wait_until_succeeds("test -f /home/rl/.hecate/.configured", timeout=10)

    # Verify firstboot service stopped (it exits after configuration)
    machine.wait_until_fails("systemctl is-active hecate-firstboot.service", timeout=15)
  '';
}
