#!/usr/bin/env bash
#
# Deploy hecate as native BEAM to beam nodes.
#
#   Site A: beam00 + beam01 + host00.lab (Erlang cluster)
#   Site B: beam02 (standalone)
#   Site C: beam03 (standalone)
#
set -euo pipefail

BEAM_USER="${BEAM_USER:-rl}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_INSTALL="${SCRIPT_DIR}/../install.sh"
SITE_A_COOKIE="${SITE_A_COOKIE:-9ExkyysakEt8gR0SMQvI}"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; }

deploy_node() {
    local fqdn="$1" role="$2" cookie="$3" peers="$4" site="$5"

    echo ""
    echo -e "${BOLD}━━━ ${fqdn} (${site}) ━━━${NC}"

    local env="HECATE_NODE_ROLE=${role} HECATE_COOKIE=${cookie}"
    [ -n "$peers" ] && env+=" HECATE_CLUSTER_PEERS=${peers}"

    # Propagate LLM keys
    for var in ANTHROPIC_API_KEY OPENAI_API_KEY GROQ_API_KEY GEMINI_API_KEY; do
        [ -n "${!var:-}" ] && env+=" ${var}=${!var}"
    done

    if cat "${LOCAL_INSTALL}" | ssh "${BEAM_USER}@${fqdn}" "${env} bash -s -- --native --headless"; then
        ok "${fqdn}"
    else
        fail "${fqdn}"
        return 1
    fi
}

echo -e "${BOLD}Hecate Native BEAM Deploy${NC}"
echo ""
echo "  Site A: beam00 + beam01 + host00.lab  cookie: ${SITE_A_COOKIE}"
echo "  Site B: beam02 (standalone)"
echo "  Site C: beam03 (standalone)"
echo ""

info "Checking SSH..."
for n in beam00 beam01 beam02 beam03; do
    ssh -o ConnectTimeout=5 -o BatchMode=yes "${BEAM_USER}@${n}.lab" 'true' 2>/dev/null && ok "${n}.lab" || { fail "${n}.lab"; exit 1; }
done

deploy_node "beam00.lab" cluster "$SITE_A_COOKIE" "beam01.lab,host00.lab" "Site A"
deploy_node "beam01.lab" cluster "$SITE_A_COOKIE" "beam00.lab,host00.lab" "Site A"
deploy_node "beam02.lab" standalone "" "" "Site B"
deploy_node "beam03.lab" standalone "" "" "Site C"

echo ""
echo -e "${BOLD}━━━ Status ━━━${NC}"
sleep 5
for entry in "beam00.lab:A" "beam01.lab:A" "beam02.lab:B" "beam03.lab:C"; do
    fqdn="${entry%%:*}"; site="${entry##*:}"
    if ssh -o ConnectTimeout=5 "${BEAM_USER}@${fqdn}" 'test -S ~/.hecate/hecate-daemon/sockets/api.sock' 2>/dev/null; then
        echo -e "  ${BOLD}${fqdn}${NC}  Site ${site}  ${GREEN}running${NC}"
    else
        echo -e "  ${BOLD}${fqdn}${NC}  Site ${site}  ${CYAN}starting${NC}"
    fi
done

echo ""
echo "  host00.lab ←Erlang→ beam00.lab ←Erlang→ beam01.lab   [Site A]"
echo "                  ↕ mesh              ↕ mesh"
echo "              beam02.lab                                [Site B]"
echo "              beam03.lab                                [Site C]"
echo ""
ok "Done"
