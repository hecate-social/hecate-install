#!/usr/bin/env bash
# fix-beam-docker.sh — Switch beam nodes from podman to docker
#
# Ubuntu 20.04 on beam00-03 has Docker CE but no podman.
# The old systemd unit references /usr/bin/podman which doesn't exist,
# causing infinite crash-loop. This script:
#   1. Stops the broken service
#   2. Installs a docker-based systemd unit
#   3. Starts the daemon
#
# Usage:
#   ./scripts/fix-beam-docker.sh                # all beam nodes
#   ./scripts/fix-beam-docker.sh beam00.lab     # single node

set -euo pipefail

NODES=("beam00.lab" "beam01.lab" "beam02.lab" "beam03.lab")

if [[ $# -gt 0 ]]; then
    NODES=("$@")
fi

UNIT_CONTENT='[Unit]
Description=Hecate Daemon (docker container)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStartPre=-/usr/bin/docker rm -f hecate-daemon
ExecStart=/usr/bin/docker run --rm --name hecate-daemon \
  --network host \
  -e HOME=/home/rl \
  -e HECATE_HOSTNAME=%H \
  -e HECATE_USER=rl \
  --env-file /home/rl/.hecate/gitops/system/hecate-daemon.env \
  --env-file /home/rl/.hecate/secrets/llm-providers.env \
  -v /home/rl/.hecate/hecate-daemon:/home/rl/.hecate/hecate-daemon:Z \
  -v /home/rl/.hecate/gitops:/home/rl/.hecate/gitops:ro \
  ghcr.io/hecate-social/hecate-daemon:main
ExecStop=/usr/bin/docker stop -t 30 hecate-daemon
Restart=always
RestartSec=10s
TimeoutStartSec=120s
TimeoutStopSec=45s

[Install]
WantedBy=default.target'

for node in "${NODES[@]}"; do
    echo "=== $node ==="

    # Verify docker is available
    if ! ssh -o ConnectTimeout=3 "rl@${node}" 'docker --version' >/dev/null 2>&1; then
        echo "  SKIP: docker not available on ${node}"
        continue
    fi

    # Stop the crash-looping service
    echo "  Stopping broken service..."
    ssh "rl@${node}" 'systemctl --user stop hecate-daemon 2>/dev/null; systemctl --user reset-failed hecate-daemon 2>/dev/null' || true

    # Write new unit file
    echo "  Installing docker-based unit..."
    ssh "rl@${node}" "mkdir -p ~/.config/systemd/user && cat > ~/.config/systemd/user/hecate-daemon.service << 'UNIT_EOF'
${UNIT_CONTENT}
UNIT_EOF"

    # Reload and start
    echo "  Reloading systemd and starting daemon..."
    ssh "rl@${node}" 'systemctl --user daemon-reload && systemctl --user start hecate-daemon'

    # Wait briefly and check
    sleep 3
    status=$(ssh "rl@${node}" 'systemctl --user is-active hecate-daemon 2>/dev/null' || echo "failed")
    echo "  Status: ${status}"

    if [[ "$status" == "active" ]]; then
        echo "  OK"
    else
        echo "  WARN: not yet active, checking logs..."
        ssh "rl@${node}" 'journalctl --user -u hecate-daemon --no-pager -n 5' 2>/dev/null || true
    fi

    echo ""
done

echo "Done. Check with:"
echo "  for h in ${NODES[*]}; do echo \"\$h:\"; ssh rl@\$h 'systemctl --user status hecate-daemon' 2>/dev/null | head -5; done"
