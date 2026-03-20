#!/usr/bin/env bash
#
# Configure beam nodes into two sites for dev clustering.
#
# Site A (beam00, beam01) — Erlang-clusters with host00.lab (local dev)
# Site B (beam02, beam03) — Separate Erlang cluster, mesh-only link to Site A
#
# Mounts a custom vm.args into each container to switch from -sname to -name
# with the correct cookie per site.
#
# Usage:
#   ./scripts/configure-beam-sites.sh
#
set -euo pipefail

BEAM_USER="${BEAM_USER:-rl}"

SITE_A_COOKIE="${SITE_A_COOKIE:-9ExkyysakEt8gR0SMQvI}"
SITE_B_COOKIE="${SITE_B_COOKIE:-YtxQd7Ee0e4f2xzIdZSY}"

SITE_A_NODES=(beam00 beam01)
SITE_B_NODES=(beam02 beam03)

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }

configure_node() {
    local node="$1"
    local fqdn="${node}.lab"
    local cookie="$2"
    local peers="$3"
    local site="$4"

    echo ""
    echo -e "${BOLD}━━━ ${fqdn} (${site}) ━━━${NC}"

    ssh "${BEAM_USER}@${fqdn}" bash -s <<REMOTE
set -euo pipefail

ENV_FILE="\$HOME/.hecate/gitops/system/hecate-daemon.env"
VMARGS_FILE="\$HOME/.hecate/hecate-daemon/vm.args"
CONTAINER_FILE="\$HOME/.hecate/gitops/system/hecate-daemon.container"

# --- 1. Write custom vm.args with long names ---
cat > "\$VMARGS_FILE" <<'VMEOF'
## Long name for cross-machine Erlang clustering
-name hecate@${fqdn}

## Cookie set per-site
-setcookie ${cookie}

## Heartbeat management
-heart

## Enable SMP
-smp auto

## Increase async threads
+A 64

## Increase process limit
+P 1048576

## Increase port limit
+Q 65536

## Set scheduler bind type
+sbt db

## Enable dirty schedulers
+SDio 32

## Interactive code server — required for in-VM plugin loading
-mode interactive
VMEOF
echo "Wrote \$VMARGS_FILE"

# --- 2. Update env file ---
sed -i '/^HECATE_ERLANG_COOKIE=/d' "\$ENV_FILE"
sed -i '/^HECATE_CLUSTER_PEERS=/d' "\$ENV_FILE"
sed -i '/^ERL_FLAGS=/d' "\$ENV_FILE"
sed -i '/^# Site /d' "\$ENV_FILE"

cat >> "\$ENV_FILE" <<EOF
# Site ${site} cluster config (configured \$(date -Iseconds))
HECATE_ERLANG_COOKIE=${cookie}
HECATE_CLUSTER_PEERS=${peers}
EOF
echo "Updated \$ENV_FILE"

# --- 3. Add vm.args volume mount to .container if not present ---
if ! grep -q "vm.args" "\$CONTAINER_FILE" 2>/dev/null; then
    # Insert the volume mount after the existing hecate-daemon volume line
    sed -i '/Volume=%h\/.hecate\/hecate-daemon:%h\/.hecate\/hecate-daemon:Z/a Volume=%h/.hecate/hecate-daemon/vm.args:/app/releases/0.8.1/vm.args:ro,Z' "\$CONTAINER_FILE"
    echo "Added vm.args volume mount to container"
fi

# --- 4. Reload systemd and restart ---
systemctl --user daemon-reload
systemctl --user restart hecate-daemon 2>/dev/null || true
echo "Restarted hecate-daemon"
REMOTE

    ok "${fqdn} configured for ${site}"
}

echo -e "${BOLD}Configuring Beam Cluster Sites${NC}"
echo ""
echo "  Site A: ${SITE_A_NODES[*]} + host00.lab (dev)"
echo "    Cookie: ${SITE_A_COOKIE}"
echo ""
echo "  Site B: ${SITE_B_NODES[*]} (remote sites)"
echo "    Cookie: ${SITE_B_COOKIE}"
echo ""

# Site A: beam00, beam01 cluster with each other + host00.lab
for node in "${SITE_A_NODES[@]}"; do
    local_peers=()
    for peer in "${SITE_A_NODES[@]}"; do
        [ "$peer" = "$node" ] && continue
        local_peers+=("${peer}.lab")
    done
    local_peers+=("host00.lab")
    peers_str=$(IFS=,; echo "${local_peers[*]}")
    configure_node "$node" "$SITE_A_COOKIE" "$peers_str" "Site A"
done

# Site B: beam02, beam03 cluster with each other only
for node in "${SITE_B_NODES[@]}"; do
    local_peers=()
    for peer in "${SITE_B_NODES[@]}"; do
        [ "$peer" = "$node" ] && continue
        local_peers+=("${peer}.lab")
    done
    peers_str=$(IFS=,; echo "${local_peers[*]}")
    configure_node "$node" "$SITE_B_COOKIE" "$peers_str" "Site B"
done

# Wait for restarts
info "Waiting 20s for daemons to restart..."
sleep 20

# Status check
echo ""
echo -e "${BOLD}━━━ Status ━━━${NC}"
echo ""
for node in "${SITE_A_NODES[@]}" "${SITE_B_NODES[@]}"; do
    fqdn="${node}.lab"
    if ssh -o ConnectTimeout=5 "${BEAM_USER}@${fqdn}" \
        'test -S ~/.hecate/hecate-daemon/sockets/api.sock' 2>/dev/null; then
        status="${GREEN}running${NC}"
    else
        status="${RED}down${NC}"
    fi
    site="A"
    [[ " ${SITE_B_NODES[*]} " =~ " ${node} " ]] && site="B"
    echo -e "  ${BOLD}${fqdn}${NC}  Site ${site}  ${status}"
done

echo ""
echo -e "${BOLD}Topology:${NC}"
echo "  host00.lab (dev) ←Erlang→ beam00.lab ←Erlang→ beam01.lab    [Site A]"
echo "                       ↕ mesh                    ↕ mesh"
echo "                   beam02.lab ←Erlang→ beam03.lab              [Site B]"
echo ""
echo "  Dev vm.args: config/dev.vm.args"
echo "    -name hecate_dev@host00.lab -setcookie ${SITE_A_COOKIE}"
echo ""
echo "  Start local dev:  ./scripts/dev-all.sh daemon"
echo "  Verify cluster:   erl -name probe@host00.lab -setcookie ${SITE_A_COOKIE} -eval"
echo "                     \"net_adm:ping('hecate@beam00.lab'), nodes().\""
echo ""
ok "Sites configured"
