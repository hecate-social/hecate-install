#!/usr/bin/env bash
# fix-beam-docker-groups.sh — Restart systemd --user manager to pick up docker group
#
# On beam00, beam01, beam03 the user session was started before rl was added
# to the docker group. The systemd --user manager doesn't have the docker GID,
# so child processes (hecate-daemon) can't access /var/run/docker.sock.
#
# Fix: restart the systemd --user manager via sudo systemctl restart user@$(id -u rl)
#
# REQUIRES SUDO on each node. Run with:
#   ./scripts/fix-beam-docker-groups.sh
#
# After this, the hecate-daemon service should start normally.

set -euo pipefail

NODES=("beam00.lab" "beam01.lab" "beam03.lab")

if [[ $# -gt 0 ]]; then
    NODES=("$@")
fi

REMOTE_SCRIPT='
#!/bin/bash
set -e
UID_RL=$(id -u rl)
echo "Restarting user@${UID_RL}.service to pick up docker group..."
sudo systemctl restart "user@${UID_RL}.service"
sleep 2
echo "Verifying docker group in user session..."
# The user manager should now have docker GID
systemctl --user status hecate-daemon --no-pager 2>/dev/null | head -5 || true
echo "Starting hecate-daemon..."
systemctl --user restart hecate-daemon
sleep 3
systemctl --user is-active hecate-daemon
'

for node in "${NODES[@]}"; do
    echo "=== $node ==="
    ssh -t "rl@${node}" "${REMOTE_SCRIPT}" 2>/dev/null || echo "  FAILED on ${node}"
    echo ""
done

echo "Checking all nodes..."
for h in beam00.lab beam01.lab beam02.lab beam03.lab; do
    echo -n "$h: "
    ssh -o ConnectTimeout=2 "rl@$h" 'systemctl --user is-active hecate-daemon 2>/dev/null' 2>/dev/null || echo "not-active"
done
