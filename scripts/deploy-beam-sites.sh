#!/usr/bin/env bash
#
# Deploy hecate to beam nodes with site topology:
#
#   Site A: beam00 + beam01 + host00.lab (Erlang cluster)
#   Site B: beam02 (standalone)
#   Site C: beam03 (standalone)
#
# Cross-site communication is mesh-only (Macula QUIC).
#
# Usage:
#   ./scripts/deploy-beam-sites.sh
#   ./scripts/deploy-beam-sites.sh --dry-run
#
set -euo pipefail

BEAM_USER="${BEAM_USER:-rl}"
INSTALL_URL="${INSTALL_URL:-https://raw.githubusercontent.com/hecate-social/hecate-install/main/install.sh}"

# Site A cookie (shared with host00.lab dev machine)
SITE_A_COOKIE="${SITE_A_COOKIE:-9ExkyysakEt8gR0SMQvI}"

# Site B and C get unique cookies
SITE_B_COOKIE="$(head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 20)"
SITE_C_COOKIE="$(head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 20)"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; }

# ─── LLM keys to propagate ───
collect_llm_keys() {
    local keys=""
    for var in ANTHROPIC_API_KEY OPENAI_API_KEY GROQ_API_KEY GEMINI_API_KEY GOOGLE_API_KEY MISTRAL_API_KEY DEEPSEEK_API_KEY; do
        [ -n "${!var:-}" ] && keys+="${var}=${!var} "
    done
    echo "$keys"
}

# ─── Phase 1: Install hecate (podman + daemon + reconciler) ───
install_node() {
    local fqdn="$1"
    local role="$2"
    local cookie="$3"
    local peers="$4"

    echo ""
    echo -e "${BOLD}━━━ Installing ${fqdn} (${role}) ━━━${NC}"

    local env_block="HECATE_NODE_ROLE=${role} HECATE_COOKIE=${cookie}"
    [ -n "$peers" ] && env_block+=" HECATE_CLUSTER_PEERS=${peers}"

    local llm_keys
    llm_keys=$(collect_llm_keys)
    [ -n "$llm_keys" ] && env_block+=" ${llm_keys}"

    local remote_cmd="${env_block} bash -s -- --daemon-only --headless"

    if [ "$DRY_RUN" = true ]; then
        info "[dry-run] ssh ${BEAM_USER}@${fqdn} | ${role}, cookie=${cookie:0:8}..."
        return 0
    fi

    if curl -fsSL "${INSTALL_URL}" | ssh "${BEAM_USER}@${fqdn}" "${remote_cmd}"; then
        ok "${fqdn} installed"
    else
        fail "${fqdn} install failed"
        return 1
    fi
}

# ─── Phase 2: Configure long names + site-specific vm.args ───
configure_node() {
    local fqdn="$1"
    local cookie="$2"
    local peers="$3"
    local site="$4"

    echo -e "  Configuring ${fqdn} → ${site}"

    ssh "${BEAM_USER}@${fqdn}" bash -s <<REMOTE
set -euo pipefail

VMARGS_FILE="\$HOME/.hecate/hecate-daemon/vm.args"
ENV_FILE="\$HOME/.hecate/gitops/system/hecate-daemon.env"
CONTAINER_FILE="\$HOME/.hecate/gitops/system/hecate-daemon.container"

# Write vm.args with long names
cat > "\$VMARGS_FILE" <<'VMEOF'
-name hecate@${fqdn}
-setcookie ${cookie}
-heart
-smp auto
+A 64
+P 1048576
+Q 65536
+sbt db
+SDio 32
-mode interactive
VMEOF

# Update env
sed -i '/^HECATE_ERLANG_COOKIE=/d' "\$ENV_FILE"
sed -i '/^HECATE_CLUSTER_PEERS=/d' "\$ENV_FILE"
sed -i '/^ERL_FLAGS=/d' "\$ENV_FILE"
sed -i '/^# Site /d' "\$ENV_FILE"
cat >> "\$ENV_FILE" <<EOF
# ${site} (configured \$(date -Iseconds))
HECATE_ERLANG_COOKIE=${cookie}
HECATE_CLUSTER_PEERS=${peers}
EOF

# Mount vm.args into container
if ! grep -q "vm.args" "\$CONTAINER_FILE" 2>/dev/null; then
    sed -i '/Volume=%h\/.hecate\/hecate-daemon:%h\/.hecate\/hecate-daemon:Z/a Volume=%h/.hecate/hecate-daemon/vm.args:/app/releases/0.8.1/vm.args:ro,Z' "\$CONTAINER_FILE"
fi

systemctl --user daemon-reload
systemctl --user restart hecate-daemon 2>/dev/null || true
REMOTE
}

# ─── Main ───
echo -e "${BOLD}Hecate Beam Sites Deploy${NC}"
echo ""
echo "  Site A: beam00.lab + beam01.lab + host00.lab (Erlang cluster)"
echo "    Cookie: ${SITE_A_COOKIE}"
echo "  Site B: beam02.lab (standalone)"
echo "    Cookie: ${SITE_B_COOKIE}"
echo "  Site C: beam03.lab (standalone)"
echo "    Cookie: ${SITE_C_COOKIE}"
echo ""

# Check connectivity
info "Checking SSH..."
for node in beam00 beam01 beam02 beam03; do
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "${BEAM_USER}@${node}.lab" 'echo ok' &>/dev/null; then
        ok "${node}.lab"
    else
        fail "${node}.lab unreachable"
        exit 1
    fi
done

# Phase 1: Install
echo ""
echo -e "${BOLD}Phase 1: Install${NC}"

install_node "beam00.lab" "cluster" "$SITE_A_COOKIE" "beam01.lab,host00.lab"
install_node "beam01.lab" "cluster" "$SITE_A_COOKIE" "beam00.lab,host00.lab"
install_node "beam02.lab" "standalone" "$SITE_B_COOKIE" ""
install_node "beam03.lab" "standalone" "$SITE_C_COOKIE" ""

if [ "$DRY_RUN" = true ]; then
    info "Dry run complete"
    exit 0
fi

# Phase 2: Configure long names + restart
echo ""
echo -e "${BOLD}Phase 2: Configure sites${NC}"

configure_node "beam00.lab" "$SITE_A_COOKIE" "beam01.lab,host00.lab" "Site A"
configure_node "beam01.lab" "$SITE_A_COOKIE" "beam00.lab,host00.lab" "Site A"
configure_node "beam02.lab" "$SITE_B_COOKIE" "" "Site B"
configure_node "beam03.lab" "$SITE_C_COOKIE" "" "Site C"

# Wait for boot
info "Waiting 30s for daemons..."
sleep 30

# Status
echo ""
echo -e "${BOLD}━━━ Status ━━━${NC}"
echo ""
for entry in "beam00.lab:A" "beam01.lab:A" "beam02.lab:B" "beam03.lab:C"; do
    fqdn="${entry%%:*}"
    site="${entry##*:}"
    if ssh -o ConnectTimeout=5 "${BEAM_USER}@${fqdn}" 'test -S ~/.hecate/hecate-daemon/sockets/api.sock' 2>/dev/null; then
        echo -e "  ${BOLD}${fqdn}${NC}  Site ${site}  ${GREEN}running${NC}"
    else
        echo -e "  ${BOLD}${fqdn}${NC}  Site ${site}  ${CYAN}starting${NC}"
    fi
done

echo ""
echo -e "${BOLD}Topology:${NC}"
echo "  host00.lab (dev) ←Erlang→ beam00.lab ←Erlang→ beam01.lab   [Site A]"
echo "                        ↕ mesh              ↕ mesh"
echo "                    beam02.lab (standalone)                    [Site B]"
echo "                    beam03.lab (standalone)                    [Site C]"
echo ""
echo "  Dev: ./scripts/dev-all.sh"
echo "    -name hecate_dev@host00.lab -setcookie ${SITE_A_COOKIE}"
echo ""
ok "Done"
