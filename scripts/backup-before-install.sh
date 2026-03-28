#!/usr/bin/env bash
#
# backup-before-install.sh — Back up home + work before hecatOS install
#
# Backs up /home/rl to /dev/sdb5 using rsync.
# Run as: sudo bash scripts/backup-before-install.sh
#
set -euo pipefail

BACKUP_DEV="${1:-/dev/sdb5}"
BACKUP_MNT="/mnt/backup"
SOURCE_HOME="/home/rl"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="${BACKUP_MNT}/hecatos-backup-${TIMESTAMP}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERR ]${NC} $*" >&2; }

if [ "$(id -u)" -ne 0 ]; then
    error "Run as root: sudo bash $0"
    exit 1
fi

# ── Verify target disk ──────────────────────────────────────────────────

if [ ! -b "$BACKUP_DEV" ]; then
    error "Device ${BACKUP_DEV} not found"
    exit 1
fi

echo ""
echo -e "${BOLD}hecatOS Pre-Install Backup${NC}"
echo ""
echo -e "  ${BOLD}Source:${NC}  ${SOURCE_HOME}"
echo -e "  ${BOLD}Target:${NC}  ${BACKUP_DEV} → ${BACKUP_DIR}"
echo ""

# Show what we're backing up
info "Calculating sizes..."
echo ""
for dir in work .config .claude .ssh .gnupg .gitconfig .erlang.cookie .hex .cargo .hecate-dev .kube .asdf; do
    local_path="${SOURCE_HOME}/${dir}"
    if [ -e "$local_path" ]; then
        size=$(du -sh "$local_path" 2>/dev/null | cut -f1 || echo "?")
        printf "  %-25s %s\n" "$dir" "$size"
    fi
done
echo ""

# Check available space
mkdir -p "$BACKUP_MNT"
mount "$BACKUP_DEV" "$BACKUP_MNT" 2>/dev/null || {
    error "Could not mount ${BACKUP_DEV}. Format it first?"
    echo "  sudo mkfs.ext4 -L hecate-backup ${BACKUP_DEV}"
    exit 1
}

avail=$(df -h "$BACKUP_MNT" | awk 'NR==2{print $4}')
info "Available space on ${BACKUP_DEV}: ${avail}"
echo ""

echo -en "  ${YELLOW}Proceed with backup? [y/N]:${NC} "
read -r confirm
if [[ ! "$confirm" =~ ^[Yy] ]]; then
    umount "$BACKUP_MNT"
    info "Cancelled."
    exit 0
fi

# ── Run backup ──────────────────────────────────────────────────────────

mkdir -p "$BACKUP_DIR"

info "Backing up ${SOURCE_HOME} → ${BACKUP_DIR}"
echo ""

rsync -avh --info=progress2 \
    --exclude='.cache' \
    --exclude='.local/share/Trash' \
    --exclude='_build' \
    --exclude='deps' \
    --exclude='node_modules' \
    --exclude='.nix-defexpr' \
    --exclude='.nix-profile' \
    --exclude='.local/state/nix' \
    --exclude='target/debug' \
    --exclude='target/release' \
    "${SOURCE_HOME}/" "${BACKUP_DIR}/home-rl/"

echo ""

# ── Save system info ───────────────────────────────────────────────────

info "Saving system metadata..."

cat > "${BACKUP_DIR}/system-info.txt" <<EOF
hecatOS Pre-Install Backup
==========================
Date:     $(date)
Hostname: $(hostname)
OS:       $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)
Kernel:   $(uname -r)
Packages: $(pacman -Q 2>/dev/null | wc -l) (pacman)

Disk layout:
$(lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS)

Package list:
$(pacman -Q 2>/dev/null)
EOF

# Save explicit package list (user-installed, not deps)
pacman -Qqe 2>/dev/null > "${BACKUP_DIR}/pacman-explicit.txt" || true

ok "System metadata saved"

# ── Verify ──────────────────────────────────────────────────────────────

echo ""
info "Backup contents:"
du -sh "${BACKUP_DIR}/home-rl/" 2>/dev/null
echo ""
info "Key directories:"
for dir in work .config .claude .ssh .gnupg .gitconfig; do
    if [ -e "${BACKUP_DIR}/home-rl/${dir}" ]; then
        size=$(du -sh "${BACKUP_DIR}/home-rl/${dir}" 2>/dev/null | cut -f1)
        printf "  %-25s %s\n" "$dir" "$size"
    fi
done

echo ""
umount "$BACKUP_MNT"
ok "Backup complete and unmounted: ${BACKUP_DEV}"
echo ""
echo -e "${GREEN}${BOLD}  Safe to install hecatOS on /dev/sda now.${NC}"
echo ""
echo -e "${DIM}  After install, restore with:${NC}"
echo -e "${DIM}    sudo mount ${BACKUP_DEV} /mnt${NC}"
echo -e "${DIM}    rsync -avh /mnt/hecatos-backup-*/home-rl/ /home/\$(whoami)/${NC}"
echo ""
