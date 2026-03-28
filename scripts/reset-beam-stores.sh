#!/usr/bin/env bash
# reset-beam-stores.sh — Wipe stale ReckonDB data and restart hecate-daemon
#
# Ra/Khepri stores on beam01/beam03 have corrupted cluster state from the
# podman crash-loop era. This wipes them so stores can reinitialize cleanly.
#
# Usage:
#   ./scripts/reset-beam-stores.sh                    # beam01 + beam03
#   ./scripts/reset-beam-stores.sh beam01.lab         # single node

set -euo pipefail

NODES=("beam01.lab" "beam03.lab")

if [[ $# -gt 0 ]]; then
    NODES=("$@")
fi

for node in "${NODES[@]}"; do
    echo "=== $node ==="

    echo "  Stopping hecate-daemon..."
    ssh "rl@${node}" 'docker stop hecate-daemon 2>/dev/null; sleep 2' || true

    echo "  Wiping stale ReckonDB data..."
    ssh "rl@${node}" 'rm -rf ~/.hecate/hecate-daemon/reckon-db/*'

    echo "  Wiping stale SQLite data..."
    ssh "rl@${node}" 'rm -rf ~/.hecate/hecate-daemon/sqlite/*'

    echo "  Starting hecate-daemon..."
    ssh "rl@${node}" 'systemctl --user restart hecate-daemon'

    echo "  Waiting for boot..."
    sleep 5
    status=$(ssh "rl@${node}" 'docker ps --format "{{.Status}}" --filter name=hecate-daemon 2>/dev/null' || echo "unknown")
    echo "  Container: ${status}"
    echo ""
done

echo "Waiting 30s for stores to initialize..."
sleep 30

echo "Checking mesh status..."
for h in "${NODES[@]}"; do
    echo -n "$h: "
    ssh -o ConnectTimeout=2 "rl@$h" \
        'curl -s --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock http://localhost/api/mesh/status 2>/dev/null' \
        2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(f\"connected={d['connected']} peers={d['peer_count']}\")
" 2>/dev/null || echo "not ready yet (may need more time)"
done
