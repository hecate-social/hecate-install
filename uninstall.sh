#!/usr/bin/env bash
#
# Hecate Node Uninstaller
# Usage: curl -fsSL https://macula.io/hecate/uninstall.sh | bash
#
set -euo pipefail

INSTALL_DIR="${HECATE_INSTALL_DIR:-$HOME/.hecate}"
BIN_DIR="${HECATE_BIN_DIR:-$HOME/.local/bin}"

# Colors
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' DIM='' NC=''
fi

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()      { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
section() { echo ""; echo -e "${CYAN}${BOLD}━━━ $* ━━━${NC}"; echo ""; }

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

echo -e "${RED}${BOLD}"
cat << 'EOF'
    __  __              __
   / / / /__  _______ _/ /____
  / /_/ / _ \/ __/ _ `/ __/ -_)
 /_//_/\___/\__/\_,_/\__/\__/

EOF
echo -e "${NC}"
echo -e "${BOLD}Hecate Node Uninstaller${NC}"
echo ""

section "Detecting Installation"

FOUND_COMPOSE=false
FOUND_CONTAINERS=false
FOUND_CLI=false
FOUND_TUI=false
FOUND_SKILLS=false

if [ -f "${INSTALL_DIR}/docker-compose.yml" ]; then
    FOUND_COMPOSE=true
    echo -e "  ${GREEN}✓${NC} Docker Compose: ${INSTALL_DIR}/docker-compose.yml"
fi

if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "hecate"; then
    FOUND_CONTAINERS=true
    echo -e "  ${GREEN}✓${NC} Docker containers: hecate-daemon, hecate-watchtower"
fi

if [ -f "${BIN_DIR}/hecate" ]; then
    FOUND_CLI=true
    echo -e "  ${GREEN}✓${NC} CLI wrapper: ${BIN_DIR}/hecate"
fi

if [ -f "${BIN_DIR}/hecate-tui" ]; then
    FOUND_TUI=true
    echo -e "  ${GREEN}✓${NC} TUI binary: ${BIN_DIR}/hecate-tui"
fi

if [ -f "$HOME/.claude/HECATE_SKILLS.md" ]; then
    FOUND_SKILLS=true
    echo -e "  ${GREEN}✓${NC} Claude skills: ~/.claude/HECATE_SKILLS.md"
fi

if [ "$FOUND_COMPOSE" = false ] && [ "$FOUND_CLI" = false ] && [ "$FOUND_TUI" = false ]; then
    echo ""
    warn "No Hecate installation found"
    exit 0
fi

echo ""
if ! confirm "Uninstall Hecate?"; then
    echo "Cancelled."
    exit 0
fi

# Stop and remove containers
if [ "$FOUND_CONTAINERS" = true ] || [ "$FOUND_COMPOSE" = true ]; then
    section "Stopping Docker Containers"

    if [ -f "${INSTALL_DIR}/docker-compose.yml" ]; then
        cd "${INSTALL_DIR}"
        docker compose down --remove-orphans 2>/dev/null || true
        ok "Containers stopped and removed"
    fi
fi

# Remove binaries
section "Removing Binaries"

if [ "$FOUND_CLI" = true ]; then
    rm -f "${BIN_DIR}/hecate"
    ok "Removed ${BIN_DIR}/hecate"
fi

if [ "$FOUND_TUI" = true ]; then
    rm -f "${BIN_DIR}/hecate-tui"
    ok "Removed ${BIN_DIR}/hecate-tui"
fi

# Remove skills
if [ "$FOUND_SKILLS" = true ]; then
    rm -f "$HOME/.claude/HECATE_SKILLS.md"
    ok "Removed Claude skills"

    if [ -f "$HOME/.claude/CLAUDE.md" ]; then
        sed -i '/HECATE_SKILLS/d' "$HOME/.claude/CLAUDE.md" 2>/dev/null || \
        sed -i '' '/HECATE_SKILLS/d' "$HOME/.claude/CLAUDE.md" 2>/dev/null || true
        sed -i '/## Hecate Skills/d' "$HOME/.claude/CLAUDE.md" 2>/dev/null || \
        sed -i '' '/## Hecate Skills/d' "$HOME/.claude/CLAUDE.md" 2>/dev/null || true
    fi
fi

# Remove data directory
section "Data Directory"

if [ -d "${INSTALL_DIR}" ]; then
    echo "Contents:"
    ls -la "${INSTALL_DIR}" 2>/dev/null || true
    echo ""

    if confirm "Delete ${INSTALL_DIR}? ${RED}(includes config and data)${NC}"; then
        rm -rf "${INSTALL_DIR}"
        ok "Removed ${INSTALL_DIR}"
    else
        warn "Kept ${INSTALL_DIR}"
    fi
fi

# Docker images
section "Docker Images"

echo "Hecate Docker images can be removed with:"
echo -e "  ${CYAN}docker rmi ghcr.io/hecate-social/hecate-daemon${NC}"
echo -e "  ${CYAN}docker rmi containrrr/watchtower${NC}"
echo ""
echo "Docker itself was NOT removed."

section "Uninstall Complete"

echo -e "${GREEN}${BOLD}Hecate has been uninstalled.${NC}"
echo ""
echo "To reinstall:"
echo -e "  ${CYAN}curl -fsSL https://macula.io/hecate/install.sh | bash${NC}"
echo ""
