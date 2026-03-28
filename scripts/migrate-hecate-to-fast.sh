#!/usr/bin/env bash
# migrate-hecate-to-fast.sh — Move HECATE_HOME from eMMC to /fast (NVMe)
#
# The eMMC boot drive on beam nodes can't handle 12 Ra/Khepri systems
# initializing simultaneously. Moving to NVMe (/fast) fixes boot times.
#
# This script:
#   1. Stops hecate-daemon
#   2. Creates /fast/.hecate/hecate-daemon/ owned by rl
#   3. Moves existing data from ~/.hecate/hecate-daemon/ (or starts fresh)
#   4. Updates hecate-daemon.env to set HECATE_HOME=/fast/.hecate
#   5. Updates the systemd unit to mount /fast/.hecate instead of ~/.hecate
#   6. Restarts the daemon
#
# Usage:
#   ./scripts/migrate-hecate-to-fast.sh                 # all beam nodes
#   ./scripts/migrate-hecate-to-fast.sh beam00.lab      # single node
#
# REQUIRES SUDO on each node (for creating dirs on /fast).

set -euo pipefail

NODES=("beam00.lab" "beam01.lab" "beam02.lab" "beam03.lab")

if [[ $# -gt 0 ]]; then
    NODES=("$@")
fi

REMOTE_SCRIPT='
set -euo pipefail

FAST_HECATE="/fast/.hecate"
FAST_DAEMON="${FAST_HECATE}/hecate-daemon"
OLD_DAEMON="${HOME}/.hecate/hecate-daemon"

echo "  [1/6] Stopping hecate-daemon..."
docker stop hecate-daemon 2>/dev/null || true
systemctl --user stop hecate-daemon 2>/dev/null || true
sleep 2

echo "  [2/6] Creating ${FAST_DAEMON}..."
sudo mkdir -p "${FAST_DAEMON}"
sudo chown -R rl:rl "${FAST_HECATE}"

# Create subdirs
mkdir -p "${FAST_DAEMON}"/{reckon-db,sqlite,sockets,run,connectors}

echo "  [3/6] Moving existing data..."
if [ -d "${OLD_DAEMON}/reckon-db" ] && [ "$(ls -A ${OLD_DAEMON}/reckon-db 2>/dev/null)" ]; then
    # Only copy if target is empty (avoid clobbering)
    if [ ! "$(ls -A ${FAST_DAEMON}/reckon-db 2>/dev/null)" ]; then
        sudo cp -a "${OLD_DAEMON}/reckon-db/"* "${FAST_DAEMON}/reckon-db/" 2>/dev/null || true
        sudo chown -R rl:rl "${FAST_DAEMON}/reckon-db"
        echo "    Copied reckon-db data"
    else
        echo "    Target reckon-db not empty, skipping copy"
    fi
else
    echo "    No existing reckon-db data (fresh start)"
fi

# Copy other state files
for subdir in sqlite identity.enc node.cert.pem; do
    if [ -e "${OLD_DAEMON}/${subdir}" ]; then
        sudo cp -a "${OLD_DAEMON}/${subdir}" "${FAST_DAEMON}/" 2>/dev/null || true
        echo "    Copied ${subdir}"
    fi
done

# Copy gitops and secrets (these stay in ~/.hecate since they are config, not data)
# The container mounts both paths

echo "  [4/6] Updating hecate-daemon.env..."
ENV_FILE="${HOME}/.hecate/gitops/system/hecate-daemon.env"
if grep -q "^HECATE_HOME=" "${ENV_FILE}" 2>/dev/null; then
    sed -i "s|^HECATE_HOME=.*|HECATE_HOME=${FAST_HECATE}|" "${ENV_FILE}"
else
    echo "" >> "${ENV_FILE}"
    echo "# Data directory (NVMe for fast Ra/Khepri I/O)" >> "${ENV_FILE}"
    echo "HECATE_HOME=${FAST_HECATE}" >> "${ENV_FILE}"
fi

# Also update socket path to point to new location
if grep -q "^HECATE_SOCKET_PATH=" "${ENV_FILE}" 2>/dev/null; then
    sed -i "s|^HECATE_SOCKET_PATH=.*|HECATE_SOCKET_PATH=${FAST_DAEMON}/sockets/api.sock|" "${ENV_FILE}"
fi

echo "  [5/6] Updating systemd unit..."
UNIT_FILE="${HOME}/.config/systemd/user/hecate-daemon.service"
# Replace volume mounts to use /fast/.hecate
cat > "${UNIT_FILE}" << UNIT_EOF
[Unit]
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
  -v ${FAST_DAEMON}:${FAST_DAEMON}:Z \
  -v /home/rl/.hecate/gitops:/home/rl/.hecate/gitops:ro \
  ghcr.io/hecate-social/hecate-daemon:main
ExecStop=/usr/bin/docker stop -t 30 hecate-daemon
Restart=always
RestartSec=10s
TimeoutStartSec=120s
TimeoutStopSec=45s

[Install]
WantedBy=default.target
UNIT_EOF

echo "  [6/6] Reloading and starting..."
systemctl --user daemon-reload
systemctl --user start hecate-daemon

echo "  Done. Data at ${FAST_DAEMON}"
'

for node in "${NODES[@]}"; do
    echo "=== $node ==="
    ssh -t "rl@${node}" "${REMOTE_SCRIPT}" 2>/dev/null || echo "  FAILED on ${node}"
    echo ""
done

echo "Waiting 45s for stores to initialize on NVMe..."
sleep 45

echo ""
echo "Checking status..."
for h in "${NODES[@]}"; do
    echo -n "$h: "
    ssh -o ConnectTimeout=2 "rl@$h" \
        "curl -s --unix-socket /fast/.hecate/hecate-daemon/sockets/api.sock http://localhost/api/mesh/status 2>/dev/null" \
        2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(f\"connected={d['connected']} peers={d['peer_count']}\")
" 2>/dev/null || echo "not ready yet (stores still initializing — check again in 60s)"
done
