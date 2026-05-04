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
REPO_BASE="https://codeberg.org/hecate-social"
# :latest = most recently tagged release (multi-arch); default.
# Override with HECATE_TAG=main for bleeding edge or HECATE_TAG=v0.16.5 to pin.
HECATE_IMAGE="codeberg.org/hecate-social/hecate-daemon:${HECATE_TAG:-latest}"

JOIN_TOKEN=""
CLUSTER_COOKIE=""
CLUSTER_PEERS=""
SITE_ID=""
REALM=""
NODE_HOST=""

TOTAL_STEPS=8
CURRENT_STEP=0
USE_QUADLET=false  # Detected in ensure_podman (requires podman >= 4.4)

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

info()    { echo -e "  ${BLUE}>${NC} $*"; }
ok()      { echo -e "  ${GREEN}✓${NC} $*"; }
warn()    { echo -e "  ${YELLOW}!${NC} $*"; }
error()   { echo -e "  ${RED}✗${NC} $*" >&2; }
fatal()   { error "$@"; exit 1; }

step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo ""
    echo -e "${MAGENTA}${BOLD}[${CURRENT_STEP}/${TOTAL_STEPS}] $*${NC}"
    echo ""
}

command_exists() { command -v "$1" &>/dev/null; }

# -----------------------------------------------------------------------------
# Step 1: Token Decode
# -----------------------------------------------------------------------------

decode_join_token() {
    step "Decoding join token"

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
        fatal "Token expired at $(date -d @"$expires_at" 2>/dev/null || echo "$expires_at")"
    fi

    # Verify HMAC
    local expected_sig
    expected_sig=$(echo -n "$payload" | openssl dgst -sha256 -hmac "$CLUSTER_COOKIE" -hex 2>/dev/null | awk '{print $NF}')
    expected_sig=$(echo "$expected_sig" | tr '[:lower:]' '[:upper:]')
    signature=$(echo "$signature" | tr '[:lower:]' '[:upper:]')

    [ "$expected_sig" = "$signature" ] || fatal "Token signature mismatch — corrupted?"

    ok "Token signature valid"
    info "Site:   ${SITE_ID}"
    info "Cookie: ${CLUSTER_COOKIE:0:4}...${CLUSTER_COOKIE: -4}"
    info "Peers:  ${CLUSTER_PEERS:-none}"
    info "Realm:  ${REALM:-default}"
}

# -----------------------------------------------------------------------------
# Step 2: Hardware Detection
# -----------------------------------------------------------------------------

detect_hardware() {
    step "Detecting hardware"

    DETECTED_RAM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo "0")
    DETECTED_CPU_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1")

    # GPU
    if command_exists nvidia-smi && nvidia-smi &>/dev/null; then
        DETECTED_GPU_TYPE="nvidia"
    elif [ -d /sys/class/drm ] && ls /sys/class/drm/card*/device/vendor 2>/dev/null | xargs grep -l 0x1002 &>/dev/null; then
        DETECTED_GPU_TYPE="amd"
    fi

    # Node hostname
    NODE_HOST=$(cat /etc/hostname 2>/dev/null || uname -n)
    [[ "$NODE_HOST" == *.* ]] || NODE_HOST="${NODE_HOST}.lab"

    ok "Host:    ${NODE_HOST}"
    ok "RAM:     ${DETECTED_RAM_GB} GB"
    ok "CPU:     ${DETECTED_CPU_CORES} cores"
    ok "GPU:     ${DETECTED_GPU_TYPE}"
}

# -----------------------------------------------------------------------------
# Step 3: Firewall
# -----------------------------------------------------------------------------

configure_firewall() {
    step "Configuring firewall"

    info "Cluster ports needed: 4433/udp (mesh), 4369/tcp (EPMD), 9100/tcp (dist), 22/tcp (SSH)"

    local fw_tool=""

    if command_exists ufw; then
        local ufw_status
        ufw_status=$(sudo ufw status 2>/dev/null || echo "")
        if echo "$ufw_status" | grep -q "Status: active"; then
            fw_tool="ufw"
        elif echo "$ufw_status" | grep -q "Status: inactive"; then
            ok "Firewall (ufw) installed but inactive — ports are open"
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
            ok "Firewall (nftables) installed but no rules — ports are open"
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
        ok "No firewall detected — all ports are open"
        return
    fi

    info "Active firewall: ${fw_tool}"
    info "Opening cluster ports..."

    case "$fw_tool" in
        ufw)
            sudo ufw allow ssh 2>&1 | sed 's/^/    /'
            sudo ufw allow 4433/udp comment 'Macula mesh' 2>&1 | sed 's/^/    /'
            sudo ufw allow 4369/tcp comment 'EPMD' 2>&1 | sed 's/^/    /'
            sudo ufw allow 9100/tcp comment 'Erlang dist' 2>&1 | sed 's/^/    /'
            if ! sudo ufw status | grep -q "Status: active"; then
                sudo ufw --force enable 2>&1 | sed 's/^/    /'
            fi
            sudo ufw reload 2>&1 | sed 's/^/    /'
            ;;
        firewalld)
            sudo firewall-cmd --permanent --add-port=4433/udp 2>&1 | sed 's/^/    /'
            sudo firewall-cmd --permanent --add-port=4369/tcp 2>&1 | sed 's/^/    /'
            sudo firewall-cmd --permanent --add-port=9100/tcp 2>&1 | sed 's/^/    /'
            sudo firewall-cmd --reload 2>&1 | sed 's/^/    /'
            ;;
        nftables)
            sudo nft add table inet hecate 2>/dev/null || true
            sudo nft add chain inet hecate input '{ type filter hook input priority 0; policy accept; }' 2>/dev/null || true
            sudo nft add rule inet hecate input udp dport 4433 accept comment \"Macula mesh\" 2>&1 | sed 's/^/    /'
            sudo nft add rule inet hecate input tcp dport 4369 accept comment \"EPMD\" 2>&1 | sed 's/^/    /'
            sudo nft add rule inet hecate input tcp dport 9100 accept comment \"Erlang dist\" 2>&1 | sed 's/^/    /'
            ;;
        iptables)
            sudo iptables -A INPUT -p udp --dport 4433 -j ACCEPT -m comment --comment "Macula mesh" 2>&1 | sed 's/^/    /'
            sudo iptables -A INPUT -p tcp --dport 4369 -j ACCEPT -m comment --comment "EPMD" 2>&1 | sed 's/^/    /'
            sudo iptables -A INPUT -p tcp --dport 9100 -j ACCEPT -m comment --comment "Erlang dist" 2>&1 | sed 's/^/    /'
            ;;
    esac

    ok "Firewall configured (${fw_tool})"
}

# -----------------------------------------------------------------------------
# Step 4: Podman
# -----------------------------------------------------------------------------

ensure_podman() {
    step "Ensuring podman"

    if command_exists podman; then
        local version
        version=$(podman --version 2>/dev/null | awk '{print $3}')
        ok "podman ${version} already installed"
    else
        info "Installing podman..."
        if command_exists pacman; then
            sudo pacman -S --noconfirm --needed podman 2>&1 | tail -5 | sed 's/^/    /'
        elif command_exists apt-get; then
            sudo apt-get update -qq 2>&1 | tail -2 | sed 's/^/    /'
            sudo apt-get install -y -qq podman 2>&1 | tail -5 | sed 's/^/    /'
        elif command_exists dnf; then
            sudo dnf install -y -q podman 2>&1 | tail -5 | sed 's/^/    /'
        elif command_exists zypper; then
            sudo zypper install -y podman 2>&1 | tail -5 | sed 's/^/    /'
        else
            fatal "No supported package manager — install podman manually"
        fi
        command_exists podman || fatal "podman installation failed"
        ok "podman installed"
    fi

    # Detect Quadlet support (podman >= 4.4)
    local podman_version
    podman_version=$(podman --version 2>/dev/null | awk '{print $3}')
    local major minor
    major=$(echo "$podman_version" | cut -d. -f1)
    minor=$(echo "$podman_version" | cut -d. -f2)
    if [ "${major:-0}" -gt 4 ] || { [ "${major:-0}" -eq 4 ] && [ "${minor:-0}" -ge 4 ]; }; then
        USE_QUADLET=true
        ok "Quadlet supported (podman ${podman_version})"
    else
        USE_QUADLET=false
        info "Podman ${podman_version} — using legacy systemd service (Quadlet needs 4.4+)"
    fi

    # Enable lingering so user services survive logout
    if command_exists loginctl; then
        loginctl enable-linger "$(whoami)" 2>/dev/null || true
        ok "User lingering enabled (services persist after logout)"
    fi
}

# -----------------------------------------------------------------------------
# Step 5: Directory Layout
# -----------------------------------------------------------------------------

create_directory_layout() {
    step "Creating directory layout"

    local dirs=(
        "${INSTALL_DIR}/hecate-daemon/sqlite"
        "${INSTALL_DIR}/hecate-daemon/reckon-db"
        "${INSTALL_DIR}/hecate-daemon/sockets"
        "${INSTALL_DIR}/hecate-daemon/run"
        "${INSTALL_DIR}/hecate-daemon/connectors"
        "${INSTALL_DIR}/config"
        "${INSTALL_DIR}/secrets"
        "${GITOPS_DIR}/system"
        "${GITOPS_DIR}/apps"
        "${QUADLET_DIR}"
        "${SYSTEMD_USER_DIR}"
        "${BIN_DIR}"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "${dir}"
    done
    touch "${INSTALL_DIR}/secrets/llm-providers.env"

    ok "${INSTALL_DIR}/"
    info "hecate-daemon/  (sqlite, reckon-db, sockets)"
    info "gitops/         (system, apps)"
    info "config/         secrets/"
}

# -----------------------------------------------------------------------------
# Step 6: GitOps + Configuration
# -----------------------------------------------------------------------------

seed_gitops() {
    step "Configuring node"

    # Stop existing daemon if running (we're about to change its config)
    if systemctl --user is-active --quiet hecate-daemon.service 2>/dev/null; then
        info "Stopping existing daemon (will restart with new config)..."
        systemctl --user stop hecate-daemon.service 2>/dev/null || true
        ok "Existing daemon stopped"
    fi

    # Clone gitops repo for Quadlet templates
    local tmpdir
    tmpdir=$(mktemp -d)
    local cloned=false

    if command_exists git; then
        info "Fetching Quadlet templates from hecate-gitops..."
        git clone --depth 1 "${REPO_BASE}/hecate-gitops.git" "${tmpdir}" 2>/dev/null && cloned=true || true
    fi

    if [ "$cloned" = true ]; then
        if [ -d "${tmpdir}/quadlet/system" ]; then
            cp "${tmpdir}/quadlet/system/"* "${GITOPS_DIR}/system/" 2>/dev/null || true
            ok "Quadlet files seeded from hecate-gitops"
        fi
        if [ -d "${tmpdir}/reconciler" ]; then
            cp "${tmpdir}/reconciler/hecate-reconciler.sh" "${BIN_DIR}/hecate-reconciler"
            chmod +x "${BIN_DIR}/hecate-reconciler"
            cp "${tmpdir}/reconciler/hecate-reconciler.service" "${SYSTEMD_USER_DIR}/hecate-reconciler.service"
            ok "Reconciler installed"
        fi
        rm -rf "${tmpdir}"
    else
        warn "Could not clone hecate-gitops — using embedded defaults"
        rm -rf "${tmpdir}"
        create_default_quadlet
    fi

    write_env_config

    # Show the config that was written
    info "Config: ${GITOPS_DIR}/system/hecate-daemon.env"
    echo ""
    echo -e "  ${DIM}HECATE_NODE_NAME=hecate@${NODE_HOST}${NC}"
    echo -e "  ${DIM}HECATE_ERLANG_COOKIE=${CLUSTER_COOKIE:0:4}...${NC}"
    echo -e "  ${DIM}HECATE_CLUSTER_PEERS=${CLUSTER_PEERS}${NC}"
    echo -e "  ${DIM}HECATE_MESH_BOOTSTRAP=boot.macula.io:4433${NC}"
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
HECATE_NODE_NAME=hecate@${NODE_HOST}
HECATE_ERLANG_COOKIE=${CLUSTER_COOKIE}
HECATE_CLUSTER_PEERS=${CLUSTER_PEERS}
EOF

    ok "Env config written"
}

# -----------------------------------------------------------------------------
# Step 7: Reconciler
# -----------------------------------------------------------------------------

install_reconciler() {
    step "Setting up reconciler"

    if [ "$USE_QUADLET" = false ]; then
        info "Skipping reconciler (not needed without Quadlet)"
        info "Daemon managed directly via systemd service"
        return
    fi

    if [ ! -x "${BIN_DIR}/hecate-reconciler" ]; then
        info "Creating embedded reconciler..."
        create_embedded_reconciler
    else
        ok "Reconciler already installed"
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
        ok "Reconciler service file created"
    fi

    # Install inotify-tools for watch mode
    if ! command_exists inotifywait; then
        info "Installing inotify-tools (filesystem watcher)..."
        if command_exists pacman; then
            sudo pacman -S --noconfirm --needed inotify-tools 2>&1 | tail -3 | sed 's/^/    /'
        elif command_exists apt-get; then
            sudo apt-get install -y -qq inotify-tools 2>&1 | tail -3 | sed 's/^/    /'
        elif command_exists dnf; then
            sudo dnf install -y -q inotify-tools 2>&1 | tail -3 | sed 's/^/    /'
        elif command_exists zypper; then
            sudo zypper install -y inotify-tools 2>&1 | tail -3 | sed 's/^/    /'
        else
            warn "Could not install inotify-tools — reconciler will poll"
        fi
    else
        ok "inotify-tools available"
    fi

    systemctl --user daemon-reload
    systemctl --user enable hecate-reconciler.service 2>/dev/null
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
    ok "Embedded reconciler created"
}

# -----------------------------------------------------------------------------
# Step 8: Deploy + Verify
# -----------------------------------------------------------------------------

deploy_via_quadlet() {
    info "Using Quadlet (podman 4.4+)..."

    # Run reconciler to link Quadlet files
    info "Running reconciler..."
    "${BIN_DIR}/hecate-reconciler" --once 2>&1 | sed 's/^/    /'

    systemctl --user daemon-reload

    info "Starting hecate-daemon service..."
    systemctl --user restart hecate-daemon.service 2>/dev/null || \
        systemctl --user start hecate-daemon.service 2>/dev/null || true

    systemctl --user restart hecate-reconciler.service 2>/dev/null || \
        systemctl --user start hecate-reconciler.service 2>/dev/null || true
}

deploy_via_systemd() {
    info "Creating systemd service (legacy podman)..."

    local env_file="${GITOPS_DIR}/system/hecate-daemon.env"
    local secrets_file="${INSTALL_DIR}/secrets/llm-providers.env"
    local data_dir="${INSTALL_DIR}/hecate-daemon"
    local podman_bin
    podman_bin=$(command -v podman)

    cat > "${SYSTEMD_USER_DIR}/hecate-daemon.service" << EOF
[Unit]
Description=Hecate Daemon (podman container)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStartPre=-${podman_bin} rm -f hecate-daemon
ExecStart=${podman_bin} run --rm --name hecate-daemon \\
  --network host \\
  -e HOME=${HOME} \\
  -e HECATE_HOSTNAME=$(cat /etc/hostname 2>/dev/null || uname -n) \\
  -e HECATE_USER=$(whoami) \\
  --env-file ${env_file} \\
  --env-file ${secrets_file} \\
  -v ${data_dir}:${data_dir}:Z \\
  ${HECATE_IMAGE}
ExecStop=${podman_bin} stop hecate-daemon
Restart=always
RestartSec=10s
TimeoutStartSec=120s

[Install]
WantedBy=default.target
EOF

    ok "Created systemd service"

    systemctl --user daemon-reload
    systemctl --user enable hecate-daemon.service 2>/dev/null

    info "Starting hecate-daemon service..."
    systemctl --user restart hecate-daemon.service 2>/dev/null || \
        systemctl --user start hecate-daemon.service 2>/dev/null || true
}

deploy_hecate() {
    step "Deploying hecate daemon"

    # Pull image (show progress)
    info "Pulling ${HECATE_IMAGE}..."
    echo ""
    podman pull "${HECATE_IMAGE}" 2>&1 | sed 's/^/    /'
    echo ""
    ok "Image ready"

    if [ "$USE_QUADLET" = true ]; then
        deploy_via_quadlet
    else
        deploy_via_systemd
    fi

    # Wait for daemon socket with progress
    info "Waiting for daemon to start..."
    local socket_path="${INSTALL_DIR}/hecate-daemon/sockets/api.sock"
    local retries=30
    local dots=""
    while [ $retries -gt 0 ]; do
        if [ -S "${socket_path}" ]; then
            echo ""
            ok "Daemon socket ready: ${socket_path}"
            break
        fi
        dots="${dots}."
        echo -ne "\r  ${DIM}${dots}${NC}"
        retries=$((retries - 1))
        sleep 2
    done

    if [ $retries -eq 0 ]; then
        echo ""
        warn "Daemon socket not ready after 60s"
        echo ""
        info "Service status:"
        systemctl --user status hecate-daemon.service --no-pager 2>&1 | head -15 | sed 's/^/    /'
        echo ""
        info "Recent logs:"
        journalctl --user -u hecate-daemon --no-pager -n 20 2>&1 | sed 's/^/    /'
        echo ""
        warn "The daemon may still be starting. Check logs with:"
        echo "  journalctl --user -u hecate-daemon -f"
        return
    fi

    # Post-deploy verification
    echo ""
    info "Verifying deployment..."

    # Check systemd status
    local daemon_status
    daemon_status=$(systemctl --user is-active hecate-daemon.service 2>/dev/null || echo "unknown")
    if [ "$daemon_status" = "active" ]; then
        ok "systemd: hecate-daemon is ${GREEN}active${NC}"
    else
        warn "systemd: hecate-daemon is ${daemon_status}"
    fi

    local reconciler_status
    reconciler_status=$(systemctl --user is-active hecate-reconciler.service 2>/dev/null || echo "unknown")
    if [ "$reconciler_status" = "active" ]; then
        ok "systemd: hecate-reconciler is ${GREEN}active${NC}"
    else
        warn "systemd: hecate-reconciler is ${reconciler_status}"
    fi

    # Check container status
    local container_status
    container_status=$(podman ps --format '{{.Names}} {{.Status}}' 2>/dev/null | grep hecate-daemon || echo "")
    if [ -n "$container_status" ]; then
        ok "container: ${container_status}"
    else
        warn "container: hecate-daemon not found in podman ps"
        info "Podman containers:"
        podman ps -a --format '{{.Names}} {{.Status}}' 2>&1 | sed 's/^/    /'
    fi

    # Try health check via API socket
    if [ -S "${socket_path}" ]; then
        local health_response
        health_response=$(curl -s --unix-socket "${socket_path}" http://localhost/api/health 2>/dev/null || echo "")
        if [ -n "$health_response" ]; then
            ok "API health: responding"
            # Extract node_name if available
            local api_node_name
            api_node_name=$(echo "$health_response" | grep -o '"node_name":"[^"]*"' | sed 's/"node_name":"//;s/"$//' || echo "")
            if [ -n "$api_node_name" ]; then
                ok "Node name: ${api_node_name}"
            fi
            # Extract cluster peers if available
            local api_peers
            api_peers=$(echo "$health_response" | grep -o '"connected_nodes":\[[^]]*\]' || echo "")
            if [ -n "$api_peers" ]; then
                info "Cluster: ${api_peers}"
            fi
        else
            info "API not responding yet (daemon may still be initializing)"
        fi
    fi

    # Show a few lines of daemon logs for visibility
    echo ""
    info "Recent daemon logs:"
    journalctl --user -u hecate-daemon --no-pager -n 8 2>&1 | sed 's/^/    /' || \
        podman logs --tail 8 hecate-daemon 2>&1 | sed 's/^/    /' || true
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

show_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}============================================${NC}"
    echo -e "${GREEN}${BOLD}  Hecate node provisioned successfully${NC}"
    echo -e "${GREEN}${BOLD}============================================${NC}"
    echo ""
    echo -e "  ${BOLD}Node:${NC}   hecate@${NODE_HOST}"
    echo -e "  ${BOLD}Site:${NC}   ${SITE_ID}"
    echo -e "  ${BOLD}Peers:${NC}  ${CLUSTER_PEERS}"
    echo -e "  ${BOLD}Data:${NC}   ${INSTALL_DIR}"
    echo ""
    echo -e "  ${DIM}Status:${NC}  systemctl --user status hecate-daemon"
    echo -e "  ${DIM}Logs:${NC}    journalctl --user -u hecate-daemon -f"
    echo -e "  ${DIM}Remove:${NC}  curl -fsSL .../uninstall.sh | bash -s -- --force"
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
    echo -e "  ${DIM}Joining cluster via token · $(date '+%H:%M:%S')${NC}"
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
