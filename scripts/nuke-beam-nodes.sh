#!/usr/bin/env bash
#
# Remove ALL container infrastructure from beam nodes.
# Stops services, removes podman/docker/k3s, cleans ~/.hecate.
#
# Usage:
#   ./scripts/nuke-beam-nodes.sh                # All nodes
#   ./scripts/nuke-beam-nodes.sh beam01 beam03  # Specific nodes
#
set -euo pipefail

BEAM_USER="${BEAM_USER:-rl}"
BEAM_DOMAIN="${BEAM_DOMAIN:-.lab}"
ALL_NODES=(beam00 beam01 beam02 beam03)

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; }

nuke_node() {
    local node="$1"
    local fqdn="${node}${BEAM_DOMAIN}"

    echo ""
    echo -e "${BOLD}━━━ Nuking ${fqdn} ━━━${NC}"

    ssh "${BEAM_USER}@${fqdn}" bash -s <<'REMOTE'
set -euo pipefail

echo "=== Stopping user services ==="
systemctl --user stop hecate-reconciler.service 2>/dev/null || true
systemctl --user stop hecate-daemon.service 2>/dev/null || true
systemctl --user disable hecate-reconciler.service 2>/dev/null || true
systemctl --user disable hecate-daemon.service 2>/dev/null || true

# Stop ALL user-level podman services
for svc in $(systemctl --user list-units --type=service --no-legend 2>/dev/null | grep -E 'hecate|searxng|marthad|traderd|marthaw|traderw' | awk '{print $1}'); do
    echo "  Stopping $svc"
    systemctl --user stop "$svc" 2>/dev/null || true
    systemctl --user disable "$svc" 2>/dev/null || true
done
systemctl --user daemon-reload 2>/dev/null || true

echo "=== Stopping all podman containers ==="
if command -v podman &>/dev/null; then
    podman stop -a 2>/dev/null || true
    podman rm -af 2>/dev/null || true
    podman rmi -af 2>/dev/null || true
    podman system prune -af 2>/dev/null || true
    echo "  Podman containers/images cleaned"
fi

echo "=== Stopping all docker containers ==="
if command -v docker &>/dev/null; then
    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm -f $(docker ps -aq) 2>/dev/null || true
    docker rmi -f $(docker images -aq) 2>/dev/null || true
    docker system prune -af 2>/dev/null || true
    echo "  Docker containers/images cleaned"
fi

echo "=== Removing systemd unit files ==="
rm -f ~/.config/containers/systemd/*.container 2>/dev/null || true
rm -f ~/.config/containers/systemd/*.service 2>/dev/null || true
rm -f ~/.config/systemd/user/hecate-reconciler.service 2>/dev/null || true
systemctl --user daemon-reload 2>/dev/null || true
echo "  Systemd units removed"

echo "=== Removing ~/.hecate ==="
rm -rf ~/.hecate
echo "  ~/.hecate removed"

echo "=== Removing hecate binaries ==="
rm -f ~/.local/bin/hecate-reconciler 2>/dev/null || true
rm -f ~/.local/bin/hecate 2>/dev/null || true
echo "  Binaries removed"

echo "=== Removing podman data ==="
rm -rf ~/.local/share/containers 2>/dev/null || true
rm -rf ~/.config/containers 2>/dev/null || true
echo "  Podman user data removed"

echo "=== Checking for k3s ==="
if command -v k3s &>/dev/null || [ -f /usr/local/bin/k3s ]; then
    echo "  k3s found — removing (requires sudo)"
    if [ -x /usr/local/bin/k3s-uninstall.sh ]; then
        sudo /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
        echo "  k3s server uninstalled"
    fi
    if [ -x /usr/local/bin/k3s-agent-uninstall.sh ]; then
        sudo /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || true
        echo "  k3s agent uninstalled"
    fi
    sudo rm -f /usr/local/bin/k3s 2>/dev/null || true
    sudo rm -rf /etc/rancher 2>/dev/null || true
    sudo rm -rf /var/lib/rancher 2>/dev/null || true
    echo "  k3s cleaned"
else
    echo "  No k3s found"
fi

echo "=== Checking for docker ==="
if command -v docker &>/dev/null; then
    echo "  docker found — removing (requires sudo)"
    sudo systemctl stop docker 2>/dev/null || true
    sudo systemctl disable docker 2>/dev/null || true
    if command -v apt-get &>/dev/null; then
        sudo apt-get remove -y docker docker.io docker-ce docker-ce-cli containerd.io 2>/dev/null || true
        sudo apt-get autoremove -y 2>/dev/null || true
    fi
    sudo rm -rf /var/lib/docker 2>/dev/null || true
    echo "  Docker removed"
else
    echo "  No docker found"
fi

echo "=== Removing podman package ==="
if command -v podman &>/dev/null; then
    echo "  podman found — removing (requires sudo)"
    if command -v apt-get &>/dev/null; then
        sudo apt-get remove -y podman 2>/dev/null || true
        sudo apt-get autoremove -y 2>/dev/null || true
    elif command -v dnf &>/dev/null; then
        sudo dnf remove -y podman 2>/dev/null || true
    elif command -v pacman &>/dev/null; then
        sudo pacman -Rns --noconfirm podman 2>/dev/null || true
    fi
    echo "  Podman removed"
else
    echo "  No podman found"
fi

echo "=== Verifying clean state ==="
CLEAN=true
command -v podman &>/dev/null && echo "  WARN: podman still present" && CLEAN=false
command -v docker &>/dev/null && echo "  WARN: docker still present" && CLEAN=false
command -v k3s &>/dev/null && echo "  WARN: k3s still present" && CLEAN=false
[ -d ~/.hecate ] && echo "  WARN: ~/.hecate still exists" && CLEAN=false
[ -d ~/.local/share/containers ] && echo "  WARN: container data still exists" && CLEAN=false

if [ "$CLEAN" = true ]; then
    echo "  Node is clean"
fi
REMOTE

    ok "${fqdn} nuked"
}

# Parse args
DEPLOY_NODES=()
for arg in "$@"; do
    case "$arg" in
        --help|-h)
            echo "Usage: $0 [node1 node2 ...]"
            echo "Removes podman, docker, k3s, and all hecate data from beam nodes."
            exit 0
            ;;
        beam*) DEPLOY_NODES+=("$arg") ;;
        *) echo "Unknown: $arg" >&2; exit 1 ;;
    esac
done
[ ${#DEPLOY_NODES[@]} -eq 0 ] && DEPLOY_NODES=("${ALL_NODES[@]}")

echo -e "${RED}${BOLD}WARNING: This will DESTROY all container infrastructure on: ${DEPLOY_NODES[*]}${NC}"
echo -e "  - Stop and remove all containers"
echo -e "  - Remove podman, docker, k3s packages"
echo -e "  - Delete ~/.hecate (all data, event stores, configs)"
echo -e "  - Delete all container images and volumes"
echo ""
echo -en "Type 'nuke' to confirm: "
read -r confirm
if [ "$confirm" != "nuke" ]; then
    echo "Aborted."
    exit 0
fi

for node in "${DEPLOY_NODES[@]}"; do
    nuke_node "$node"
done

echo ""
ok "All nodes cleaned"
