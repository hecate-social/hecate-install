#!/usr/bin/env bash
#
# Hecate Node Provisioner — installs a hecate cluster node on a LAN machine
#
# Designed to be run remotely via SSH from the hecate-web provisioning overlay.
# Unlike install.sh (full interactive installer), this script is focused:
#   - Always cluster mode (requires --join-token)
#   - Semi-interactive: only prompts for sudo (firewall, podman)
#   - No Ollama, no hecate-web, no CLI — just the daemon
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/hecate-social/hecate-install/main/install-hecate-node.sh \
#     | bash -s -- --join-token TOKEN
#
set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

INSTALL_DIR="${HOME}/.hecate"
BIN_DIR="${HOME}/.local/bin"
GITOPS_DIR="${INSTALL_DIR}/gitops"
QUADLET_DIR="${HOME}/.config/containers/systemd"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
REPO_BASE="https://github.com/hecate-social"
HECATE_IMAGE="ghcr.io/hecate-social/hecate-daemon:${HECATE_TAG:-main}"

JOIN_TOKEN=""
CLUSTER_COOKIE=""
CLUSTER_PEERS=""
SITE_ID=""
REALM=""

# Hardware detection
DETECTED_RAM_GB=0
DETECTED_CPU_CORES=0
DETECTED_GPU_TYPE="none"

# Colors (always enabled — output goes to xterm.js which supports ANSI)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()      { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
fatal()   { error "$@"; exit 1; }
section() { echo ""; echo -e "${MAGENTA}${BOLD}--- $* ---${NC}"; echo ""; }

command_exists() { command -v "$1" &>/dev/null; }

# -----------------------------------------------------------------------------
# Token Decode
# -----------------------------------------------------------------------------

decode_join_token() {
    section "Decoding Join Token"

    local decoded
    decoded=$(echo "$JOIN_TOKEN" | base64 -d 2>/dev/null) || fatal "Invalid token: base64 decode failed"

    # Split on LAST dot — payload contains dots in hostnames
    local payload signature
    payload="${decoded%.*}"
    signature="${decoded##*.}"

    [ -n "$payload" ] && [ -n "$signature" ] || fatal "Malformed token"

    # Extract fields
    CLUSTER_COOKIE=$(echo "$payload" | grep -o '"cookie":"[^"]*"' | sed 's/"cookie":"//;s/"$//')
    SITE_ID=$(echo "$payload" | grep -o '"site_id":"[^"]*"' | sed 's/"site_id":"//;s/"$//')
    CLUSTER_PEERS=$(echo "$payload" | grep -o '"admin_host":"[^"]*"' | sed 's/"admin_host":"//;s/"$//')
    REALM=$(echo "$payload" | grep -o '"realm":"[^"]*"' | sed 's/"realm":"//;s/"$//')
    local expires_at
    expires_at=$(echo "$payload" | grep -o '"expires_at":[0-9]*' | sed 's/"expires_at"://')

    [ -n "$CLUSTER_COOKIE" ] || fatal "Token missing cookie"

    # Check expiry
    local now
    now=$(date +%s)
    if [ -n "$expires_at" ] && [ "$now" -gt "$expires_at" ]; then
        fatal "Token expired"
    fi

    # Verify HMAC
    local expected_sig
    expected_sig=$(echo -n "$payload" | openssl dgst -sha256 -hmac "$CLUSTER_COOKIE" -hex 2>/dev/null | awk '{print $NF}')
    expected_sig=$(echo "$expected_sig" | tr '[:lower:]' '[:upper:]')
    signature=$(echo "$signature" | tr '[:lower:]' '[:upper:]')

    [ "$expected_sig" = "$signature" ] || fatal "Token signature mismatch"

    ok "Token verified"
    info "  Site:   ${SITE_ID}"
    info "  Cookie: ${CLUSTER_COOKIE:0:4}...${CLUSTER_COOKIE: -4}"
    info "  Peers:  ${CLUSTER_PEERS:-none}"
    info "  Realm:  ${REALM:-default}"
}

# -----------------------------------------------------------------------------
# Hardware Detection
# -----------------------------------------------------------------------------

detect_hardware() {
    section "Detecting Hardware"

    DETECTED_RAM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo "0")
    DETECTED_CPU_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1")

    # GPU
    if command_exists nvidia-smi && nvidia-smi &>/dev/null; then
        DETECTED_GPU_TYPE="nvidia"
    elif [ -d /sys/class/drm ] && ls /sys/class/drm/card*/device/vendor 2>/dev/null | xargs grep -l 0x1002 &>/dev/null; then
        DETECTED_GPU_TYPE="amd"
    fi

    info "RAM: ${DETECTED_RAM_GB} GB  |  CPU: ${DETECTED_CPU_CORES} cores  |  GPU: ${DETECTED_GPU_TYPE}"
}

# -----------------------------------------------------------------------------
# Firewall
# -----------------------------------------------------------------------------

configure_firewall() {
    section "Firewall Configuration"

    info "Cluster nodes need these ports:"
    echo -e "  ${CYAN}4433/udp${NC}  Macula mesh (QUIC)"
    echo -e "  ${CYAN}4369/tcp${NC}  EPMD (Erlang node discovery)"
    echo -e "  ${CYAN}9100/tcp${NC}  Erlang distribution"
    echo -e "  ${CYAN}22/tcp${NC}    SSH"
    echo ""

    local fw_tool=""

    if command_exists ufw; then
        if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
            fw_tool="ufw"
        elif sudo ufw status 2>/dev/null | grep -q "Status: inactive"; then
            info "ufw installed but inactive — no changes needed"
            return
        fi
    fi

    if [ -z "$fw_tool" ] && command_exists firewall-cmd; then
        if sudo firewall-cmd --state 2>/dev/null | grep -q "running"; then
            fw_tool="firewalld"
        fi
    fi

    if [ -z "$fw_tool" ] && command_exists nft; then
        if sudo nft list ruleset 2>/dev/null | grep -q "table"; then
            fw_tool="nftables"
        else
            info "nftables installed but no rules — no changes needed"
            return
        fi
    fi

    if [ -z "$fw_tool" ] && command_exists iptables; then
        local rules_count
        rules_count=$(sudo iptables -L -n 2>/dev/null | grep -c "^Chain" || echo "0")
        if [ "$rules_count" -gt 3 ]; then
            fw_tool="iptables"
        fi
    fi

    if [ -z "$fw_tool" ]; then
        ok "No active firewall detected — ports are open by default"
        return
    fi

    info "Active firewall: ${fw_tool} — opening cluster ports..."

    case "$fw_tool" in
        ufw)
            sudo ufw allow ssh
            sudo ufw allow 4433/udp comment 'Macula mesh'
            sudo ufw allow 4369/tcp comment 'EPMD'
            sudo ufw allow 9100/tcp comment 'Erlang dist'
            if ! sudo ufw status | grep -q "Status: active"; then
                sudo ufw --force enable
            fi
            sudo ufw reload
            ;;
        firewalld)
            sudo firewall-cmd --permanent --add-port=4433/udp
            sudo firewall-cmd --permanent --add-port=4369/tcp
            sudo firewall-cmd --permanent --add-port=9100/tcp
            sudo firewall-cmd --reload
            ;;
        nftables)
            sudo nft add table inet hecate 2>/dev/null || true
            sudo nft add chain inet hecate input '{ type filter hook input priority 0; policy accept; }' 2>/dev/null || true
            sudo nft add rule inet hecate input udp dport 4433 accept comment \"Macula mesh\"
            sudo nft add rule inet hecate input tcp dport 4369 accept comment \"EPMD\"
            sudo nft add rule inet hecate input tcp dport 9100 accept comment \"Erlang dist\"
            ;;
        iptables)
            sudo iptables -A INPUT -p udp --dport 4433 -j ACCEPT -m comment --comment "Macula mesh"
            sudo iptables -A INPUT -p tcp --dport 4369 -j ACCEPT -m comment --comment "EPMD"
            sudo iptables -A INPUT -p tcp --dport 9100 -j ACCEPT -m comment --comment "Erlang dist"
            ;;
    esac

    ok "Firewall configured (${fw_tool})"
}

# -----------------------------------------------------------------------------
# Podman
# -----------------------------------------------------------------------------

ensure_podman() {
    section "Podman"

    if command_exists podman; then
        ok "podman already installed: $(podman --version 2>/dev/null | awk '{print $3}')"
    else
        info "Installing podman..."
        if command_exists pacman; then
            sudo pacman -S --noconfirm --needed podman
        elif command_exists apt-get; then
            sudo apt-get update -qq && sudo apt-get install -y -qq podman
        elif command_exists dnf; then
            sudo dnf install -y -q podman
        elif command_exists zypper; then
            sudo zypper install -y podman
        else
            fatal "No supported package manager found — install podman manually"
        fi
        command_exists podman || fatal "podman installation failed"
        ok "podman installed"
    fi

    # Enable lingering so user services survive logout
    if command_exists loginctl; then
        loginctl enable-linger "$(whoami)" 2>/dev/null || true
    fi
}

# -----------------------------------------------------------------------------
# Directory Layout
# -----------------------------------------------------------------------------

create_directory_layout() {
    section "Creating Directory Layout"

    mkdir -p "${INSTALL_DIR}/hecate-daemon/sqlite"
    mkdir -p "${INSTALL_DIR}/hecate-daemon/reckon-db"
    mkdir -p "${INSTALL_DIR}/hecate-daemon/sockets"
    mkdir -p "${INSTALL_DIR}/hecate-daemon/run"
    mkdir -p "${INSTALL_DIR}/hecate-daemon/connectors"
    mkdir -p "${INSTALL_DIR}/config"
    mkdir -p "${INSTALL_DIR}/secrets"
    touch "${INSTALL_DIR}/secrets/llm-providers.env"
    mkdir -p "${GITOPS_DIR}/system"
    mkdir -p "${GITOPS_DIR}/apps"
    mkdir -p "${QUADLET_DIR}"
    mkdir -p "${SYSTEMD_USER_DIR}"
    mkdir -p "${BIN_DIR}"

    ok "Directory layout: ${INSTALL_DIR}"
}

# -----------------------------------------------------------------------------
# GitOps + Quadlet
# -----------------------------------------------------------------------------

seed_gitops() {
    section "Seeding GitOps"

    local tmpdir
    tmpdir=$(mktemp -d)
    local cloned=false

    if command_exists git; then
        git clone --depth 1 "${REPO_BASE}/hecate-gitops.git" "${tmpdir}" 2>/dev/null && cloned=true || true
    fi

    if [ "$cloned" = true ]; then
        # Copy system Quadlet files
        if [ -d "${tmpdir}/quadlet/system" ]; then
            cp "${tmpdir}/quadlet/system/"* "${GITOPS_DIR}/system/" 2>/dev/null || true
            ok "Seeded Quadlet files from hecate-gitops"
        fi
        # Copy reconciler
        if [ -d "${tmpdir}/reconciler" ]; then
            cp "${tmpdir}/reconciler/hecate-reconciler.sh" "${BIN_DIR}/hecate-reconciler"
            chmod +x "${BIN_DIR}/hecate-reconciler"
            cp "${tmpdir}/reconciler/hecate-reconciler.service" "${SYSTEMD_USER_DIR}/hecate-reconciler.service"
            ok "Installed reconciler"
        fi
        rm -rf "${tmpdir}"
    else
        warn "Could not clone hecate-gitops — creating embedded defaults"
        rm -rf "${tmpdir}"
        create_default_quadlet
    fi

    write_env_config
}

create_default_quadlet() {
    local arch
    arch=$(uname -m)
    [ "$arch" = "x86_64" ] && arch="amd64"
    [ "$arch" = "aarch64" ] && arch="arm64"

    cat > "${GITOPS_DIR}/system/hecate-daemon.container" << EOF
[Unit]
Description=Hecate Daemon (core)
After=network-online.target
Wants=network-online.target

[Container]
Image=${HECATE_IMAGE}
ContainerName=hecate-daemon
PodmanArgs=--arch ${arch}
AutoUpdate=registry
Network=host

Environment=HOME=%h
Environment=HECATE_HOSTNAME=%H
Environment=HECATE_USER=%u

Volume=%h/.hecate/hecate-daemon:%h/.hecate/hecate-daemon:Z

EnvironmentFile=%h/.hecate/gitops/system/hecate-daemon.env
EnvironmentFile=%h/.hecate/secrets/llm-providers.env

HealthCmd=test -S %h/.hecate/hecate-daemon/sockets/api.sock
HealthInterval=30s
HealthRetries=3
HealthTimeout=5s
HealthStartPeriod=15s

[Service]
Restart=always
RestartSec=10s
TimeoutStartSec=120s

[Install]
WantedBy=default.target
EOF

    ok "Created default Quadlet files"
}

write_env_config() {
    local env_file="${GITOPS_DIR}/system/hecate-daemon.env"

    # Determine node name for Erlang clustering
    local node_host
    node_host=$(cat /etc/hostname 2>/dev/null || uname -n)
    [[ "$node_host" == *.* ]] || node_host="${node_host}.lab"

    cat > "${env_file}" << EOF
# Hecate Daemon Configuration (cluster node)
# Generated by install-hecate-node.sh on $(date -Iseconds)

# Mesh
HECATE_MESH_BOOTSTRAP=boot.macula.io:4433
HECATE_MESH_REALM=${REALM:-io.macula}

# API socket
HECATE_SOCKET_PATH=${INSTALL_DIR}/hecate-daemon/sockets/api.sock

# LLM (no local Ollama — inference handled by cluster)
HECATE_LLM_BACKEND=ollama
HECATE_LLM_ENDPOINT=http://localhost:11434

# Hardware
HECATE_RAM_GB=${DETECTED_RAM_GB}
HECATE_CPU_CORES=${DETECTED_CPU_CORES}
HECATE_GPU=${DETECTED_GPU_TYPE}

# BEAM Cluster
HECATE_NODE_NAME=hecate@${node_host}
HECATE_ERLANG_COOKIE=${CLUSTER_COOKIE}
HECATE_CLUSTER_PEERS=${CLUSTER_PEERS}
EOF

    ok "Env config written (node: hecate@${node_host})"
}

# -----------------------------------------------------------------------------
# Reconciler
# -----------------------------------------------------------------------------

install_reconciler() {
    section "Installing Reconciler"

    if [ ! -x "${BIN_DIR}/hecate-reconciler" ]; then
        warn "Reconciler not found — creating embedded version"
        create_embedded_reconciler
    fi

    # Ensure service file
    if [ ! -f "${SYSTEMD_USER_DIR}/hecate-reconciler.service" ]; then
        cat > "${SYSTEMD_USER_DIR}/hecate-reconciler.service" << 'EOF'
[Unit]
Description=Hecate Reconciler (watches gitops, manages Quadlet units)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=%h/.local/bin/hecate-reconciler --watch
Restart=on-failure
RestartSec=10s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=hecate-reconciler
Environment=HECATE_GITOPS_DIR=%h/.hecate/gitops

[Install]
WantedBy=default.target
EOF
    fi

    # Install inotify-tools for watch mode
    if ! command_exists inotifywait; then
        info "Installing inotify-tools..."
        if command_exists pacman; then
            sudo pacman -S --noconfirm --needed inotify-tools
        elif command_exists apt-get; then
            sudo apt-get install -y -qq inotify-tools
        elif command_exists dnf; then
            sudo dnf install -y -q inotify-tools
        elif command_exists zypper; then
            sudo zypper install -y inotify-tools
        else
            warn "Could not install inotify-tools — reconciler will use polling"
        fi
    fi

    systemctl --user daemon-reload
    systemctl --user enable hecate-reconciler.service
    ok "Reconciler enabled"
}

create_embedded_reconciler() {
    cat > "${BIN_DIR}/hecate-reconciler" << 'RECONCILER'
#!/usr/bin/env bash
set -euo pipefail

GITOPS_DIR="${HECATE_GITOPS_DIR:-${HOME}/.hecate/gitops}"
QUADLET_DIR="${HOME}/.config/containers/systemd"
LOG_PREFIX="[hecate-reconciler]"

log_info() { echo "${LOG_PREFIX} INFO  $(date +%H:%M:%S) $*"; }
log_warn() { echo "${LOG_PREFIX} WARN  $(date +%H:%M:%S) $*" >&2; }

preflight() {
    command -v podman &>/dev/null || { echo "podman not installed" >&2; exit 1; }
    command -v systemctl &>/dev/null || { echo "systemctl not available" >&2; exit 1; }
    [ -d "${GITOPS_DIR}" ] || { echo "gitops dir not found: ${GITOPS_DIR}" >&2; exit 1; }
    mkdir -p "${QUADLET_DIR}"
}

desired_units() {
    local files=()
    for dir in "${GITOPS_DIR}/system" "${GITOPS_DIR}/apps"; do
        if [ -d "${dir}" ]; then
            for f in "${dir}"/*.container; do
                [ -f "${f}" ] && files+=("${f}")
            done
        fi
    done
    [ ${#files[@]} -gt 0 ] && printf '%s\n' "${files[@]}"
}

actual_units() {
    local files=()
    for f in "${QUADLET_DIR}"/*.container; do
        if [ -L "${f}" ]; then
            local target
            target=$(readlink -f "${f}" 2>/dev/null || true)
            if [[ "${target}" == "${GITOPS_DIR}"/* ]]; then
                files+=("${f}")
            fi
        fi
    done
    [ ${#files[@]} -gt 0 ] && printf '%s\n' "${files[@]}"
}

reconcile() {
    local changed=0

    while IFS= read -r src; do
        local name dest
        name=$(basename "${src}")
        dest="${QUADLET_DIR}/${name}"

        if [ -L "${dest}" ]; then
            local current_target
            current_target=$(readlink -f "${dest}")
            [ "${current_target}" = "${src}" ] && continue
            log_info "UPDATE ${name}"
            rm "${dest}"
        elif [ -e "${dest}" ]; then
            log_warn "SKIP ${name} (non-symlink exists)"
            continue
        else
            log_info "ADD ${name}"
        fi

        ln -s "${src}" "${dest}"
        changed=1
    done < <(desired_units)

    while IFS= read -r dest; do
        local target
        target=$(readlink -f "${dest}")
        if [ ! -f "${target}" ]; then
            local name unit_name
            name=$(basename "${dest}")
            unit_name="${name%.container}.service"
            log_info "REMOVE ${name}"
            systemctl --user stop "${unit_name}" 2>/dev/null || true
            rm "${dest}"
            changed=1
        fi
    done < <(actual_units)

    if [ ${changed} -eq 1 ]; then
        log_info "Reloading systemd..."
        systemctl --user daemon-reload
        while IFS= read -r src; do
            local name unit_name
            name=$(basename "${src}")
            unit_name="${name%.container}.service"
            if ! systemctl --user is-active --quiet "${unit_name}" 2>/dev/null; then
                log_info "Starting ${unit_name}..."
                systemctl --user start "${unit_name}" || log_warn "Failed to start ${unit_name}"
            fi
        done < <(desired_units)
        log_info "Reconciliation complete"
    else
        log_info "No changes detected"
    fi
}

watch_loop() {
    log_info "Watching ${GITOPS_DIR} for changes..."
    log_info "Initial reconciliation..."
    reconcile
    while true; do
        if command -v inotifywait &>/dev/null; then
            inotifywait -r -q -e create -e delete -e modify -e moved_to -e moved_from \
                --timeout 300 "${GITOPS_DIR}/system" "${GITOPS_DIR}/apps" 2>/dev/null || true
        else
            sleep 30
        fi
        sleep 1
        log_info "Change detected, reconciling..."
        reconcile
    done
}

preflight

case "${1:-}" in
    --once)   reconcile ;;
    --watch)  watch_loop ;;
    --status) echo "=== Hecate Reconciler ===" ;;
    *)        echo "Usage: hecate-reconciler [--once|--watch|--status]"; exit 1 ;;
esac
RECONCILER

    chmod +x "${BIN_DIR}/hecate-reconciler"
    ok "Created embedded reconciler"
}

# -----------------------------------------------------------------------------
# Deploy
# -----------------------------------------------------------------------------

deploy_hecate() {
    section "Deploying Hecate Daemon"

    info "Pulling daemon image..."
    podman pull "${HECATE_IMAGE}"
    ok "Image ready: ${HECATE_IMAGE}"

    info "Running initial reconciliation..."
    "${BIN_DIR}/hecate-reconciler" --once

    systemctl --user start hecate-reconciler.service
    ok "Reconciler started"

    info "Waiting for daemon to start..."
    local retries=60
    local socket_path="${INSTALL_DIR}/hecate-daemon/sockets/api.sock"
    while [ $retries -gt 0 ]; do
        if [ -S "${socket_path}" ]; then
            ok "Daemon socket ready"
            break
        fi
        retries=$((retries - 1))
        sleep 2
    done

    if [ $retries -eq 0 ]; then
        warn "Daemon socket not ready yet — check logs:"
        echo "  systemctl --user status hecate-daemon"
        echo "  journalctl --user -u hecate-daemon -f"
    fi
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

show_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}=== Hecate Node Installed ===${NC}"
    echo ""
    echo -e "  ${BOLD}Node:${NC}     hecate@$(cat /etc/hostname 2>/dev/null || uname -n)"
    echo -e "  ${BOLD}Site:${NC}     ${SITE_ID}"
    echo -e "  ${BOLD}Peers:${NC}    ${CLUSTER_PEERS}"
    echo -e "  ${BOLD}Data:${NC}     ${INSTALL_DIR}"
    echo ""
    echo -e "  ${DIM}Manage:${NC}   systemctl --user status hecate-daemon"
    echo -e "  ${DIM}Logs:${NC}     journalctl --user -u hecate-daemon -f"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --join-token) shift; JOIN_TOKEN="$1" ;;
            --help|-h)
                echo "Usage: install-hecate-node.sh --join-token TOKEN"
                echo ""
                echo "Installs a hecate cluster node (podman + daemon + reconciler)."
                echo "The join token is generated by your admin node's Site page."
                exit 0
                ;;
        esac
        shift
    done

    [ -n "${JOIN_TOKEN}" ] || fatal "Missing --join-token. Generate one from Site > Install."

    echo ""
    echo -e "${MAGENTA}${BOLD}  Hecate Node Provisioner${NC}"
    echo -e "  ${DIM}Joining cluster via token${NC}"
    echo ""

    decode_join_token
    detect_hardware
    configure_firewall
    ensure_podman
    create_directory_layout
    seed_gitops
    install_reconciler
    deploy_hecate
    show_summary
}

main "$@"
