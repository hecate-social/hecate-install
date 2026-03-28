#!/usr/bin/env bash
#
# nix-build-iso.sh — Build hecatOS ISO with temporary nixbld group
#
# Creates the nixbld group + users required by the Nix daemon,
# runs the ISO build, then cleans up the temporary users/group.
#
# Usage: sudo bash scripts/nix-build-iso.sh
#
set -euo pipefail

NIX_USERS=10
BUILD_TARGET="${1:-.#iso}"

info()  { echo -e "\033[0;34m[INFO]\033[0m $*"; }
ok()    { echo -e "\033[0;32m[ OK ]\033[0m $*"; }
error() { echo -e "\033[0;31m[ERR ]\033[0m $*" >&2; }

if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root (sudo)"
    exit 1
fi

CALLER_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
CALLER_HOME=$(eval echo "~${CALLER_USER}")

# ── Setup nixbld group + users ──────────────────────────────────────────

CREATED_GROUP=false
CREATED_USERS=()

setup_nixbld() {
    if getent group nixbld &>/dev/null; then
        info "nixbld group already exists"
    else
        info "Creating nixbld group..."
        groupadd nixbld
        CREATED_GROUP=true
        ok "nixbld group created"
    fi

    for i in $(seq 1 "$NIX_USERS"); do
        local user="nixbld${i}"
        if id "$user" &>/dev/null; then
            continue
        fi
        useradd -g nixbld -G nixbld -M -N -r -s /sbin/nologin "$user"
        CREATED_USERS+=("$user")
    done

    if [ ${#CREATED_USERS[@]} -gt 0 ]; then
        ok "Created ${#CREATED_USERS[@]} nixbld users"
    fi

    # Restart nix-daemon to pick up the group
    if systemctl is-active nix-daemon &>/dev/null; then
        info "Restarting nix-daemon..."
        systemctl restart nix-daemon
        sleep 1
        ok "nix-daemon restarted"
    fi
}

# ── Cleanup ─────────────────────────────────────────────────────────────

cleanup_nixbld() {
    info "Cleaning up nixbld users/group..."

    for user in "${CREATED_USERS[@]}"; do
        userdel "$user" 2>/dev/null || true
    done

    if [ "$CREATED_GROUP" = true ]; then
        groupdel nixbld 2>/dev/null || true
    fi

    if [ ${#CREATED_USERS[@]} -gt 0 ] || [ "$CREATED_GROUP" = true ]; then
        ok "Cleaned up ${#CREATED_USERS[@]} users, group=$CREATED_GROUP"
    fi
}

trap cleanup_nixbld EXIT

# ── Build ───────────────────────────────────────────────────────────────

setup_nixbld

info "Building ${BUILD_TARGET} as ${CALLER_USER}..."
cd "${CALLER_HOME}/work/github.com/hecate-social/hecate-install"

# Run nix build as the original user (nix uses the daemon now)
su - "$CALLER_USER" -c "cd '$(pwd)' && nix build '${BUILD_TARGET}' --show-trace"

ok "Build complete!"
ls -lh result/iso/*.iso 2>/dev/null || ls -lh result/ 2>/dev/null || true
