#!/usr/bin/env bash
#
# Deploy Hecate daemon-only nodes to the beam cluster (beam00-beam03).
#
# Usage:
#   ./scripts/deploy-beam-cluster.sh                    # All nodes
#   ./scripts/deploy-beam-cluster.sh beam01 beam03      # Specific nodes
#   ./scripts/deploy-beam-cluster.sh --dry-run           # Preview only
#
# The script:
#   1. Generates a shared BEAM cookie (or reuses HECATE_COOKIE env)
#   2. SSHes to each node
#   3. Runs install.sh --daemon-only --headless with cluster config
#   4. Reports status
#
set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

BEAM_USER="${BEAM_USER:-rl}"
BEAM_DOMAIN="${BEAM_DOMAIN:-.lab}"

# All beam nodes — override with args
ALL_NODES=(beam00 beam01 beam02 beam03)

# Installer URL (from main branch, or override with INSTALL_URL)
INSTALL_URL="${INSTALL_URL:-https://raw.githubusercontent.com/hecate-social/hecate-install/main/install.sh}"

# Shared cluster cookie
HECATE_COOKIE="${HECATE_COOKIE:-}"

# Remote Ollama (empty = skip, or set to a specific node)
OLLAMA_HOST="${OLLAMA_HOST:-}"

# LLM API keys to propagate (space-separated env var names)
LLM_KEY_VARS=(ANTHROPIC_API_KEY OPENAI_API_KEY GROQ_API_KEY GEMINI_API_KEY GOOGLE_API_KEY MISTRAL_API_KEY DEEPSEEK_API_KEY)

# Dry run
DRY_RUN=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; }

node_fqdn() { echo "${1}${BEAM_DOMAIN}"; }

peers_for_node() {
    local exclude="$1"
    local peers=()
    for n in "${DEPLOY_NODES[@]}"; do
        [ "$n" = "$exclude" ] && continue
        peers+=("$(node_fqdn "$n")")
    done
    echo "${peers[*]}" | tr ' ' ','
}

collect_llm_keys() {
    local keys=""
    for var in "${LLM_KEY_VARS[@]}"; do
        if [ -n "${!var:-}" ]; then
            keys+="${var}=${!var} "
        fi
    done
    echo "$keys"
}

# -----------------------------------------------------------------------------
# Pre-flight
# -----------------------------------------------------------------------------

preflight() {
    info "Checking SSH connectivity..."
    local all_ok=true
    for node in "${DEPLOY_NODES[@]}"; do
        local fqdn
        fqdn=$(node_fqdn "$node")
        if ssh -o ConnectTimeout=5 -o BatchMode=yes "${BEAM_USER}@${fqdn}" 'echo ok' &>/dev/null; then
            ok "${fqdn} reachable"
        else
            fail "${fqdn} unreachable (ssh ${BEAM_USER}@${fqdn})"
            all_ok=false
        fi
    done

    if [ "$all_ok" = false ]; then
        echo ""
        warn "Some nodes are unreachable. Continue with reachable nodes only?"
        echo -en "  [y/N] "
        read -r response
        if [[ ! "$response" =~ ^[Yy] ]]; then
            echo "Aborted."
            exit 1
        fi
        # Filter to reachable nodes
        local reachable=()
        for node in "${DEPLOY_NODES[@]}"; do
            local fqdn
            fqdn=$(node_fqdn "$node")
            if ssh -o ConnectTimeout=5 -o BatchMode=yes "${BEAM_USER}@${fqdn}" 'echo ok' &>/dev/null; then
                reachable+=("$node")
            fi
        done
        DEPLOY_NODES=("${reachable[@]}")
    fi
}

# -----------------------------------------------------------------------------
# Deploy to a single node
# -----------------------------------------------------------------------------

deploy_node() {
    local node="$1"
    local fqdn
    fqdn=$(node_fqdn "$node")
    local peers
    peers=$(peers_for_node "$node")

    echo ""
    echo -e "${BOLD}━━━ Deploying to ${fqdn} ━━━${NC}"
    echo ""

    # Build the env block for the remote install
    local env_block="HECATE_NODE_ROLE=cluster"
    env_block+=" HECATE_COOKIE=${HECATE_COOKIE}"
    [ -n "$peers" ] && env_block+=" HECATE_CLUSTER_PEERS=${peers}"
    [ -n "$OLLAMA_HOST" ] && env_block+=" OLLAMA_HOST=${OLLAMA_HOST}"

    # Propagate LLM API keys
    local llm_keys
    llm_keys=$(collect_llm_keys)
    [ -n "$llm_keys" ] && env_block+=" ${llm_keys}"

    local remote_cmd="${env_block} bash -s -- --daemon-only --headless"

    if [ "$DRY_RUN" = true ]; then
        info "[dry-run] ssh ${BEAM_USER}@${fqdn}"
        info "[dry-run] curl -fsSL ${INSTALL_URL} | ${remote_cmd}"
        return 0
    fi

    # Stream install.sh to the remote node via stdin
    if curl -fsSL "${INSTALL_URL}" | ssh "${BEAM_USER}@${fqdn}" "${remote_cmd}"; then
        ok "${fqdn} deployed successfully"
        return 0
    else
        fail "${fqdn} deployment failed (exit $?)"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Post-deploy status check
# -----------------------------------------------------------------------------

check_status() {
    echo ""
    echo -e "${BOLD}━━━ Cluster Status ━━━${NC}"
    echo ""

    for node in "${DEPLOY_NODES[@]}"; do
        local fqdn
        fqdn=$(node_fqdn "$node")
        local status

        # Check daemon socket
        if ssh -o ConnectTimeout=5 "${BEAM_USER}@${fqdn}" \
            'test -S ~/.hecate/hecate-daemon/sockets/api.sock' 2>/dev/null; then
            status="${GREEN}running${NC}"
        else
            # Check if service is at least active
            if ssh -o ConnectTimeout=5 "${BEAM_USER}@${fqdn}" \
                'systemctl --user is-active hecate-daemon 2>/dev/null' 2>/dev/null | grep -q active; then
                status="${YELLOW}starting${NC}"
            else
                status="${RED}down${NC}"
            fi
        fi

        echo -e "  ${BOLD}${fqdn}${NC}  ${status}"
    done

    echo ""
    echo -e "${DIM}Cookie: ${HECATE_COOKIE}${NC}"
    echo -e "${DIM}Check logs: ssh ${BEAM_USER}@beam00${BEAM_DOMAIN} 'journalctl --user -u hecate-daemon -f'${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    local nodes_from_args=()

    for arg in "$@"; do
        case "$arg" in
            --dry-run) DRY_RUN=true ;;
            --help|-h)
                echo "Usage: $0 [--dry-run] [node1 node2 ...]"
                echo ""
                echo "Deploys Hecate daemon to beam cluster nodes."
                echo ""
                echo "  --dry-run    Preview commands without executing"
                echo ""
                echo "Environment variables:"
                echo "  HECATE_COOKIE         Shared BEAM cookie (auto-generated if empty)"
                echo "  OLLAMA_HOST           Remote Ollama URL for all nodes"
                echo "  BEAM_USER             SSH user (default: rl)"
                echo "  BEAM_DOMAIN           Node domain suffix (default: .lab)"
                echo "  INSTALL_URL           Override installer URL"
                echo "  ANTHROPIC_API_KEY     Propagated to nodes as LLM secret"
                echo "  (and other LLM provider keys)"
                echo ""
                echo "Examples:"
                echo "  $0                                # Deploy all 4 nodes"
                echo "  $0 beam01 beam03                  # Deploy specific nodes"
                echo "  OLLAMA_HOST=http://beam00.lab:11434 $0  # With remote Ollama"
                echo "  $0 --dry-run                      # Preview only"
                exit 0
                ;;
            beam*)
                nodes_from_args+=("$arg")
                ;;
            *)
                echo "Unknown option: $arg" >&2
                exit 1
                ;;
        esac
    done

    # Use specified nodes or all
    if [ ${#nodes_from_args[@]} -gt 0 ]; then
        DEPLOY_NODES=("${nodes_from_args[@]}")
    else
        DEPLOY_NODES=("${ALL_NODES[@]}")
    fi

    # Generate cookie if not provided
    if [ -z "$HECATE_COOKIE" ]; then
        HECATE_COOKIE=$(head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 20)
        info "Generated cluster cookie: ${HECATE_COOKIE}"
    else
        info "Using provided cookie"
    fi

    echo ""
    echo -e "${BOLD}Hecate Beam Cluster Deploy${NC}"
    echo -e "  Nodes:   ${DEPLOY_NODES[*]}"
    echo -e "  Domain:  ${BEAM_DOMAIN}"
    echo -e "  Role:    cluster"
    echo -e "  Cookie:  ${HECATE_COOKIE}"
    [ -n "$OLLAMA_HOST" ] && echo -e "  Ollama:  ${OLLAMA_HOST}"
    echo ""

    preflight

    # Deploy sequentially (parallel SSH would interleave output)
    local failed=()
    for node in "${DEPLOY_NODES[@]}"; do
        if ! deploy_node "$node"; then
            failed+=("$node")
        fi
    done

    if [ "$DRY_RUN" = true ]; then
        echo ""
        info "Dry run complete — no changes made"
        exit 0
    fi

    # Brief wait for daemons to boot
    info "Waiting 15s for daemons to initialize..."
    sleep 15

    check_status

    if [ ${#failed[@]} -gt 0 ]; then
        warn "Failed nodes: ${failed[*]}"
        exit 1
    fi

    ok "Cluster deployment complete"
}

main "$@"
