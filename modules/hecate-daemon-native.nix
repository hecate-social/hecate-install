{ config, lib, pkgs, ... }:

let
  cfg = config.services.hecate;
  nativeCfg = cfg.daemonNative;

  # OTP 28 — the release was built with ERTS 16.1, nixpkgs has 16.3.
  # The relx boot script falls back to system ERTS automatically.
  erlang = pkgs.erlang_28;

  # Fetch the release tarball from GitHub
  releaseTarball = pkgs.fetchurl {
    url = "https://github.com/hecate-social/hecate-daemon/releases/download/v${nativeCfg.version}/hecate-${nativeCfg.version}.tar.gz";
    hash = nativeCfg.tarballHash;
  };

  # Unpack the release into /nix/store (immutable)
  hecateDaemon = pkgs.stdenv.mkDerivation {
    pname = "hecate-daemon";
    version = nativeCfg.version;
    src = releaseTarball;
    dontUnpack = true;

    installPhase = ''
      mkdir -p $out
      tar xzf $src -C $out
    '';
  };

  hostname = config.networking.hostName;
  nodeName = "hecate@${hostname}.lab";
  dataDir = cfg.dataDir;

  # Generate vm.args
  vmArgs = pkgs.writeText "vm.args" ''
    -name ${nodeName}
    -setcookie ${cfg.cluster.cookie}
    -kernel inet_dist_listen_min 9100
    -kernel inet_dist_listen_max 9155
    +K true
    +A 64
    +SDio 64
    +stbt db
    +sbwt very_long
    -env ERL_CRASH_DUMP ${dataDir}/hecate-daemon/run/erl_crash.dump
  '';

  # Generate sys.config
  peersErlangList = "[" + lib.concatMapStringsSep ", " (p: "'hecate@${p}'") cfg.cluster.peers + "]";
  sysConfig = pkgs.writeText "sys.config" ''
    [
      {hecate, [
        {data_dir, "${dataDir}/hecate-daemon"},
        {api_socket, "${dataDir}/hecate-daemon/sockets/api.sock"},
        {mesh_bootstrap, "${cfg.mesh.bootstrap}"},
        {mesh_realm, "${cfg.mesh.realm}"},
        {mesh_port, ${toString cfg.mesh.port}},
        {llm_backend, "${cfg.ollama.backend}"},
        {llm_endpoint, "${cfg.ollama.endpoint}"},
        {cluster_peers, ${peersErlangList}},
        {hostname, "${hostname}"}
      ]}
    ].
  '';

  # Wrapper: copies release to a mutable directory (relx needs to write log/),
  # injects NixOS-generated config, sources secrets, then delegates to bin/hecate.
  hecateWrapper = pkgs.writeShellScript "hecate-daemon-wrapper" ''
    set -euo pipefail

    RELEASE_DIR=${dataDir}/hecate-daemon/release
    RELEASE_STORE=${hecateDaemon}

    # Sync release from Nix store to mutable location (relx writes log/, tmp/)
    mkdir -p "$RELEASE_DIR"
    ${pkgs.rsync}/bin/rsync -a --delete "$RELEASE_STORE/" "$RELEASE_DIR/"
    chmod -R u+w "$RELEASE_DIR"

    # Override config with NixOS-generated files
    export VMARGS_PATH=${vmArgs}
    export RELX_CONFIG_PATH=${sysConfig}

    # Data directories
    export HECATE_DATA_DIR=${dataDir}/hecate-daemon
    export HECATE_API_SOCKET=${dataDir}/hecate-daemon/sockets/api.sock
    export HECATE_HOSTNAME=${hostname}

    # Secrets (source if exists)
    if [ -f ${dataDir}/secrets/llm-providers.env ]; then
      set -a
      . ${dataDir}/secrets/llm-providers.env
      set +a
    fi

    exec "$RELEASE_DIR/bin/hecate" "$@"
  '';
in
{
  options.services.hecate.daemonNative = {
    enable = lib.mkEnableOption "hecate daemon (native Erlang release, no containers)";

    version = lib.mkOption {
      type = lib.types.str;
      default = "0.16.5";
      description = "Version of the hecate-daemon release tarball.";
    };

    tarballHash = lib.mkOption {
      type = lib.types.str;
      default = "sha256-2TWvqabb/DAbY8N76To5SolBfRQMAJOl1HoBHPEakNg=";
      description = ''
        SRI hash of the release tarball. Update when changing version.
        Get it with: nix-prefetch-url --type sha256 <url> | nix hash to-sri --type sha256
      '';
    };
  };

  config = lib.mkIf nativeCfg.enable {
    # Erlang on the system PATH (relx boot script uses `command -v erl`)
    environment.systemPackages = [ erlang ];

    # systemd user service for the rl user
    systemd.user.services.hecate-daemon = {
      description = "Hecate Daemon (native Erlang release)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "default.target" ];

      path = [ erlang ];

      serviceConfig = {
        Type = "exec";
        ExecStart = "${hecateWrapper} foreground";
        ExecStop = "${hecateWrapper} stop";
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStartSec = "120s";

        # Logging
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "hecate-daemon";

        # Resource limits
        LimitNOFILE = 65536;
      };

      environment = {
        HOME = "/home/${cfg.user}";
        RELEASE_NODE = nodeName;
        RELEASE_COOKIE = cfg.cluster.cookie;
      };
    };
  };
}
