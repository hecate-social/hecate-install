#!/usr/bin/env bash
#
# Verify that Hecate is discoverable from graphical launchers (rofi,
# dmenu, GNOME/KDE app grid). Runs a sequence of checks and reports
# exactly which condition is failing — so "hecate doesn't work from
# rofi" becomes a one-command diagnosis.
#
# Usage:
#   scripts/verify-desktop-entry.sh
#
# Exit code: 0 if all green, 1 if any check fails.
#
set -u

BIN_DIR="${HECATE_BIN_DIR:-$HOME/.local/bin}"
APPS_DIR="${HOME}/.local/share/applications"
ICONS_DIR="${HOME}/.local/share/icons/hicolor"
DESKTOP_FILE="${APPS_DIR}/hecate-web.desktop"

# Colors
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' NC=''
fi

PASSED=0
FAILED=0

pass() { echo -e "  ${GREEN}✓${NC} $*"; PASSED=$((PASSED + 1)); }
fail() { echo -e "  ${RED}✗${NC} $*"; FAILED=$((FAILED + 1)); }
warn() { echo -e "  ${YELLOW}!${NC} $*"; }
info() { echo -e "  ${CYAN}i${NC} $*"; }

section() { echo ""; echo -e "${BOLD}$*${NC}"; }

section "Hecate desktop entry diagnostic"
echo ""

# -----------------------------------------------------------------------------
# 1. hecate-web binary
# -----------------------------------------------------------------------------
section "Binary"

if [ -f "${BIN_DIR}/hecate-web" ]; then
    pass "Binary present: ${BIN_DIR}/hecate-web"
    if [ -x "${BIN_DIR}/hecate-web" ]; then
        pass "Binary is executable"
    else
        fail "Binary is NOT executable — run: chmod +x ${BIN_DIR}/hecate-web"
    fi
else
    fail "Binary missing: ${BIN_DIR}/hecate-web"
    info "Rerun install.sh or check BIN_DIR"
fi

# -----------------------------------------------------------------------------
# 2. PATH in interactive shell (.zshrc / .bashrc)
# -----------------------------------------------------------------------------
section "PATH — interactive shell"

shell_rc_has_it=false
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$rc" ] && grep -qE "${BIN_DIR}" "$rc" 2>/dev/null; then
        pass "PATH entry found in $rc"
        shell_rc_has_it=true
    fi
done
[ "$shell_rc_has_it" = false ] && warn "No PATH entry in .zshrc/.bashrc — hecate CLI from terminal may not work"

# -----------------------------------------------------------------------------
# 3. PATH in graphical session (~/.profile)
# -----------------------------------------------------------------------------
section "PATH — graphical session"

if [ -f "$HOME/.profile" ] && grep -qE "${BIN_DIR}" "$HOME/.profile" 2>/dev/null; then
    pass "PATH entry found in ~/.profile (graphical sessions will see ${BIN_DIR})"
else
    fail "No PATH entry in ~/.profile"
    info "rofi/dmenu launchers inherit the graphical session PATH — without this,"
    info "the 'hecate' CLI is invisible to them. The GUI still works via the"
    info ".desktop file's absolute Exec=, but 'rofi -show run' will miss it."
fi

# -----------------------------------------------------------------------------
# 4. Desktop entry file
# -----------------------------------------------------------------------------
section "Desktop entry"

if [ -f "${DESKTOP_FILE}" ]; then
    pass "Desktop file present: ${DESKTOP_FILE}"

    # Validate Exec= points at the real binary
    exec_line=$(grep -m1 '^Exec=' "${DESKTOP_FILE}" | cut -d= -f2-)
    exec_bin="${exec_line%% *}"
    if [ -n "${exec_bin}" ] && [ -x "${exec_bin}" ]; then
        pass "Exec= resolves to runnable binary: ${exec_bin}"
    else
        fail "Exec= points at non-executable or missing path: ${exec_line}"
    fi

    # Validate Name + Icon
    name_line=$(grep -m1 '^Name=' "${DESKTOP_FILE}" | cut -d= -f2-)
    icon_line=$(grep -m1 '^Icon=' "${DESKTOP_FILE}" | cut -d= -f2-)
    info "Name=${name_line}"
    info "Icon=${icon_line}"
else
    fail "Desktop file missing: ${DESKTOP_FILE}"
    info "Rerun install.sh — without this, rofi-drun / app grids cannot find Hecate"
fi

# -----------------------------------------------------------------------------
# 5. Icon installed
# -----------------------------------------------------------------------------
section "Icon"

icon_found=false
for size_dir in "${ICONS_DIR}"/*/apps; do
    if [ -f "${size_dir}/hecate-web.png" ]; then
        pass "Icon present: ${size_dir}/hecate-web.png"
        icon_found=true
    fi
done
if [ "$icon_found" = false ]; then
    fail "No Hecate icon in ${ICONS_DIR}/*/apps"
    info "Some rofi themes filter entries without icons. Rerun install.sh."
fi

# -----------------------------------------------------------------------------
# 6. Desktop database indexed
# -----------------------------------------------------------------------------
section "Launcher index"

if command -v gtk-launch &>/dev/null; then
    if gtk-launch --help &>/dev/null; then
        if gtk-launch hecate-web.desktop --dry-run 2>/dev/null; then
            pass "gtk-launch can resolve hecate-web.desktop"
        else
            # gtk-launch doesn't have a reliable --dry-run; fall through
            info "gtk-launch installed but can't verify without running app"
        fi
    fi
else
    info "gtk-launch not installed — skipping index check"
fi

if command -v update-desktop-database &>/dev/null; then
    pass "update-desktop-database installed"
else
    warn "update-desktop-database not installed — install desktop-file-utils"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
section "Summary"
echo -e "  ${GREEN}${PASSED} passed${NC}  ${RED}${FAILED} failed${NC}"
echo ""

if [ "$FAILED" -gt 0 ]; then
    echo -e "${BOLD}Suggested fix:${NC}"
    echo "  Rerun install.sh — the updated installer (post-2026-04-21) addresses"
    echo "  missing icon, missing ~/.profile PATH entry, and cache refresh."
    echo "  After reinstall: log out + back in (or run 'systemctl --user daemon-reexec')"
    echo "  so the graphical session picks up the new PATH."
    exit 1
fi

echo -e "${GREEN}All checks passed — Hecate should be visible in rofi/dmenu/app grids.${NC}"
exit 0
