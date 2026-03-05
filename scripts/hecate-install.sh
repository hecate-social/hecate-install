#!/usr/bin/env bash
#
# hecatOS Install Engine
#
# Installs NixOS from a live ISO onto a target disk using disko + nixos-install.
# Supports unattended (auto-detect everything) and interactive (confirm before wipe) modes.
#
# Usage:
#   hecate-install --unattended       # No prompts, 10s countdown, wipe + install
#   hecate-install --interactive      # Confirm role/disk/hostname before wipe
#   hecate-install --config file.json # Pre-set role/hostname/disk/cluster
#
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────

FLAKE_SOURCE="/etc/hecate-install"
MODE="interactive"   # unattended | interactive
CONFIG_FILE=""
COUNTDOWN_SECS=10

# Detected values (populated by detect_* functions)
DETECTED_CPU_MODEL=""
DETECTED_RAM_GB=0
DETECTED_CPU_CORES=0
DETECTED_HAS_GPU=false
DETECTED_GPU_TYPE=""
DETECTED_IS_BEAM_NODE=false
DETECTED_UEFI=false

# Selected values
SELECTED_ROLE=""
SELECTED_DISK=""
SELECTED_HOSTNAME=""
SELECTED_DISKO_LAYOUT=""

# Cluster config (from config file or defaults)
CLUSTER_COOKIE="hecate_cluster_secret"
CLUSTER_PEERS=""

# ── Colors ───────────────────────────────────────────────────────────────────

if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' BOLD='' DIM='' NC=''
fi

# ── Helpers ──────────────────────────────────────────────────────────────────

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()      { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR ]${NC} $*" >&2; }
fatal()   { error "$@"; exit 1; }
section() { echo ""; echo -e "${MAGENTA}${BOLD}━━━ $* ━━━${NC}"; echo ""; }

# ── Banner ───────────────────────────────────────────────────────────────────

show_banner() {
    echo ""
    echo -e "${BOLD}${CYAN}"
    echo "  _               _    ___  ____  "
    echo " | |__   ___  ___| |_ / _ \\/ ___| "
    echo " | '_ \\ / _ \\/ __| __| | | \\___ \\ "
    echo " | | | |  __/ (__| |_| |_| |___) |"
    echo " |_| |_|\\___|\\___|\\__|\\___/|____/ "
    echo ""
    echo -e "${NC}${DIM}  NixOS-based distribution for the Hecate mesh${NC}"
    echo ""
}

# ── Hardware Detection ───────────────────────────────────────────────────────

detect_hardware() {
    section "Detecting Hardware"

    # CPU model
    DETECTED_CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "Unknown")
    info "CPU: ${DETECTED_CPU_MODEL}"

    # RAM
    DETECTED_RAM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo "0")
    info "RAM: ${DETECTED_RAM_GB} GB"

    # CPU cores
    DETECTED_CPU_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1")
    info "CPU cores: ${DETECTED_CPU_CORES}"

    # GPU
    if lspci 2>/dev/null | grep -qi 'nvidia'; then
        DETECTED_HAS_GPU=true
        DETECTED_GPU_TYPE="nvidia"
    elif lspci 2>/dev/null | grep -qi 'AMD.*Radeon\|ATI'; then
        DETECTED_HAS_GPU=true
        DETECTED_GPU_TYPE="amd"
    fi

    if [ "$DETECTED_HAS_GPU" = true ]; then
        info "GPU: ${DETECTED_GPU_TYPE}"
    else
        info "GPU: None detected"
    fi

    # UEFI detection
    if [ -d /sys/firmware/efi ]; then
        DETECTED_UEFI=true
        info "Boot: UEFI"
    else
        info "Boot: BIOS (legacy)"
    fi

    # Beam node detection (Intel Celeron J4105)
    if echo "$DETECTED_CPU_MODEL" | grep -qi 'J4105\|J4125\|N5105\|N5095'; then
        DETECTED_IS_BEAM_NODE=true
        info "Hardware profile: Beam cluster node"
    fi

    echo ""
}

# ── Disk Inventory ───────────────────────────────────────────────────────────

list_candidate_disks() {
    # List block devices that are:
    #   - Not the ISO boot device (not usb if we booted from USB, or skip the device containing /)
    #   - Not loop/ram/rom
    #   - At least 20GB
    #   - Whole disks (not partitions)
    local boot_dev
    boot_dev=$(findmnt -n -o SOURCE / 2>/dev/null | sed 's/[0-9]*$//' | sed 's/p[0-9]*$//' || echo "")

    lsblk -dnbo NAME,SIZE,TYPE,TRAN,MODEL 2>/dev/null | while read -r name size dtype tran model; do
        # Skip non-disk devices
        [ "$dtype" != "disk" ] && continue

        # Skip tiny disks (<20GB)
        [ "$size" -lt 21474836480 ] 2>/dev/null && continue

        # Skip the device we booted from
        [ "/dev/$name" = "$boot_dev" ] && continue

        # Skip USB devices (likely the install media)
        [ "$tran" = "usb" ] && continue

        local size_gb=$((size / 1073741824))
        echo "/dev/$name ${size_gb}GB ${model:-unknown}"
    done
}

select_target_disk() {
    section "Selecting Target Disk"

    local candidates
    candidates=$(list_candidate_disks)

    if [ -z "$candidates" ]; then
        fatal "No suitable disks found (need >=20GB, non-USB, non-boot)"
    fi

    info "Available disks:"
    echo "$candidates" | while read -r dev size model; do
        echo -e "  ${BOLD}${dev}${NC}  ${size}  ${DIM}${model}${NC}"
    done
    echo ""

    if [ "$MODE" = "unattended" ]; then
        # Pick the largest non-USB disk
        SELECTED_DISK=$(echo "$candidates" | sort -t' ' -k2 -rn | head -1 | awk '{print $1}')
        info "Auto-selected: ${SELECTED_DISK}"
    else
        # Let user pick
        local disk_list
        mapfile -t disk_list < <(echo "$candidates" | awk '{print $1}')

        if [ "${#disk_list[@]}" -eq 1 ]; then
            SELECTED_DISK="${disk_list[0]}"
            info "Only one disk available: ${SELECTED_DISK}"
        else
            echo -e "${CYAN}?${NC} Select target disk:"
            local i=1
            echo "$candidates" | while read -r dev size model; do
                echo "  ${i}) ${dev}  ${size}  ${model}"
                i=$((i + 1))
            done
            echo -n "> "
            read -r choice
            local idx=$((choice - 1))
            if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#disk_list[@]}" ]; then
                SELECTED_DISK="${disk_list[$idx]}"
            else
                fatal "Invalid selection"
            fi
        fi
    fi

    ok "Target disk: ${SELECTED_DISK}"
}

# ── Role Selection ───────────────────────────────────────────────────────────

detect_role() {
    section "Selecting Role"

    if [ -n "$SELECTED_ROLE" ]; then
        info "Role pre-set: ${SELECTED_ROLE}"
        return
    fi

    if [ "$MODE" = "unattended" ]; then
        # Auto-detect role based on hardware
        if [ "$DETECTED_IS_BEAM_NODE" = true ]; then
            SELECTED_ROLE="cluster"
            info "Auto-detected: cluster (beam node hardware)"
        elif [ "$DETECTED_HAS_GPU" = true ]; then
            SELECTED_ROLE="inference"
            info "Auto-detected: inference (GPU present)"
        elif [ "$DETECTED_RAM_GB" -le 8 ]; then
            SELECTED_ROLE="standalone"
            info "Auto-detected: standalone (<=8GB RAM)"
        else
            SELECTED_ROLE="standalone"
            info "Auto-detected: standalone (default)"
        fi
    else
        echo -e "  ${BOLD}1)${NC} standalone  — Full hecate stack on one machine"
        echo -e "  ${BOLD}2)${NC} cluster     — BEAM cluster member"
        echo -e "  ${BOLD}3)${NC} inference   — GPU inference server (Ollama)"
        echo -e "  ${BOLD}4)${NC} workstation — Standalone + Hyprland desktop"
        echo -e "  ${BOLD}5)${NC} desktop     — Full desktop daily driver"
        echo ""
        echo -n "> "
        read -r choice
        case "$choice" in
            1) SELECTED_ROLE="standalone" ;;
            2) SELECTED_ROLE="cluster" ;;
            3) SELECTED_ROLE="inference" ;;
            4) SELECTED_ROLE="workstation" ;;
            5) SELECTED_ROLE="desktop" ;;
            *) fatal "Invalid role selection" ;;
        esac
    fi

    # Pick matching disko layout
    case "$SELECTED_ROLE" in
        standalone|inference) SELECTED_DISKO_LAYOUT="standalone" ;;
        cluster)
            if [ "$DETECTED_IS_BEAM_NODE" = true ]; then
                SELECTED_DISKO_LAYOUT="beam-node"
            else
                SELECTED_DISKO_LAYOUT="cluster"
            fi
            ;;
        workstation|desktop) SELECTED_DISKO_LAYOUT="desktop" ;;
        *) SELECTED_DISKO_LAYOUT="standalone" ;;
    esac

    ok "Role: ${SELECTED_ROLE} (disko layout: ${SELECTED_DISKO_LAYOUT})"
}

# ── Hostname ─────────────────────────────────────────────────────────────────

select_hostname() {
    if [ -n "$SELECTED_HOSTNAME" ]; then
        return
    fi

    if [ "$MODE" = "unattended" ]; then
        SELECTED_HOSTNAME="hecate-${SELECTED_ROLE}"
    else
        echo ""
        echo -e "${CYAN}?${NC} Hostname [hecate-${SELECTED_ROLE}]: "
        read -r hn
        SELECTED_HOSTNAME="${hn:-hecate-${SELECTED_ROLE}}"
    fi

    ok "Hostname: ${SELECTED_HOSTNAME}"
}

# ── Generate Disko Config ───────────────────────────────────────────────────

generate_disko_config() {
    section "Generating Disk Layout"

    local disko_file="/tmp/hecate-disko-config.nix"

    if [ "$SELECTED_DISKO_LAYOUT" = "beam-node" ]; then
        # Beam nodes: detect eMMC + HDDs + NVMe
        local boot_dev="$SELECTED_DISK"
        local bulk0_dev bulk1_dev fast_dev
        bulk0_dev=$(lsblk -dnbo NAME,TYPE,TRAN 2>/dev/null | awk '$2=="disk" && $3!="usb" {print "/dev/"$1}' | grep -v "$boot_dev" | grep '/dev/sd' | head -1 || echo "")
        bulk1_dev=$(lsblk -dnbo NAME,TYPE,TRAN 2>/dev/null | awk '$2=="disk" && $3!="usb" {print "/dev/"$1}' | grep -v "$boot_dev" | grep '/dev/sd' | tail -1 || echo "")
        fast_dev=$(lsblk -dnbo NAME,TYPE,TRAN 2>/dev/null | awk '$2=="disk" && $3!="usb" {print "/dev/"$1}' | grep -v "$boot_dev" | grep 'nvme' | head -1 || echo "")

        # If bulk0 == bulk1, only one HDD
        [ "$bulk0_dev" = "$bulk1_dev" ] && bulk1_dev=""

        cat > "$disko_file" <<NIX
{ lib, ... }:

{
  imports = [ ${FLAKE_SOURCE}/disko/beam-node.nix ];

  disko.devices.disk.boot.device = "${boot_dev}";
  ${bulk0_dev:+disko.devices.disk.bulk0.device = "${bulk0_dev}";}
  ${bulk1_dev:+disko.devices.disk.bulk1.device = "${bulk1_dev}";}
  ${fast_dev:+disko.devices.disk.fast.device = "${fast_dev}";}
}
NIX
    else
        cat > "$disko_file" <<NIX
{ lib, ... }:

{
  imports = [ ${FLAKE_SOURCE}/disko/${SELECTED_DISKO_LAYOUT}.nix ];

  disko.devices.disk.main.device = "${SELECTED_DISK}";
}
NIX
    fi

    ok "Disko config written to ${disko_file}"
    info "Layout: ${SELECTED_DISKO_LAYOUT} on ${SELECTED_DISK}"
}

# ── Confirmation ─────────────────────────────────────────────────────────────

confirm_install() {
    echo ""
    echo -e "${BOLD}${RED}WARNING: This will ERASE ALL DATA on the following disk(s):${NC}"
    echo ""
    echo -e "  ${BOLD}Target:${NC}    ${SELECTED_DISK}"
    echo -e "  ${BOLD}Role:${NC}      ${SELECTED_ROLE}"
    echo -e "  ${BOLD}Hostname:${NC}  ${SELECTED_HOSTNAME}"
    echo -e "  ${BOLD}Layout:${NC}    ${SELECTED_DISKO_LAYOUT}"
    echo ""

    if [ "$MODE" = "unattended" ]; then
        echo -e "${YELLOW}Unattended mode: installing in ${COUNTDOWN_SECS} seconds...${NC}"
        echo -e "${YELLOW}Press Ctrl+C to cancel.${NC}"
        local i=$COUNTDOWN_SECS
        while [ "$i" -gt 0 ]; do
            echo -ne "\r  ${BOLD}${i}${NC} seconds remaining...  "
            sleep 1
            i=$((i - 1))
        done
        echo ""
    else
        echo -e "${CYAN}?${NC} Proceed with installation? [y/N] "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy] ]]; then
            info "Installation cancelled."
            exit 0
        fi
    fi
}

# ── Install ──────────────────────────────────────────────────────────────────

run_disko() {
    section "Partitioning Disks"

    local disko_file="/tmp/hecate-disko-config.nix"

    info "Running disko to partition and format ${SELECTED_DISK}..."
    disko --mode disko "$disko_file"

    ok "Disk partitioned and formatted"
}

run_nixos_install() {
    section "Installing NixOS"

    local flake_target="${FLAKE_SOURCE}#${SELECTED_ROLE}"

    # Generate hardware-configuration.nix for the target
    nixos-generate-config --root /mnt --no-filesystems 2>/dev/null || true

    # Build extra config module with hostname + cluster settings
    local extra_config="/tmp/hecate-extra-config.nix"
    cat > "$extra_config" <<NIX
{ lib, ... }:

{
  networking.hostName = "${SELECTED_HOSTNAME}";

  # Disko manages filesystems — disable default hardware-configuration mounts
  # (nixos-generate-config creates these but disko already handles them)
}
NIX

    # Add cluster config if applicable
    if [ "$SELECTED_ROLE" = "cluster" ] && [ -n "$CLUSTER_COOKIE" ]; then
        cat >> "$extra_config" <<NIX

  services.hecate.cluster = {
    cookie = "${CLUSTER_COOKIE}";
    ${CLUSTER_PEERS:+peers = [ ${CLUSTER_PEERS} ];}
  };
NIX
    fi

    info "Installing NixOS (flake: ${flake_target})..."
    info "This will download packages from the binary cache. Requires internet."
    echo ""

    nixos-install --flake "$flake_target" --no-root-password --extra-config "$extra_config"

    ok "NixOS installed successfully"
}

finish_install() {
    section "Installation Complete"

    echo -e "${GREEN}${BOLD}"
    echo "  hecatOS has been installed!"
    echo ""
    echo -e "${NC}${BOLD}  Summary:${NC}"
    echo -e "  ${BOLD}Hostname:${NC}  ${SELECTED_HOSTNAME}"
    echo -e "  ${BOLD}Role:${NC}      ${SELECTED_ROLE}"
    echo -e "  ${BOLD}Disk:${NC}      ${SELECTED_DISK}"
    echo ""
    echo -e "  ${DIM}The system will reboot in 5 seconds...${NC}"
    echo -e "  ${DIM}Remove the USB drive before the system starts.${NC}"
    echo ""

    sleep 5
    reboot
}

# ── Config File Parsing ─────────────────────────────────────────────────────

load_config_file() {
    local file="$1"

    if [ ! -f "$file" ]; then
        fatal "Config file not found: ${file}"
    fi

    info "Loading config from ${file}"

    # Parse JSON config (requires jq)
    if ! command -v jq &>/dev/null; then
        fatal "jq is required for --config. Install it or use --unattended."
    fi

    SELECTED_ROLE=$(jq -r '.role // empty' "$file" 2>/dev/null || echo "")
    SELECTED_DISK=$(jq -r '.disk // empty' "$file" 2>/dev/null || echo "")
    SELECTED_HOSTNAME=$(jq -r '.hostname // empty' "$file" 2>/dev/null || echo "")
    CLUSTER_COOKIE=$(jq -r '.cluster.cookie // "hecate_cluster_secret"' "$file" 2>/dev/null || echo "hecate_cluster_secret")
    CLUSTER_PEERS=$(jq -r '.cluster.peers // [] | map("\"" + . + "\"") | join(" ")' "$file" 2>/dev/null || echo "")

    [ -n "$SELECTED_ROLE" ] && ok "Role: ${SELECTED_ROLE}"
    [ -n "$SELECTED_DISK" ] && ok "Disk: ${SELECTED_DISK}"
    [ -n "$SELECTED_HOSTNAME" ] && ok "Hostname: ${SELECTED_HOSTNAME}"
}

# ── Argument Parsing ────────────────────────────────────────────────────────

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --unattended|-u)
                MODE="unattended"
                shift
                ;;
            --interactive|-i)
                MODE="interactive"
                shift
                ;;
            --config|-c)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --role)
                SELECTED_ROLE="$2"
                shift 2
                ;;
            --disk)
                SELECTED_DISK="$2"
                shift 2
                ;;
            --hostname)
                SELECTED_HOSTNAME="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: hecate-install [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --unattended, -u    No prompts, auto-detect everything (10s countdown)"
                echo "  --interactive, -i   Confirm role/disk/hostname before wipe (default)"
                echo "  --config, -c FILE   Load settings from JSON config file"
                echo "  --role ROLE         Pre-set role (standalone|cluster|inference|workstation|desktop)"
                echo "  --disk DEVICE       Pre-set target disk (e.g., /dev/sda)"
                echo "  --hostname NAME     Pre-set hostname"
                echo "  --help, -h          Show this help"
                echo ""
                echo "Config file format (JSON):"
                echo '  { "role": "standalone", "disk": "/dev/sda", "hostname": "my-node" }'
                exit 0
                ;;
            *)
                fatal "Unknown argument: $1 (use --help)"
                ;;
        esac
    done
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    parse_args "$@"

    # Must run as root
    if [ "$(id -u)" -ne 0 ]; then
        fatal "hecate-install must be run as root (try: sudo hecate-install)"
    fi

    # Verify flake source exists (baked into ISO at /etc/hecate-install)
    if [ ! -f "${FLAKE_SOURCE}/flake.nix" ]; then
        fatal "Flake source not found at ${FLAKE_SOURCE}. Are you booting from a hecatOS ISO?"
    fi

    # Load config file if provided
    if [ -n "$CONFIG_FILE" ]; then
        load_config_file "$CONFIG_FILE"
    fi

    show_banner
    detect_hardware

    # Select role (auto or interactive)
    detect_role

    # Select target disk (auto or interactive)
    if [ -z "$SELECTED_DISK" ]; then
        select_target_disk
    else
        ok "Disk pre-set: ${SELECTED_DISK}"
    fi

    # Select hostname
    select_hostname

    # Generate disko configuration
    generate_disko_config

    # Confirm before destructive operations
    confirm_install

    # Partition and format
    run_disko

    # Install NixOS
    run_nixos_install

    # Done — reboot
    finish_install
}

main "$@"
