#!/usr/bin/env bash
#
# Hecate Node Uninstaller (systemd + podman)
# Usage: curl -fsSL https://hecate.io/uninstall.sh | bash
#
set -euo pipefail

INSTALL_DIR="${HECATE_INSTALL_DIR:-$HOME/.hecate}"
BIN_DIR="${HECATE_BIN_DIR:-$HOME/.local/bin}"
GITOPS_DIR="${INSTALL_DIR}/gitops"
QUADLET_DIR="${HOME}/.config/containers/systemd"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

# Colors
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' MAGENTA='' BOLD='' DIM='' NC=''
fi

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()      { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
section() { echo ""; echo -e "${MAGENTA}${BOLD}--- $* ---${NC}"; echo ""; }

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local yn_hint="[y/N]"
    [ "$default" = "y" ] && yn_hint="[Y/n]"
    echo -en "${CYAN}?${NC} ${prompt} ${yn_hint} " > /dev/tty
    read -r response < /dev/tty
    response="${response:-$default}"
    [[ "$response" =~ ^[Yy] ]]
}

command_exists() { command -v "$1" &>/dev/null; }

echo ""
echo "    🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺"
echo ""
echo -e "    ${RED}${BOLD}🔥🗝️🔥  H E C A T E  🔥🗝️🔥${NC}"
echo -e "           ${DIM}U N I N S T A L L${NC}"
echo ""
echo "    🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺🇪🇺"
echo ""

# -----------------------------------------------------------------------------
# Detect Installation
# -----------------------------------------------------------------------------

section "Detecting Installation"

FOUND_RECONCILER=false
FOUND_DAEMON=false
FOUND_QUADLET_LINKS=false
FOUND_CLI=false
FOUND_WEB=false
FOUND_GITOPS=false
FOUND_SOCKET=false

# Check reconciler service
if systemctl --user is-enabled hecate-reconciler.service &>/dev/null; then
    FOUND_RECONCILER=true
    echo -e "  ${GREEN}+${NC} Reconciler service: enabled"
fi

# Check daemon service (Quadlet-generated)
if systemctl --user is-active hecate-daemon.service &>/dev/null; then
    FOUND_DAEMON=true
    echo -e "  ${GREEN}+${NC} Daemon: running"
elif systemctl --user list-unit-files 'hecate-daemon*' --no-pager 2>/dev/null | grep -q hecate-daemon; then
    FOUND_DAEMON=true
    echo -e "  ${GREEN}+${NC} Daemon: installed (not running)"
fi

# Check Quadlet symlinks
if ls "${QUADLET_DIR}"/hecate-*.container 2>/dev/null | head -1 &>/dev/null; then
    FOUND_QUADLET_LINKS=true
    count=$(ls "${QUADLET_DIR}"/hecate-*.container 2>/dev/null | wc -l)
    echo -e "  ${GREEN}+${NC} Quadlet units: ${count} container files"
fi

# Check GitOps directory
if [ -d "$GITOPS_DIR" ]; then
    FOUND_GITOPS=true
    echo -e "  ${GREEN}+${NC} GitOps directory: ${GITOPS_DIR}"
fi

# Check daemon socket
socket_path="${INSTALL_DIR}/hecate-daemon/sockets/api.sock"
if [ -S "${socket_path}" ]; then
    FOUND_SOCKET=true
    echo -e "  ${GREEN}+${NC} Daemon socket: ${socket_path}"
fi

# Check CLI wrapper
if [ -f "${BIN_DIR}/hecate" ]; then
    FOUND_CLI=true
    echo -e "  ${GREEN}+${NC} CLI wrapper: ${BIN_DIR}/hecate"
fi

# Check hecate-web
if [ -f "${BIN_DIR}/hecate-web" ]; then
    FOUND_WEB=true
    echo -e "  ${GREEN}+${NC} Desktop app: ${BIN_DIR}/hecate-web"
fi

# Check Ollama
FOUND_OLLAMA=false
if command_exists ollama || [ -d "${HOME}/.ollama" ]; then
    FOUND_OLLAMA=true
    if command_exists ollama; then
        ollama_version=$(ollama --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        echo -e "  ${GREEN}+${NC} Ollama installed: v${ollama_version}"
    fi
    if [ -d "${HOME}/.ollama" ]; then
        ollama_size=$(du -sh "${HOME}/.ollama" 2>/dev/null | cut -f1 || echo "unknown")
        echo -e "  ${GREEN}+${NC} Ollama models: ${ollama_size}"
    fi
fi

# Check if anything found
if [ "$FOUND_RECONCILER" = false ] && [ "$FOUND_DAEMON" = false ] && \
   [ "$FOUND_CLI" = false ] && [ "$FOUND_WEB" = false ] && \
   [ "$FOUND_GITOPS" = false ] && [ "$FOUND_OLLAMA" = false ]; then
    echo ""
    warn "No Hecate installation found"
    exit 0
fi

echo ""
if ! confirm "Uninstall Hecate?"; then
    echo "Cancelled."
    exit 0
fi

# -----------------------------------------------------------------------------
# Stop and Remove Services
# -----------------------------------------------------------------------------

section "Stopping Services"

# Stop all hecate systemd user services
info "Stopping hecate services..."
for unit in $(systemctl --user list-units 'hecate-*' --no-pager --plain --no-legend 2>/dev/null | awk '{print $1}'); do
    info "Stopping ${unit}..."
    systemctl --user stop "${unit}" 2>/dev/null || true
done

# Disable reconciler
if [ "$FOUND_RECONCILER" = true ]; then
    systemctl --user disable hecate-reconciler.service 2>/dev/null || true
    ok "Reconciler disabled"
fi

ok "All hecate services stopped"

# -----------------------------------------------------------------------------
# Remove Quadlet Symlinks
# -----------------------------------------------------------------------------

section "Removing Quadlet Units"

# Remove all hecate-* container files from Quadlet directory
removed_quadlets=0
for f in "${QUADLET_DIR}"/hecate-*.container; do
    if [ -f "${f}" ] || [ -L "${f}" ]; then
        rm -f "${f}"
        removed_quadlets=$((removed_quadlets + 1))
    fi
done

if [ $removed_quadlets -gt 0 ]; then
    ok "Removed ${removed_quadlets} Quadlet unit(s)"
    systemctl --user daemon-reload 2>/dev/null || true
else
    info "No Quadlet units found"
fi

# Remove reconciler service file
if [ -f "${SYSTEMD_USER_DIR}/hecate-reconciler.service" ]; then
    rm -f "${SYSTEMD_USER_DIR}/hecate-reconciler.service"
    systemctl --user daemon-reload 2>/dev/null || true
    ok "Removed reconciler service file"
fi

# -----------------------------------------------------------------------------
# Remove Containers
# -----------------------------------------------------------------------------

section "Removing Containers"

if command_exists podman; then
    # Stop and remove hecate containers
    for container in $(podman ps -a --format '{{.Names}}' 2>/dev/null | grep '^hecate-'); do
        info "Removing container: ${container}"
        podman rm -f "${container}" 2>/dev/null || true
    done

    # Remove hecate images (optional)
    echo ""
    if confirm "Remove hecate container images? (frees disk space)" "y"; then
        for image in $(podman images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep 'hecate'); do
            info "Removing image: ${image}"
            podman rmi "${image}" 2>/dev/null || true
        done
        ok "Container images removed"
    else
        warn "Keeping container images"
    fi
else
    info "podman not found, skipping container cleanup"
fi

# -----------------------------------------------------------------------------
# Remove Binaries
# -----------------------------------------------------------------------------

section "Removing Binaries"

for binary in hecate hecate-reconciler hecate-web; do
    if [ -f "${BIN_DIR}/${binary}" ]; then
        rm -f "${BIN_DIR}/${binary}"
        ok "Removed ${BIN_DIR}/${binary}"
    fi
done

# -----------------------------------------------------------------------------
# Clean Shell Profiles
# -----------------------------------------------------------------------------

section "Shell Profiles"

CLEANED_PROFILES=false
for profile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [ -f "$profile" ]; then
        if grep -qE "(# Hecate)" "$profile" 2>/dev/null; then
            info "Cleaning $profile..."

            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' '/# Hecate/d' "$profile" 2>/dev/null || true
                sed -i '' '/\.local\/bin.*hecate/d' "$profile" 2>/dev/null || true
            else
                sed -i '/# Hecate/d' "$profile" 2>/dev/null || true
                sed -i '/\.local\/bin.*hecate/d' "$profile" 2>/dev/null || true
            fi

            ok "Cleaned $profile"
            CLEANED_PROFILES=true
        fi
    fi
done

if [ "$CLEANED_PROFILES" = false ]; then
    echo "No Hecate entries found in shell profiles"
fi

# -----------------------------------------------------------------------------
# Remove Data Directory
# -----------------------------------------------------------------------------

section "Data Directory"

if [ -d "${INSTALL_DIR}" ]; then
    echo "Contents of ${INSTALL_DIR}:"
    ls -la "${INSTALL_DIR}" 2>/dev/null || true
    echo ""

    if confirm "Delete ${INSTALL_DIR}? ${RED}(includes gitops, secrets, and daemon data)${NC}"; then
        if rm -rf "${INSTALL_DIR}" 2>/dev/null; then
            ok "Removed ${INSTALL_DIR}"
        else
            warn "Some files could not be removed"
            info "Attempting removal with sudo..."
            if sudo rm -rf "${INSTALL_DIR}"; then
                ok "Removed ${INSTALL_DIR}"
            else
                warn "Failed to remove ${INSTALL_DIR}"
                echo "Try manually: sudo rm -rf ${INSTALL_DIR}"
            fi
        fi
    else
        warn "Kept ${INSTALL_DIR}"
        echo "Contains: gitops manifests, daemon data, secrets"
    fi
fi

# -----------------------------------------------------------------------------
# Ollama Cleanup
# -----------------------------------------------------------------------------

section "Ollama (LLM Backend)"

OLLAMA_MODELS_DIR="${HOME}/.ollama"
OLLAMA_MODELS_SIZE=""

if [ -d "$OLLAMA_MODELS_DIR" ]; then
    OLLAMA_MODELS_SIZE=$(du -sh "$OLLAMA_MODELS_DIR" 2>/dev/null | cut -f1 || echo "unknown")
fi

if command_exists ollama || [ -d "$OLLAMA_MODELS_DIR" ]; then
    echo "Ollama was installed for LLM features."
    if [ -n "$OLLAMA_MODELS_SIZE" ]; then
        echo -e "Downloaded models: ${YELLOW}${OLLAMA_MODELS_SIZE}${NC} in ${OLLAMA_MODELS_DIR}"
    fi
    echo ""

    if confirm "Remove Ollama and downloaded models?" "y"; then
        # Stop Ollama service if running
        if command_exists systemctl; then
            if systemctl is-active --quiet ollama 2>/dev/null; then
                info "Stopping Ollama service..."
                sudo systemctl stop ollama 2>/dev/null || true
            fi
            if systemctl is-enabled --quiet ollama 2>/dev/null; then
                sudo systemctl disable ollama 2>/dev/null || true
            fi
        fi

        # Kill any running ollama process
        info "Stopping Ollama processes..."
        pkill -f "ollama" 2>/dev/null || true
        sleep 1

        # Find and remove Ollama binary
        ollama_bin=""
        for path in /usr/local/bin/ollama /usr/bin/ollama; do
            if [ -f "$path" ]; then
                ollama_bin="$path"
                break
            fi
        done
        if command_exists ollama; then
            ollama_bin=$(command -v ollama)
        fi

        if [ -n "$ollama_bin" ] && [ -f "$ollama_bin" ]; then
            info "Removing ${ollama_bin}..."
            sudo rm -f "$ollama_bin"
            ok "Removed ${ollama_bin}"
        else
            info "Ollama binary not found (already removed or installed via package manager)"
        fi

        # Remove Ollama service files
        removed_service=false
        if [ -f /etc/systemd/system/ollama.service ]; then
            sudo rm -f /etc/systemd/system/ollama.service
            removed_service=true
            ok "Removed Ollama systemd service"
        fi
        if [ -d /etc/systemd/system/ollama.service.d ]; then
            sudo rm -rf /etc/systemd/system/ollama.service.d
            removed_service=true
            ok "Removed Ollama service overrides"
        fi
        if [ "$removed_service" = true ]; then
            sudo systemctl daemon-reload 2>/dev/null || true
        fi

        # Remove models from all possible locations
        removed_models=false
        for models_dir in "${HOME}/.ollama" "/usr/share/ollama" "/var/lib/ollama"; do
            if [ -d "$models_dir" ]; then
                dir_size=""
                dir_size=$(du -sh "$models_dir" 2>/dev/null | cut -f1 || echo "unknown")
                info "Removing ${models_dir} (${dir_size})..."
                if sudo rm -rf "$models_dir"; then
                    ok "Removed ${models_dir}"
                    removed_models=true
                else
                    warn "Failed to remove ${models_dir}"
                fi
            fi
        done

        if [ "$removed_models" = false ]; then
            info "No model directories found"
        fi

        echo ""
        ok "Ollama cleanup complete"
    else
        warn "Kept Ollama installation"
        echo "To remove manually later:"
        echo -e "  ${CYAN}sudo rm /usr/local/bin/ollama${NC}"
        echo -e "  ${CYAN}rm -rf ~/.ollama${NC}"
    fi
else
    echo "Ollama not found (not installed or already removed)"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

section "Uninstall Complete"

echo -e "${DIM}The goddess has departed. The crossroads await her return.${NC}"
echo ""
echo "Removed:"
[ "$FOUND_RECONCILER" = true ] && echo "  - Reconciler service"
[ "$FOUND_DAEMON" = true ] && echo "  - Hecate daemon"
[ "$FOUND_CLI" = true ] && echo "  - CLI wrapper (hecate)"
[ "$FOUND_WEB" = true ] && echo "  - Desktop app (hecate-web)"
echo ""
echo "To summon her again:"
echo -e "  ${CYAN}curl -fsSL https://hecate.io/install.sh | bash${NC}"
echo ""
