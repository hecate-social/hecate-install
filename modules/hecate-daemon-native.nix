{ config, lib, pkgs, ... }:

let
  cfg = config.services.hecate;
  nativeCfg = cfg.daemonNative;

  # Erlang/OTP 27 (latest stable in nixpkgs 24.11)
  erlang = pkgs.erlang_27;

  # Fetch the release tarball from GitHub
  releaseTarball = pkgs.fetchurl {
    url = "https://github.com/hecate-social/hecate-daemon/releases/download/v${nativeCfg.version}/hecate-${nativeCfg.version}.tar.gz";
    hash = nativeCfg.tarballHash;
  };

  # Unpack the release into a derivation
  hecateDaemon = pkgs.stdenv.mkDerivation {
    pname = "hecate-daemon";
    version = nativeCfg.version;
    src = releaseTarball;
    dontUnpack = true;

    installPhase = ''
      mkdir -p $out
      tar xzf $src -C $out --strip-components=1
      # Remove bundled ERTS — we use the system Erlang
      rm -rf $out/erts-*
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

  # Wrapper script that sets up the environment and delegates to the release
  hecateWrapper = pkgs.writeShellScript "hecate-daemon-start" ''
    export ROOTDIR=${hecateDaemon}
    export BINDIR=${erlang}/lib/erlang/erts-${erlang.version}/bin
    export EMU=beam
    export PROGNAME=hecate

    # Override release config with NixOS-generated files
    export VMARGS_PATH=${vmArgs}
    export SYS_CONFIG_PATH=${sysConfig}

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

    exec ${hecateDaemon}/bin/hecate "$@"
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
      default = lib.fakeSha256;
      description = ''
        SHA256 hash of the release tarball. Update this when changing the version.
        Run: nix-prefetch-url <tarball-url> to get the hash.
      '';
    };
  };

  config = lib.mkIf nativeCfg.enable {
    # Install Erlang system-wide
    environment.systemPackages = [ erlang ];

    # Install the release to /opt/hecate
    environment.etc."hecate/release".source = hecateDaemon;

    # systemd user service for the rl user
    systemd.user.services.hecate-daemon = {
      description = "Hecate Daemon (native Erlang release)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "default.target" ];

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
