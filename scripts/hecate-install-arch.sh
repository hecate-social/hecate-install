#!/usr/bin/env bash
#
# hecatOS Install Engine (Arch/CachyOS edition)
#
# Installs an Arch-based system with the hecatOS desktop from a live ISO.
# Supports CachyOS live USB as the boot medium.
#
# Usage:
#   hecate-install --interactive      # Guided install (default)
#   hecate-install --config file.json # Pre-set role/hostname/disk/cluster
#
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────

# Where this script and its assets live (auto-detected)
# When bundled in ISO: /usr/local/share/hecate-install
# When run from git checkout: parent of scripts/
if [ -d "/usr/local/share/hecate-install/packages" ]; then
    SCRIPT_DIR="/usr/local/share/hecate-install"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
MODE="interactive"
CONFIG_FILE=""

# Detected values
DETECTED_CPU_MODEL=""
DETECTED_RAM_GB=0
DETECTED_CPU_CORES=0
DETECTED_HAS_GPU=false
DETECTED_GPU_TYPE=""
DETECTED_UEFI=false
DETECTED_IS_LAPTOP=false

# Selected values
SELECTED_ROLE=""
SELECTED_DISK=""
SELECTED_HOSTNAME=""
SELECTED_HOME_DISK=""
SELECTED_ROOT_FS="ext4"
SELECTED_HOME_FS="ext4"

# OOBE values
SELECTED_KEYBOARD="us"
SELECTED_TIMEZONE="UTC"
SELECTED_LOCALE="en_US.UTF-8"
SELECTED_USERNAME="hecate"
SELECTED_FULLNAME=""
SELECTED_PASSWORD=""

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

show_banner() {
    echo ""
    echo -e "${BOLD}${CYAN}"
    echo "  _               _    ___  ____  "
    echo " | |__   ___  ___| |_ / _ \\/ ___| "
    echo " | '_ \\ / _ \\/ __| __| | | \\___ \\ "
    echo " | | | |  __/ (__| |_| |_| |___) |"
    echo " |_| |_|\\___|\\___|\\__|\\___/|____/ "
    echo ""
    echo -e "${NC}${DIM}  Arch-based distribution for the Hecate mesh${NC}"
    echo ""
}

# ── Read package list ───────────────────────────────────────────────────────

read_packages() {
    # Read a package list file, strip comments and blank lines
    local file="${SCRIPT_DIR}/packages/$1"
    [ -f "$file" ] || return
    grep -v '^#' "$file" | grep -v '^$' | tr '\n' ' '
}

# ── Dialog helpers ──────────────────────────────────────────────────────────

HAS_DIALOG=false
if command -v dialog &>/dev/null; then
    HAS_DIALOG=true
    export DIALOGRC="/etc/dialogrc"
fi

# Dialog wrapper — falls back to plain text if dialog isn't available
dlg_menu() {
    # Usage: dlg_menu "title" "item1" "desc1" "item2" "desc2" ...
    local title="$1"; shift
    if [ "$HAS_DIALOG" = true ]; then
        dialog --clear --backtitle "hecatOS Installer" --title "$title" \
            --menu "" 0 0 0 "$@" 3>&1 1>&2 2>&3
    else
        echo -e "\n${MAGENTA}${BOLD}━━━ $title ━━━${NC}\n" >&2
        local i=1
        while [ $# -ge 2 ]; do
            echo -e "  ${BOLD}${i})${NC} $1 — $2" >&2
            shift 2; i=$((i + 1))
        done
        echo -n "> " >&2
        read -r choice
        # Return the tag of the selected item
        local j=1
        while [ $# -ge 2 ]; do shift 2; j=$((j + 1)); done
        # Re-parse: we need the original args. Caller handles numeric input.
        echo "$choice"
    fi
}

dlg_input() {
    # Usage: dlg_input "title" "prompt" "default"
    local title="$1" prompt="$2" default="${3:-}"
    if [ "$HAS_DIALOG" = true ]; then
        dialog --clear --backtitle "hecatOS Installer" --title "$title" \
            --inputbox "$prompt" 0 60 "$default" 3>&1 1>&2 2>&3
    else
        echo -en "  ${CYAN}?${NC} ${prompt} [${default}]: " >&2
        read -r input
        echo "${input:-$default}"
    fi
}

dlg_password() {
    # Usage: dlg_password "title" "prompt"
    local title="$1" prompt="$2"
    if [ "$HAS_DIALOG" = true ]; then
        dialog --clear --backtitle "hecatOS Installer" --title "$title" \
            --insecure --passwordbox "$prompt" 0 60 3>&1 1>&2 2>&3
    else
        echo -en "  ${CYAN}?${NC} ${prompt}: " >&2
        read -rs pass
        echo "" >&2
        echo "$pass"
    fi
}

dlg_yesno() {
    # Usage: dlg_yesno "title" "question" — returns 0=yes, 1=no
    local title="$1" question="$2"
    if [ "$HAS_DIALOG" = true ]; then
        dialog --clear --backtitle "hecatOS Installer" --title "$title" \
            --yesno "$question" 0 0
    else
        echo -en "${CYAN}?${NC} ${question} [Y/n] " >&2
        read -r yn
        [[ "$yn" =~ ^[Nn] ]] && return 1 || return 0
    fi
}

dlg_msg() {
    # Usage: dlg_msg "title" "message"
    local title="$1" message="$2"
    if [ "$HAS_DIALOG" = true ]; then
        dialog --clear --backtitle "hecatOS Installer" --title "$title" \
            --msgbox "$message" 0 0
    else
        echo -e "\n${BOLD}$title${NC}\n$message\n" >&2
    fi
}

dlg_gauge() {
    # Usage: echo "50" | dlg_gauge "title" "message"
    local title="$1" message="$2"
    if [ "$HAS_DIALOG" = true ]; then
        dialog --backtitle "hecatOS Installer" --title "$title" \
            --gauge "$message" 7 60 0
    else
        cat > /dev/null  # consume stdin
    fi
}

# ── Hardware Detection ───────────────────────────────────────────────────────

# ── Network ──────────────────────────────────────────────────────────────────

ensure_network() {
    section "Network"

    # Already online?
    if ping -c 1 -W 3 archlinux.org &>/dev/null; then
        ok "Internet connected"
        return
    fi

    warn "No internet connection detected."
    info "Internet is required to download packages."
    echo ""

    # Check if WiFi hardware exists
    local wifi_dev=""
    wifi_dev=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1 || echo "")

    if [ -n "$wifi_dev" ]; then
        info "WiFi device found: ${wifi_dev}"
        echo ""

        # Try nmcli first (if NetworkManager is running on the live ISO)
        if command -v nmcli &>/dev/null && systemctl is-active NetworkManager &>/dev/null; then
            info "Scanning for WiFi networks..."
            nmcli device wifi rescan 2>/dev/null || true
            sleep 2
            nmcli device wifi list 2>/dev/null
            echo ""
            local ssid=""
            ssid=$(dlg_input "WiFi" "Enter WiFi network name (SSID):" "") || true
            if [ -n "$ssid" ]; then
                local wifi_pass=""
                wifi_pass=$(dlg_password "WiFi" "Password for ${ssid}:") || true
                if [ -n "$wifi_pass" ]; then
                    nmcli device wifi connect "$ssid" password "$wifi_pass" 2>&1 || true
                else
                    nmcli device wifi connect "$ssid" 2>&1 || true
                fi
                sleep 3
            fi
        # Fall back to iwctl
        elif command -v iwctl &>/dev/null; then
            info "Use iwctl to connect:"
            echo -e "  ${DIM}iwctl station ${wifi_dev} scan${NC}"
            echo -e "  ${DIM}iwctl station ${wifi_dev} get-networks${NC}"
            echo -e "  ${DIM}iwctl station ${wifi_dev} connect YOUR_SSID${NC}"
            echo ""
            echo -e "${CYAN}?${NC} Opening iwctl. Type 'exit' when connected."
            iwctl
        fi

        # Recheck
        sleep 2
        if ping -c 1 -W 3 archlinux.org &>/dev/null; then
            ok "Internet connected"
            return
        fi
    fi

    # Wired — try dhcpcd
    if command -v dhcpcd &>/dev/null; then
        info "Trying DHCP on wired interfaces..."
        dhcpcd &>/dev/null &
        sleep 5
        if ping -c 1 -W 3 archlinux.org &>/dev/null; then
            ok "Internet connected (wired)"
            return
        fi
    fi

    fatal "No internet connection. Cannot continue.\n  Connect manually and re-run the installer."
}

# ── Hardware Detection ───────────────────────────────────────────────────────

detect_hardware() {
    section "Detecting Hardware"

    DETECTED_CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "Unknown")
    info "CPU: ${DETECTED_CPU_MODEL}"

    DETECTED_RAM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo "0")
    info "RAM: ${DETECTED_RAM_GB} GB"

    DETECTED_CPU_CORES=$(nproc 2>/dev/null || echo "1")
    info "CPU cores: ${DETECTED_CPU_CORES}"

    if lspci 2>/dev/null | grep -qi 'nvidia'; then
        DETECTED_HAS_GPU=true
        DETECTED_GPU_TYPE="nvidia"
    elif lspci 2>/dev/null | grep -qi 'AMD.*Radeon\|ATI'; then
        DETECTED_HAS_GPU=true
        DETECTED_GPU_TYPE="amd"
    fi
    [ "$DETECTED_HAS_GPU" = true ] && info "GPU: ${DETECTED_GPU_TYPE}" || info "GPU: None detected"

    if [ -d /sys/firmware/efi ]; then
        DETECTED_UEFI=true
        info "Boot: UEFI"
    else
        info "Boot: BIOS (legacy)"
    fi

    if [ -d /sys/class/power_supply ] && ls /sys/class/power_supply/BAT* &>/dev/null; then
        DETECTED_IS_LAPTOP=true
        info "Form factor: Laptop"
    else
        info "Form factor: Desktop/Server"
    fi
}

# ── Disk Selection ──────────────────────────────────────────────────────────

list_candidate_disks() {
    local boot_dev
    boot_dev=$(findmnt -n -o SOURCE / 2>/dev/null | sed 's/[0-9]*$//' | sed 's/p[0-9]*$//' || echo "")

    lsblk -dnbo NAME,SIZE,TYPE,TRAN,MODEL 2>/dev/null | while read -r name size dtype tran model; do
        [ "$dtype" != "disk" ] && continue
        [ "$size" -lt 21474836480 ] 2>/dev/null && continue
        [ "/dev/$name" = "$boot_dev" ] && continue
        [ "$tran" = "usb" ] && continue
        local size_gb=$((size / 1073741824))
        echo "/dev/$name ${size_gb}GB ${model:-unknown}"
    done
}

select_target_disk() {
    local candidates
    candidates=$(list_candidate_disks)
    [ -z "$candidates" ] && fatal "No suitable disks found (need >=20GB, non-USB, non-boot)"

    local disk_count
    disk_count=$(echo "$candidates" | wc -l)

    # Build dialog items as array (handles spaces in model names)
    local -a disk_items=()
    while read -r dev size model; do
        disk_items+=("$dev" "${size} ${model:-unknown}")
    done <<< "$candidates"

    # Ask about dual-disk for desktop roles with multiple disks
    if [ "$disk_count" -ge 2 ] && [[ "$SELECTED_ROLE" =~ ^(desktop|workstation|llm-host)$ ]]; then
        if dlg_yesno "Disk Layout" "Multiple disks detected.\n\nUse a separate disk for /home?\n(Recommended: OS on SSD, /home on HDD)"; then
            SELECTED_DISK=$(dlg_menu "Select OS Disk (root + boot + swap)" "${disk_items[@]}") || fatal "No disk selected"

            # Rebuild items without the selected OS disk
            local -a home_items=()
            while read -r dev size model; do
                [ "$dev" = "$SELECTED_DISK" ] && continue
                home_items+=("$dev" "${size} ${model:-unknown}")
            done <<< "$candidates"

            SELECTED_HOME_DISK=$(dlg_menu "Select /home Disk" "${home_items[@]}") || fatal "No home disk selected"
        else
            SELECTED_DISK=$(dlg_menu "Select Target Disk" "${disk_items[@]}") || fatal "No disk selected"
        fi
    else
        SELECTED_DISK=$(dlg_menu "Select Target Disk" "${disk_items[@]}") || fatal "No disk selected"
    fi
}

select_filesystem() {
    SELECTED_ROOT_FS=$(dlg_menu "Filesystem for / (root)" \
        "ext4"  "Stable, well-tested (recommended)" \
        "btrfs" "Snapshots, compression, copy-on-write" \
        "xfs"   "High performance, large files") || SELECTED_ROOT_FS="ext4"

    if [ -n "$SELECTED_HOME_DISK" ]; then
        SELECTED_HOME_FS=$(dlg_menu "Filesystem for /home" \
            "ext4"  "Stable, well-tested (recommended)" \
            "btrfs" "Snapshots, compression, copy-on-write" \
            "xfs"   "High performance, large files") || SELECTED_HOME_FS="ext4"
    fi
}

# ── Role Selection ──────────────────────────────────────────────────────────

select_role() {
    [ -n "$SELECTED_ROLE" ] && return

    SELECTED_ROLE=$(dlg_menu "Select Role" \
        "desktop"     "Full desktop + hecate daemon + web UI" \
        "workstation" "Desktop + dev tools + hecate daemon" \
        "llm-host"    "Desktop + Ollama LLM server + hecate daemon" \
        "standalone"  "Headless hecate node (daemon only)" \
        "cluster"     "BEAM cluster member (daemon only)") || fatal "No role selected"
}

# ── OOBE (hostname, keyboard, timezone, locale, user) ───────────────────────

select_hostname() {
    SELECTED_HOSTNAME=$(dlg_input "Hostname" "Enter a hostname for this machine:" "hecate00") || true
    SELECTED_HOSTNAME="${SELECTED_HOSTNAME:-hecate00}"
}

select_keyboard() {
    # Build keyboard list from available keymaps
    local kb_items=""
    kb_items="us US-English "
    kb_items+="uk UK-English "
    kb_items+="de German "
    kb_items+="fr French "
    kb_items+="be Belgian "
    kb_items+="nl Dutch "
    kb_items+="es Spanish "
    kb_items+="it Italian "
    kb_items+="pt Portuguese "
    kb_items+="br Brazilian "
    kb_items+="se Swedish "
    kb_items+="no Norwegian "
    kb_items+="dk Danish "
    kb_items+="fi Finnish "
    kb_items+="pl Polish "
    kb_items+="cz Czech "
    kb_items+="hu Hungarian "
    kb_items+="ro Romanian "
    kb_items+="jp Japanese "
    kb_items+="kr Korean "
    kb_items+="ru Russian "

    # shellcheck disable=SC2086
    SELECTED_KEYBOARD=$(dlg_menu "Keyboard Layout" $kb_items) || SELECTED_KEYBOARD="us"
    loadkeys "$SELECTED_KEYBOARD" 2>/dev/null || true
}

select_timezone() {
    # Auto-detect timezone
    local detected_tz=""
    detected_tz=$(curl -s --max-time 5 "http://ip-api.com/line/?fields=timezone" 2>/dev/null || echo "")
    local default_tz="${detected_tz:-UTC}"

    # Build region list
    local regions=""
    regions="Europe/ Europe "
    regions+="America/ Americas "
    regions+="Asia/ Asia "
    regions+="Africa/ Africa "
    regions+="Australia/ Australia "
    regions+="Pacific/ Pacific "
    regions+="UTC UTC "

    if [ "$HAS_DIALOG" = true ]; then
        # Two-step: pick region, then city
        if [ -n "$detected_tz" ]; then
            if dlg_yesno "Timezone" "Detected timezone: ${detected_tz}\n\nIs this correct?"; then
                SELECTED_TIMEZONE="$detected_tz"
                return
            fi
        fi

        # shellcheck disable=SC2086
        local region
        region=$(dlg_menu "Timezone — Region" $regions) || { SELECTED_TIMEZONE="$default_tz"; return; }

        if [ "$region" = "UTC" ]; then
            SELECTED_TIMEZONE="UTC"
            return
        fi

        # List cities in region
        local city_items=""
        while IFS= read -r city; do
            local label="${city//_/ }"
            city_items+="${city} ${label} "
        done < <(find "/usr/share/zoneinfo/${region}" -maxdepth 1 -type f -printf '%f\n' | sort)

        # shellcheck disable=SC2086
        local city
        city=$(dlg_menu "Timezone — City" $city_items) || { SELECTED_TIMEZONE="$default_tz"; return; }
        SELECTED_TIMEZONE="${region}${city}"
    else
        SELECTED_TIMEZONE=$(dlg_input "Timezone" "Enter timezone:" "$default_tz") || true
        SELECTED_TIMEZONE="${SELECTED_TIMEZONE:-$default_tz}"
    fi
}

select_locale() {
    SELECTED_LOCALE=$(dlg_menu "Language / Locale" \
        "en_US.UTF-8" "English (US)" \
        "en_GB.UTF-8" "English (UK)" \
        "de_DE.UTF-8" "German" \
        "fr_FR.UTF-8" "French" \
        "nl_NL.UTF-8" "Dutch" \
        "nl_BE.UTF-8" "Dutch (Belgium)" \
        "es_ES.UTF-8" "Spanish" \
        "it_IT.UTF-8" "Italian" \
        "pt_BR.UTF-8" "Portuguese (Brazil)" \
        "pl_PL.UTF-8" "Polish" \
        "ru_RU.UTF-8" "Russian" \
        "ja_JP.UTF-8" "Japanese" \
        "ko_KR.UTF-8" "Korean" \
        "zh_CN.UTF-8" "Chinese (Simplified)") || SELECTED_LOCALE="en_US.UTF-8"
}

create_user() {
    SELECTED_USERNAME=$(dlg_input "User Account" "Enter your username:" "hecate") || true
    SELECTED_USERNAME="${SELECTED_USERNAME:-hecate}"

    if ! [[ "$SELECTED_USERNAME" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
        dlg_msg "Invalid Username" "Username must start with a lowercase letter.\nUsing 'hecate'."
        SELECTED_USERNAME="hecate"
    fi

    SELECTED_FULLNAME=$(dlg_input "User Account" "Full name (optional):" "") || true

    local password_ok=false
    while [ "$password_ok" = false ]; do
        local pass1 pass2
        pass1=$(dlg_password "User Account" "Enter password for ${SELECTED_USERNAME}:") || true
        [ -z "$pass1" ] && { dlg_msg "Error" "Password cannot be empty."; continue; }
        [ "${#pass1}" -lt 4 ] && { dlg_msg "Error" "Password must be at least 4 characters."; continue; }

        pass2=$(dlg_password "User Account" "Confirm password:") || true
        if [ "$pass1" != "$pass2" ]; then
            dlg_msg "Error" "Passwords do not match. Try again."
        else
            SELECTED_PASSWORD="$pass1"
            password_ok=true
        fi
    done
}

# ── Confirmation ────────────────────────────────────────────────────────────

confirm_install() {
    local summary=""
    summary+="OS disk:    ${SELECTED_DISK} (${SELECTED_ROOT_FS})\n"
    [ -n "$SELECTED_HOME_DISK" ] && \
    summary+="Home disk:  ${SELECTED_HOME_DISK} (${SELECTED_HOME_FS})\n"
    summary+="Role:       ${SELECTED_ROLE}\n"
    summary+="Hostname:   ${SELECTED_HOSTNAME}\n"
    summary+="Keyboard:   ${SELECTED_KEYBOARD}\n"
    summary+="Timezone:   ${SELECTED_TIMEZONE}\n"
    summary+="Locale:     ${SELECTED_LOCALE}\n"
    summary+="User:       ${SELECTED_USERNAME}\n"
    summary+="\n⚠  WARNING: This will ERASE ALL DATA on the selected disk(s)!"

    dlg_yesno "Confirm Installation" "$summary" || { info "Installation cancelled."; exit 0; }
}

# ── Partitioning ────────────────────────────────────────────────────────────

partition_disks() {
    section "Partitioning Disks"

    # Wipe existing signatures
    info "Wiping disk signatures..."
    wipefs -af "${SELECTED_DISK}" 2>/dev/null || true
    sgdisk --zap-all "${SELECTED_DISK}" 2>/dev/null || true
    if [ -n "$SELECTED_HOME_DISK" ]; then
        wipefs -af "${SELECTED_HOME_DISK}" 2>/dev/null || true
        sgdisk --zap-all "${SELECTED_HOME_DISK}" 2>/dev/null || true
    fi

    # ── OS disk: ESP + swap + root ──
    info "Partitioning ${SELECTED_DISK}..."

    local swap_size="8G"
    [[ "$SELECTED_ROLE" =~ ^(standalone|cluster)$ ]] && swap_size="4G"

    if [ "$DETECTED_UEFI" = true ]; then
        sgdisk -n 1:0:+512M -t 1:ef00 -c 1:ESP "${SELECTED_DISK}"
        sgdisk -n 2:0:+${swap_size} -t 2:8200 -c 2:swap "${SELECTED_DISK}"
        sgdisk -n 3:0:0 -t 3:8300 -c 3:root "${SELECTED_DISK}"
    else
        # BIOS: MBR with parted
        parted -s "${SELECTED_DISK}" mklabel msdos
        parted -s "${SELECTED_DISK}" mkpart primary linux-swap 1MiB "${swap_size}"
        parted -s "${SELECTED_DISK}" mkpart primary "${swap_size}" 100%
        parted -s "${SELECTED_DISK}" set 2 boot on
    fi

    # Wait for kernel to update partition table
    partprobe "${SELECTED_DISK}" 2>/dev/null || true
    sleep 1

    # Determine partition device names (handles nvme vs sd naming)
    local part_prefix="${SELECTED_DISK}"
    [[ "$SELECTED_DISK" =~ nvme|mmcblk ]] && part_prefix="${SELECTED_DISK}p"

    if [ "$DETECTED_UEFI" = true ]; then
        local esp_part="${part_prefix}1"
        local swap_part="${part_prefix}2"
        local root_part="${part_prefix}3"
    else
        local swap_part="${part_prefix}1"
        local root_part="${part_prefix}2"
    fi

    # ── Format ──
    info "Formatting partitions..."

    [ "$DETECTED_UEFI" = true ] && mkfs.vfat -F 32 "$esp_part"

    mkswap "$swap_part"

    case "$SELECTED_ROOT_FS" in
        ext4)  mkfs.ext4 -F "$root_part" ;;
        btrfs) mkfs.btrfs -f "$root_part" ;;
        xfs)   mkfs.xfs -f "$root_part" ;;
    esac

    # ── Home disk (if dual-disk) ──
    if [ -n "$SELECTED_HOME_DISK" ]; then
        info "Partitioning ${SELECTED_HOME_DISK}..."
        sgdisk -n 1:0:0 -t 1:8300 -c 1:home "${SELECTED_HOME_DISK}"
        partprobe "${SELECTED_HOME_DISK}" 2>/dev/null || true
        sleep 1

        local home_prefix="${SELECTED_HOME_DISK}"
        [[ "$SELECTED_HOME_DISK" =~ nvme|mmcblk ]] && home_prefix="${SELECTED_HOME_DISK}p"
        local home_part="${home_prefix}1"

        case "$SELECTED_HOME_FS" in
            ext4)  mkfs.ext4 -F "$home_part" ;;
            btrfs) mkfs.btrfs -f "$home_part" ;;
            xfs)   mkfs.xfs -f "$home_part" ;;
        esac
    fi

    # ── Mount ──
    info "Mounting filesystems..."
    mount "$root_part" /mnt

    if [ "$DETECTED_UEFI" = true ]; then
        mkdir -p /mnt/boot
        mount "$esp_part" /mnt/boot
    fi

    swapon "$swap_part"

    if [ -n "$SELECTED_HOME_DISK" ]; then
        mkdir -p /mnt/home
        mount "$home_part" /mnt/home
    fi

    ok "Disks partitioned, formatted, and mounted"
}

# ── Install base system ─────────────────────────────────────────────────────

install_base() {
    section "Installing Base System"

    # Verify network before downloading
    ping -c 1 -W 3 archlinux.org &>/dev/null || fatal "No internet. Cannot download packages."

    local base_pkgs
    base_pkgs=$(read_packages base.txt)

    info "Installing base packages with pacstrap (this will take several minutes)..."
    # shellcheck disable=SC2086
    pacstrap -K /mnt $base_pkgs || fatal "pacstrap failed. Check internet connection and disk space."

    ok "Base system installed"
}

generate_fstab() {
    info "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    ok "fstab generated"
}

# ── Configure system ────────────────────────────────────────────────────────

configure_system() {
    section "Configuring System"

    # Timezone
    arch-chroot /mnt ln -sf "/usr/share/zoneinfo/${SELECTED_TIMEZONE}" /etc/localtime
    arch-chroot /mnt hwclock --systohc
    ok "Timezone: ${SELECTED_TIMEZONE}"

    # Locale
    echo "${SELECTED_LOCALE} UTF-8" > /mnt/etc/locale.gen
    echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen
    echo "LANG=${SELECTED_LOCALE}" > /mnt/etc/locale.conf
    ok "Locale: ${SELECTED_LOCALE}"

    # Console keymap
    echo "KEYMAP=${SELECTED_KEYBOARD}" > /mnt/etc/vconsole.conf
    ok "Keyboard: ${SELECTED_KEYBOARD}"

    # Hostname
    echo "${SELECTED_HOSTNAME}" > /mnt/etc/hostname
    cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${SELECTED_HOSTNAME}.localdomain ${SELECTED_HOSTNAME}
EOF
    ok "Hostname: ${SELECTED_HOSTNAME}"

    # User
    arch-chroot /mnt useradd -m -G wheel,podman -s /bin/zsh "$SELECTED_USERNAME"
    echo "${SELECTED_USERNAME}:${SELECTED_PASSWORD}" | arch-chroot /mnt chpasswd
    [ -n "$SELECTED_FULLNAME" ] && arch-chroot /mnt chfn -f "$SELECTED_FULLNAME" "$SELECTED_USERNAME"
    ok "User: ${SELECTED_USERNAME}"

    # Sudo
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /mnt/etc/sudoers
    ok "Sudo enabled for wheel group"

    # Enable lingering for user (podman user services)
    mkdir -p /mnt/var/lib/systemd/linger
    touch "/mnt/var/lib/systemd/linger/${SELECTED_USERNAME}"
}

# ── Bootloader ──────────────────────────────────────────────────────────────

install_bootloader() {
    section "Installing Bootloader"

    if [ "$DETECTED_UEFI" = true ]; then
        arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=hecatOS
    else
        arch-chroot /mnt grub-install --target=i386-pc "${SELECTED_DISK}"
    fi

    # NVIDIA kernel params
    if [ "$DETECTED_GPU_TYPE" = "nvidia" ]; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& nvidia-drm.modeset=1 nvidia-drm.fbdev=1/' /mnt/etc/default/grub
    fi

    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    ok "Bootloader installed"
}

# ── Desktop packages ────────────────────────────────────────────────────────

install_desktop() {
    section "Installing Desktop Environment"

    local desktop_pkgs
    desktop_pkgs=$(read_packages desktop.txt)

    info "Installing desktop packages..."
    # shellcheck disable=SC2086
    arch-chroot /mnt pacman -S --noconfirm --needed $desktop_pkgs

    # NVIDIA
    if [ "$DETECTED_GPU_TYPE" = "nvidia" ]; then
        info "Installing NVIDIA drivers..."
        local nvidia_pkgs
        nvidia_pkgs=$(read_packages nvidia.txt)
        # shellcheck disable=SC2086
        arch-chroot /mnt pacman -S --noconfirm --needed $nvidia_pkgs
        cp "${SCRIPT_DIR}/configs/nvidia.sh" /mnt/etc/profile.d/hecate-nvidia.sh
    fi

    # Laptop
    if [ "$DETECTED_IS_LAPTOP" = true ]; then
        info "Installing laptop power management..."
        local laptop_pkgs
        laptop_pkgs=$(read_packages laptop.txt)
        # shellcheck disable=SC2086
        arch-chroot /mnt pacman -S --noconfirm --needed $laptop_pkgs
    fi

    ok "Desktop packages installed"
}

# ── Install AUR helper + AUR packages ───────────────────────────────────────

install_aur_packages() {
    section "Installing AUR Packages"

    local user_home="/mnt/home/${SELECTED_USERNAME}"

    # Install paru as the AUR helper
    info "Installing paru (AUR helper)..."
    arch-chroot /mnt su - "$SELECTED_USERNAME" -c \
        'cd /tmp && git clone https://aur.archlinux.org/paru-bin.git && cd paru-bin && makepkg -si --noconfirm && cd .. && rm -rf paru-bin'

    # Install AUR packages
    local aur_pkgs
    aur_pkgs=$(read_packages aur.txt)
    if [ -n "$aur_pkgs" ]; then
        info "Installing AUR packages..."
        # shellcheck disable=SC2086
        arch-chroot /mnt su - "$SELECTED_USERNAME" -c "paru -S --noconfirm --needed $aur_pkgs"
    fi

    ok "AUR packages installed"
}

# ── Deploy dotfiles ─────────────────────────────────────────────────────────

deploy_dotfiles() {
    section "Deploying Configuration"

    local user_home="/mnt/home/${SELECTED_USERNAME}"
    local config_dir="${user_home}/.config"
    mkdir -p "$config_dir"

    # ── Hyprland ──
    cp -r "${SCRIPT_DIR}/dotfiles/hypr" "${config_dir}/hypr"
    chmod +x "${config_dir}/hypr/scripts/"*.sh
    # Copy default wallpaper
    if [ -d "${SCRIPT_DIR}/dotfiles/wallpapers" ]; then
        cp -r "${SCRIPT_DIR}/dotfiles/wallpapers" "${config_dir}/hypr/wallpapers"
        # Set default wallpaper
        local default_wp
        default_wp=$(ls "${config_dir}/hypr/wallpapers/"*.{png,jpg} 2>/dev/null | head -1 || echo "")
        if [ -n "$default_wp" ]; then
            ln -sf "$default_wp" "${config_dir}/hypr/wallpaper.png"
        fi
    fi
    ok "Hyprland config deployed"

    # ── Kitty ──
    cp -r "${SCRIPT_DIR}/dotfiles/kitty" "${config_dir}/kitty"
    ok "Kitty config deployed"

    # ── Waybar ──
    cp -r "${SCRIPT_DIR}/dotfiles/waybar" "${config_dir}/waybar"
    ok "Waybar config deployed"

    # ── Rofi ──
    cp -r "${SCRIPT_DIR}/dotfiles/rofi" "${config_dir}/rofi"
    ok "Rofi config deployed"

    # ── Neovim ──
    cp -r "${SCRIPT_DIR}/dotfiles/nvim" "${config_dir}/nvim"
    # Pre-install LazyVim plugins so nvim is ready on first launch
    info "Installing Neovim plugins (this may take a minute)..."
    arch-chroot /mnt su - "$SELECTED_USERNAME" -c 'nvim --headless "+Lazy! sync" +qa 2>/dev/null' || true
    ok "Neovim config + plugins deployed"

    # ── Starship ──
    cp "${SCRIPT_DIR}/dotfiles/starship.toml" "${config_dir}/starship.toml"
    ok "Starship config deployed"

    # ── Fastfetch ──
    cp -r "${SCRIPT_DIR}/dotfiles/fastfetch" "${config_dir}/fastfetch"
    ok "Fastfetch config deployed"

    # ── Zsh ──
    cat > "${user_home}/.zshrc" <<'ZSHRC'
# hecatOS zsh configuration
export ZSH="/usr/share/oh-my-zsh"
ZSH_THEME=""  # Using starship instead

plugins=(git sudo docker zsh-autosuggestions zsh-syntax-highlighting)

# Oh My Zsh
[ -f "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"

# Starship prompt
eval "$(starship init zsh)"

# Zoxide (smart cd)
eval "$(zoxide init zsh)"

# direnv
eval "$(direnv hook zsh)"

# FZF
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh

export FZF_DEFAULT_OPTS="
  --color=fg:#c0caf5,bg:#1a1b26,hl:#ff9e64
  --color=fg+:#c0caf5,bg+:#292e42,hl+:#ff9e64
  --color=info:#7aa2f7,prompt:#7dcfff,pointer:#7aa2f7
  --color=marker:#9ece6a,spinner:#9ece6a,header:#9ece6a
  --bind 'ctrl-/:toggle-preview,ctrl-d:half-page-down,ctrl-u:half-page-up'"

# Aliases
alias c=clear
alias cat='bat --paging=never'
alias ls='eza -a --icons=always'
alias ll='eza -la --icons=always'
alias lt='eza -a --tree --level=1 --icons=always'
alias la='eza -la --git --icons=always'
alias v=nvim
alias vim=nvim
alias lg=lazygit
alias lzd=lazydocker
alias fm=yazi
alias du=dust
alias df=duf
alias ping=gping
alias dig=doggo
alias ps=procs
alias sed=sd
alias cut=choose
alias http=xh
alias bench=hyperfine
alias watch=viddy
alias j=just
alias less='bat --paging=always'
alias hex=hexyl
alias loc=tokei

# Fuzzy file editor
fe() {
    local file
    file=$(fzf --preview 'bat --color=always {}' --preview-window '~3')
    [ -n "$file" ] && nvim "$file"
}

# Fuzzy process killer
fkill() {
    local pid
    pid=$(ps aux | fzf --header-lines=1 | awk '{print $2}')
    [ -n "$pid" ] && kill -9 "$pid"
}

# Fuzzy git branch
fgb() {
    local branch
    branch=$(git branch -a | fzf | tr -d '[:space:]' | sed 's|remotes/origin/||')
    [ -n "$branch" ] && git checkout "$branch"
}

# Hecate first-boot initialization
[ -f ~/.config/zsh/hecate-first-boot.zsh ] && source ~/.config/zsh/hecate-first-boot.zsh

# Show fastfetch on interactive shell start
if [[ $- == *i* ]] && [ -z "$TMUX" ] && [ -z "$ZELLIJ" ]; then
    fastfetch
fi
ZSHRC
    ok "Zsh config deployed"

    # ── GTK theming ──
    mkdir -p "${config_dir}/gtk-3.0" "${config_dir}/gtk-4.0"
    cat > "${config_dir}/gtk-3.0/settings.ini" <<GTK3
[Settings]
gtk-theme-name=Tokyonight-Dark-BL
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Bibata-Modern-Ice
gtk-cursor-theme-size=24
gtk-font-name=Cantarell 11
gtk-application-prefer-dark-theme=1
GTK3
    cp "${config_dir}/gtk-3.0/settings.ini" "${config_dir}/gtk-4.0/settings.ini"
    ok "GTK theming deployed"

    # ── Qt theming ──
    mkdir -p "${config_dir}/qt5ct" "${config_dir}/qt6ct"
    cat > "${config_dir}/qt5ct/qt5ct.conf" <<QT5
[Appearance]
style=kvantum
icon_theme=Papirus-Dark
QT5
    cp "${config_dir}/qt5ct/qt5ct.conf" "${config_dir}/qt6ct/qt6ct.conf"
    ok "Qt theming deployed"

    # ── XDG MIME defaults ──
    mkdir -p "${config_dir}"
    cat > "${config_dir}/mimeapps.list" <<MIME
[Default Applications]
application/pdf=org.pwmt.zathura.desktop
image/png=imv.desktop
image/jpeg=imv.desktop
image/gif=imv.desktop
image/webp=imv.desktop
video/mp4=mpv.desktop
video/x-matroska=mpv.desktop
video/webm=mpv.desktop
audio/mpeg=mpv.desktop
audio/flac=mpv.desktop
application/zip=org.gnome.FileRoller.desktop
application/x-tar=org.gnome.FileRoller.desktop
MIME
    ok "MIME defaults deployed"

    # ── Environment variables ──
    cp "${SCRIPT_DIR}/configs/environment.sh" /mnt/etc/profile.d/hecate.sh
    ok "Environment variables deployed"

    # ── Fix ownership ──
    arch-chroot /mnt chown -R "${SELECTED_USERNAME}:${SELECTED_USERNAME}" "/home/${SELECTED_USERNAME}"
    ok "File ownership set"
}

# ── Enable services ─────────────────────────────────────────────────────────

# ── Install hecate stack ─────────────────────────────────────────────────────

install_hecate_stack() {
    section "Installing Hecate Stack"

    local user_home="/mnt/home/${SELECTED_USERNAME}"

    # ── hecate-daemon (OCI container via podman) ──
    info "Configuring hecate-daemon..."
    local hecate_home="${user_home}/.hecate"
    mkdir -p "${hecate_home}"/{hecate-daemon/{sqlite,reckon-db,sockets,run},compose,secrets}

    # Docker compose file for hecate-daemon
    cat > "${hecate_home}/compose/docker-compose.yml" <<'COMPOSE'
services:
  hecate-daemon:
    image: ghcr.io/hecate-social/hecate-daemon:latest
    container_name: hecate-daemon
    restart: unless-stopped
    volumes:
      - ${HECATE_HOME:-~/.hecate}/hecate-daemon:/data
    environment:
      - HECATE_HOME=/data
    network_mode: host
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /run/user/1000/podman/podman.sock:/var/run/docker.sock:ro
    environment:
      - WATCHTOWER_POLL_INTERVAL=60
      - WATCHTOWER_LABEL_ENABLE=true
      - WATCHTOWER_CLEANUP=true
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
COMPOSE

    # Systemd user service for hecate-daemon
    local systemd_user="${user_home}/.config/systemd/user"
    mkdir -p "$systemd_user"

    cat > "${systemd_user}/hecate-daemon.service" <<SYSTEMD
[Unit]
Description=Hecate Daemon (podman-compose)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=HECATE_HOME=%h/.hecate
WorkingDirectory=%h/.hecate/compose
ExecStart=/usr/bin/podman-compose up
ExecStop=/usr/bin/podman-compose down
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
SYSTEMD
    ok "hecate-daemon configured"

    # ── hecate-web (Tauri desktop app) ──
    if [[ "$SELECTED_ROLE" =~ ^(desktop|workstation|llm-host)$ ]]; then
        info "hecate-web will be available via the hecate CLI after first boot"
        # TODO: Install hecate-web from GitHub releases or AUR
        # For now, the web UI is accessed via the daemon's HTTP API
    fi

    # ── Ollama (LLM host role) ──
    if [ "$SELECTED_ROLE" = "llm-host" ]; then
        info "Installing Ollama..."
        arch-chroot /mnt pacman -S --noconfirm --needed ollama
        # Enable Ollama service
        cat > "${systemd_user}/ollama.service" <<SYSTEMD
[Unit]
Description=Ollama LLM Server
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/ollama serve
Restart=on-failure
RestartSec=5
Environment=OLLAMA_HOST=0.0.0.0

[Install]
WantedBy=default.target
SYSTEMD
        ok "Ollama configured"
    fi

    # ── Fix ownership ──
    arch-chroot /mnt chown -R "${SELECTED_USERNAME}:${SELECTED_USERNAME}" "/home/${SELECTED_USERNAME}/.hecate"
    arch-chroot /mnt chown -R "${SELECTED_USERNAME}:${SELECTED_USERNAME}" "/home/${SELECTED_USERNAME}/.config/systemd"

    # ── Enable hecate user services on first login ──
    mkdir -p "${user_home}/.config/zsh"
    cat > "${user_home}/.config/zsh/hecate-first-boot.zsh" <<'FIRSTBOOT'
# Auto-enable hecate services on first login, then self-delete
if [ ! -f ~/.hecate/.initialized ]; then
    echo "Initializing hecate services..."
    systemctl --user daemon-reload
    systemctl --user enable --now hecate-daemon.service 2>/dev/null || true
    systemctl --user enable --now ollama.service 2>/dev/null || true
    touch ~/.hecate/.initialized
    echo "Hecate stack initialized."
fi
FIRSTBOOT
    arch-chroot /mnt chown -R "${SELECTED_USERNAME}:${SELECTED_USERNAME}" "/home/${SELECTED_USERNAME}/.config/zsh"

    ok "Hecate stack configured"
}

# ── Enable services ─────────────────────────────────────────────────────────

enable_services() {
    section "Enabling Services"

    # System services
    arch-chroot /mnt systemctl enable NetworkManager
    arch-chroot /mnt systemctl enable sshd
    arch-chroot /mnt systemctl enable avahi-daemon
    arch-chroot /mnt systemctl enable bluetooth
    arch-chroot /mnt systemctl enable firewalld
    arch-chroot /mnt systemctl enable greetd
    arch-chroot /mnt systemctl enable fstrim.timer

    # Laptop services
    if [ "$DETECTED_IS_LAPTOP" = true ]; then
        arch-chroot /mnt systemctl enable auto-cpufreq
        arch-chroot /mnt systemctl enable thermald
    fi

    # ── Greetd config ──
    mkdir -p /mnt/etc/greetd
    cp "${SCRIPT_DIR}/configs/greetd.toml" /mnt/etc/greetd/config.toml

    # ── PAM for hyprlock ──
    cat > /mnt/etc/pam.d/hyprlock <<PAM
auth    include  system-auth
PAM

    ok "Services enabled"
}

# ── Finish ──────────────────────────────────────────────────────────────────

finish_install() {
    section "Installation Complete"

    echo -e "${GREEN}${BOLD}"
    echo "  hecatOS has been installed!"
    echo ""
    echo -e "${NC}${BOLD}  Summary:${NC}"
    echo -e "  ${BOLD}Hostname:${NC}  ${SELECTED_HOSTNAME}"
    echo -e "  ${BOLD}Role:${NC}      ${SELECTED_ROLE}"
    echo -e "  ${BOLD}User:${NC}      ${SELECTED_USERNAME}"
    echo -e "  ${BOLD}OS disk:${NC}   ${SELECTED_DISK} (${SELECTED_ROOT_FS})"
    [ -n "$SELECTED_HOME_DISK" ] && \
    echo -e "  ${BOLD}Home disk:${NC} ${SELECTED_HOME_DISK} (${SELECTED_HOME_FS})"
    [ "$DETECTED_GPU_TYPE" = "nvidia" ] && \
    echo -e "  ${BOLD}GPU:${NC}       NVIDIA (proprietary driver installed)"
    [ "$DETECTED_IS_LAPTOP" = true ] && \
    echo -e "  ${BOLD}Laptop:${NC}    Power management enabled"
    echo ""
    echo -e "  ${DIM}Reboot and remove the USB drive.${NC}"
    echo -e "  ${DIM}Login with: ${SELECTED_USERNAME}${NC}"
    echo ""

    echo -e "${CYAN}?${NC} Reboot now? [Y/n] "
    read -r reboot_choice
    if [[ ! "$reboot_choice" =~ ^[Nn] ]]; then
        umount -R /mnt 2>/dev/null || true
        reboot
    fi
}

# ── Argument Parsing ────────────────────────────────────────────────────────

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --interactive|-i) MODE="interactive"; shift ;;
            --config|-c)      CONFIG_FILE="$2"; shift 2 ;;
            --role)           SELECTED_ROLE="$2"; shift 2 ;;
            --disk)           SELECTED_DISK="$2"; shift 2 ;;
            --home-disk)      SELECTED_HOME_DISK="$2"; shift 2 ;;
            --root-fs)        SELECTED_ROOT_FS="$2"; shift 2 ;;
            --home-fs)        SELECTED_HOME_FS="$2"; shift 2 ;;
            --hostname)       SELECTED_HOSTNAME="$2"; shift 2 ;;
            --keyboard)       SELECTED_KEYBOARD="$2"; shift 2 ;;
            --timezone)       SELECTED_TIMEZONE="$2"; shift 2 ;;
            --locale)         SELECTED_LOCALE="$2"; shift 2 ;;
            --username)       SELECTED_USERNAME="$2"; shift 2 ;;
            --auto-disks)
                # Auto-select: smallest disk = OS, largest = /home
                local _candidates
                _candidates=$(list_candidate_disks)
                SELECTED_DISK=$(echo "$_candidates" | sort -t' ' -k2 -n | head -1 | awk '{print $1}')
                SELECTED_HOME_DISK=$(echo "$_candidates" | sort -t' ' -k2 -rn | head -1 | awk '{print $1}')
                [ "$SELECTED_DISK" = "$SELECTED_HOME_DISK" ] && SELECTED_HOME_DISK=""
                shift
                ;;
            --help|-h)
                echo "Usage: hecate-install [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --interactive, -i   Guided install (default)"
                echo "  --config, -c FILE   Load settings from JSON config file"
                echo "  --role ROLE         Pre-set role (desktop|workstation|standalone|cluster)"
                echo "  --disk DEVICE       Pre-set OS disk (e.g., /dev/sdb)"
                echo "  --home-disk DEVICE  Pre-set /home disk (e.g., /dev/sda)"
                echo "  --root-fs FS        Root filesystem: ext4, btrfs, xfs (default: ext4)"
                echo "  --home-fs FS        Home filesystem: ext4, btrfs, xfs (default: ext4)"
                echo "  --hostname NAME     Pre-set hostname"
                echo "  --keyboard LAYOUT   Pre-set keyboard layout"
                echo "  --timezone TZ       Pre-set timezone"
                echo "  --locale LOCALE     Pre-set locale"
                echo "  --username USER     Pre-set username"
                exit 0
                ;;
            *) fatal "Unknown argument: $1 (use --help)" ;;
        esac
    done
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    parse_args "$@"

    if [ "$(id -u)" -ne 0 ]; then
        fatal "hecate-install must be run as root (try: sudo hecate-install)"
    fi

    show_banner

    # ── Step 0: Network (must be online for pacstrap)
    ensure_network

    # ── Step 1: Keyboard
    select_keyboard

    # ── Step 2: Hardware detection
    detect_hardware

    # ── Step 3: Role
    select_role

    # ── Step 4: Target disk(s)
    if [ -z "$SELECTED_DISK" ]; then
        select_target_disk
    fi

    # ── Step 5: Filesystem
    select_filesystem

    # ── Step 6: Hostname
    select_hostname

    # ── Step 7: Timezone
    select_timezone

    # ── Step 8: Locale
    select_locale

    # ── Step 9: User account
    create_user

    # ── Confirm
    confirm_install

    # ── Install
    partition_disks
    install_base
    generate_fstab
    configure_system
    install_bootloader

    if [[ "$SELECTED_ROLE" =~ ^(desktop|workstation|llm-host)$ ]]; then
        install_desktop
        install_aur_packages
        deploy_dotfiles
    fi

    install_hecate_stack
    enable_services
    finish_install
}

main "$@"
