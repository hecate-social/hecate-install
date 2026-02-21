{ stdenv, lib, makeWrapper, bash, curl, coreutils }:

# Minimal CLI that talks to the daemon unix socket.
# When hecate-cli gets a proper release on GitHub, replace this
# with a fetchFromGitHub derivation.

stdenv.mkDerivation {
  pname = "hecate-cli";
  version = "0.1.0";

  src = null;
  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cat > $out/bin/hecate << 'SCRIPT'
    #!/usr/bin/env bash
    set -euo pipefail

    SOCKET="''${HECATE_SOCKET:-''${HOME}/.hecate/hecate-daemon/sockets/api.sock}"

    case "''${1:-help}" in
      status)
        if [ -S "''${SOCKET}" ]; then
          echo "Hecate daemon: running (socket: ''${SOCKET})"
          curl -sf --unix-socket "''${SOCKET}" http://localhost/api/health 2>/dev/null || echo "  API: not responding"
        else
          echo "Hecate daemon: not running (no socket)"
        fi
        ;;
      health)
        curl -sf --unix-socket "''${SOCKET}" http://localhost/api/health 2>/dev/null || echo "Daemon not responding"
        ;;
      logs)
        journalctl --user -u hecate-daemon -f
        ;;
      reconcile)
        hecate-reconciler --once
        ;;
      help|--help|-h)
        echo "hecate — Hecate node management CLI"
        echo ""
        echo "Commands:"
        echo "  status      Show daemon status"
        echo "  health      Check daemon health"
        echo "  logs        Follow daemon logs"
        echo "  reconcile   Run one-shot reconciliation"
        echo "  help        Show this help"
        ;;
      *)
        echo "Unknown command: $1" >&2
        echo "Run 'hecate help' for usage." >&2
        exit 1
        ;;
    esac
    SCRIPT
    chmod +x $out/bin/hecate

    wrapProgram $out/bin/hecate \
      --prefix PATH : ${lib.makeBinPath [ bash curl coreutils ]}
  '';

  meta = {
    description = "Hecate CLI — node management and plugin control";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "hecate";
  };
}
