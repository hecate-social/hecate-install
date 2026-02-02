#!/usr/bin/env bash
#
# Hecate Node Uninstaller
#
set -euo pipefail

INSTALL_DIR="${HECATE_INSTALL_DIR:-$HOME/.hecate}"
BIN_DIR="${HECATE_BIN_DIR:-$HOME/.local/bin}"
CLAUDE_DIR="$HOME/.claude"

# Colors
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BOLD='' NC=''
fi

info()  { echo -e "[INFO] $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

echo -e "${BOLD}Hecate Node Uninstaller${NC}"
echo ""

# Confirm
read -p "This will remove Hecate from your system. Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""

# Stop daemon if running
if pgrep -x "hecate" > /dev/null 2>&1; then
    info "Stopping Hecate daemon..."
    "${BIN_DIR}/hecate" stop 2>/dev/null || true
    sleep 1
fi

# Remove binaries
if [ -f "${BIN_DIR}/hecate" ]; then
    rm -f "${BIN_DIR}/hecate"
    ok "Removed ${BIN_DIR}/hecate"
fi

if [ -f "${BIN_DIR}/hecate-tui" ]; then
    rm -f "${BIN_DIR}/hecate-tui"
    ok "Removed ${BIN_DIR}/hecate-tui"
fi

# Remove skills file
if [ -f "${CLAUDE_DIR}/HECATE_SKILLS.md" ]; then
    rm -f "${CLAUDE_DIR}/HECATE_SKILLS.md"
    ok "Removed ${CLAUDE_DIR}/HECATE_SKILLS.md"
fi

# Ask about data directory
echo ""
read -p "Remove data directory (${INSTALL_DIR})? This includes config and logs. [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "${INSTALL_DIR}" ]; then
        rm -rf "${INSTALL_DIR}"
        ok "Removed ${INSTALL_DIR}"
    fi
else
    info "Kept ${INSTALL_DIR}"
fi

echo ""
echo -e "${GREEN}Hecate has been uninstalled.${NC}"
echo ""
echo "Note: Erlang and Elixir were not removed (they may be used by other tools)."
echo "To remove them, use your package manager or mise/asdf."
