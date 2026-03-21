#!/usr/bin/env bash
# Deploy NixOS to beam nodes via nixos-anywhere.
#
# nixos-anywhere kexec-boots a NixOS installer on the running Ubuntu,
# runs disko to partition disks, installs NixOS, and reboots.
# All over SSH — no physical access needed.
#
# Usage:
#   ./scripts/deploy-nixos-beam.sh              # Deploy all 4 nodes
#   ./scripts/deploy-nixos-beam.sh beam00       # Deploy single node
#   ./scripts/deploy-nixos-beam.sh beam00 beam02 # Deploy specific nodes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FLAKE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SSH_USER="root"
DOMAIN="lab"

ALL_NODES=(beam00 beam01 beam02 beam03)

# Use args if provided, otherwise deploy all
if [ $# -gt 0 ]; then
  NODES=("$@")
else
  NODES=("${ALL_NODES[@]}")
fi

echo "=== NixOS Beam Node Deployment ==="
echo "Flake: ${FLAKE_DIR}"
echo "Nodes: ${NODES[*]}"
echo ""
echo "WARNING: This will WIPE ALL DATA on the target nodes!"
echo "         Disks will be repartitioned and reformatted."
echo ""
read -rp "Continue? [y/N] " confirm
if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
  echo "Aborted."
  exit 1
fi

for node in "${NODES[@]}"; do
  echo ""
  echo "──────────────────────────────────────────────"
  echo "Deploying: ${node}.${DOMAIN}"
  echo "──────────────────────────────────────────────"

  # Verify SSH connectivity first
  if ! ssh -o ConnectTimeout=5 "${SSH_USER}@${node}.${DOMAIN}" true 2>/dev/null; then
    echo "ERROR: Cannot SSH to ${SSH_USER}@${node}.${DOMAIN} — skipping"
    continue
  fi

  nix run github:nix-community/nixos-anywhere -- \
    --flake "${FLAKE_DIR}#${node}" \
    "${SSH_USER}@${node}.${DOMAIN}"

  echo "✓ ${node} deployed successfully"
done

echo ""
echo "=== Deployment complete ==="
echo ""
echo "Post-deploy verification:"
for node in "${NODES[@]}"; do
  echo "  ssh rl@${node}.${DOMAIN} 'systemctl --user status hecate-daemon'"
done
echo ""
echo "RDP access (port 3389):"
for node in "${NODES[@]}"; do
  echo "  xfreerdp /v:${node}.${DOMAIN} /u:rl /p:rl"
done
