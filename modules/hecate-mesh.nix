{ config, lib, ... }:

let
  cfg = config.services.hecate;
in
{
  options.services.hecate.mesh = {
    bootstrap = lib.mkOption {
      type = lib.types.str;
      default = "boot.macula.io:4433";
      description = "Macula mesh bootstrap peer address.";
    };

    realm = lib.mkOption {
      type = lib.types.str;
      default = "io.macula";
      description = "Macula mesh realm identifier.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4433;
      description = "UDP port for Macula mesh QUIC transport.";
    };
  };

  # Mesh configuration is consumed by hecate-gitops.nix (written to daemon .env)
  # and by hecate-firewall.nix (port opening).
  # No additional config needed here.
}
