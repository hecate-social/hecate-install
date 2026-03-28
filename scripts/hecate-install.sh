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
RECORD=false
RECORD_PID=""
RECORD_FILE=""

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

# OOBE values
SELECTED_KEYBOARD="us"
SELECTED_TIMEZONE="UTC"
SELECTED_LOCALE="en_US.UTF-8"
SELECTED_USERNAME="hecate"
SELECTED_FULLNAME=""
SELECTED_PASSWORD=""

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

# ── Screen Recording ────────────────────────────────────────────────────────

start_recording() {
    [ "$RECORD" = false ] && return

    RECORD_FILE="/tmp/hecatos-install-$(date +%Y%m%d-%H%M%S).mp4"

    if [ -n "$WAYLAND_DISPLAY" ] && command -v wf-recorder &>/dev/null; then
        # Wayland (live desktop) — record full screen
        info "Recording installation to ${RECORD_FILE}"
        wf-recorder -f "$RECORD_FILE" -c h264_vaapi 2>/dev/null &
        RECORD_PID=$!
        # Fallback to software encoding if VA-API fails
        if ! kill -0 "$RECORD_PID" 2>/dev/null; then
            wf-recorder -f "$RECORD_FILE" 2>/dev/null &
            RECORD_PID=$!
        fi
        ok "Recording started (wf-recorder, PID ${RECORD_PID})"
    elif command -v ffmpeg &>/dev/null && [ -c /dev/fb0 ]; then
        # TTY with framebuffer — record via ffmpeg
        local res
        res=$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null | tr ',' 'x' || echo "1920x1080")
        info "Recording installation to ${RECORD_FILE} (framebuffer ${res})"
        ffmpeg -y -f fbdev -framerate 10 -i /dev/fb0 \
            -vf "format=yuv420p" -c:v libx264 -preset ultrafast \
            "$RECORD_FILE" </dev/null &>/dev/null &
        RECORD_PID=$!
        ok "Recording started (ffmpeg fbdev, PID ${RECORD_PID})"
    else
        warn "No recording method available (need wf-recorder on Wayland or ffmpeg + /dev/fb0 on TTY)"
        RECORD=false
    fi
}

stop_recording() {
    [ "$RECORD" = false ] && return
    [ -z "$RECORD_PID" ] && return

    info "Stopping recording..."

    # wf-recorder and ffmpeg both stop cleanly on SIGINT
    kill -INT "$RECORD_PID" 2>/dev/null || true
    wait "$RECORD_PID" 2>/dev/null || true
    RECORD_PID=""

    if [ -f "$RECORD_FILE" ]; then
        local size
        size=$(du -h "$RECORD_FILE" | cut -f1)
        ok "Recording saved: ${RECORD_FILE} (${size})"

        # Copy to the installed system if available
        if [ -d /mnt/home ]; then
            local dest="/mnt/home/${SELECTED_USERNAME}/Videos"
            mkdir -p "$dest"
            cp "$RECORD_FILE" "$dest/"
            ok "Recording copied to installed system: ~/Videos/$(basename "$RECORD_FILE")"
        fi
    else
        warn "Recording file not found"
    fi
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

# ── Keyboard Layout ─────────────────────────────────────────────────────────

select_keyboard() {
    section "Keyboard Layout"

    local layouts=(
        "us:US English"
        "gb:UK English"
        "de:German"
        "fr:French"
        "es:Spanish"
        "it:Italian"
        "pt:Portuguese"
        "nl:Dutch"
        "be:Belgian"
        "ch:Swiss (German)"
        "se:Swedish"
        "no:Norwegian"
        "dk:Danish"
        "fi:Finnish"
        "pl:Polish"
        "cz:Czech"
        "hu:Hungarian"
        "ru:Russian"
        "jp:Japanese"
        "kr:Korean"
        "br:Brazilian Portuguese"
        "latam:Latin American Spanish"
    )

    if [ "$MODE" = "unattended" ]; then
        info "Keyboard: ${SELECTED_KEYBOARD}"
        return
    fi

    echo "Select your keyboard layout:"
    echo ""

    local i=1
    for entry in "${layouts[@]}"; do
        IFS=':' read -r code name <<< "$entry"
        local marker="  "
        [ "$code" = "us" ] && marker="${GREEN}▸ ${NC}"
        printf "  ${marker}${BOLD}%2d)${NC} %-6s ${DIM}%s${NC}\n" "$i" "$code" "$name"
        i=$((i + 1))
    done
    echo ""
    echo -e "  ${BOLD} 0)${NC} Other  ${DIM}(type layout code manually)${NC}"
    echo ""
    echo -en "  ${CYAN}?${NC} Choose [1]: "
    read -r choice
    choice="${choice:-1}"

    if [ "$choice" = "0" ]; then
        echo -en "  ${CYAN}?${NC} Layout code (e.g. dvorak, colemak): "
        read -r SELECTED_KEYBOARD
    elif [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le "${#layouts[@]}" ]; then
        local idx=$((choice - 1))
        IFS=':' read -r SELECTED_KEYBOARD _ <<< "${layouts[$idx]}"
    else
        SELECTED_KEYBOARD="us"
    fi

    # Apply immediately so the user can type correctly for the rest of the install
    loadkeys "$SELECTED_KEYBOARD" 2>/dev/null || true

    ok "Keyboard: ${SELECTED_KEYBOARD}"
}

# ── Wi-Fi Connection ───────────────────────────────────────────────────────

connect_wifi() {
    # Skip if wired connection is up
    if ip route get 1.1.1.1 &>/dev/null; then
        return
    fi

    # Skip if no wireless interface
    if ! ls /sys/class/net/wl* &>/dev/null; then
        return
    fi

    if [ "$MODE" = "unattended" ]; then
        warn "No network. Unattended mode cannot configure Wi-Fi."
        return
    fi

    section "Wi-Fi Connection"

    echo -e "  ${YELLOW}No wired connection detected.${NC}"
    echo -e "  ${DIM}Internet is required to download NixOS packages.${NC}"
    echo ""

    if ! command -v nmcli &>/dev/null; then
        warn "nmcli not available. Connect Wi-Fi manually or plug in Ethernet."
        echo ""
        echo -en "  ${CYAN}?${NC} Press Enter to continue once connected... "
        read -r _
        return
    fi

    # Scan for networks
    info "Scanning for Wi-Fi networks..."
    nmcli device wifi rescan 2>/dev/null || true
    sleep 2

    local networks
    networks=$(nmcli -t -f SSID,SIGNAL,SECURITY device wifi list 2>/dev/null | grep -v '^$' | sort -t: -k2 -rn | head -15)

    if [ -z "$networks" ]; then
        warn "No Wi-Fi networks found."
        echo -en "  ${CYAN}?${NC} Press Enter to continue... "
        read -r _
        return
    fi

    echo ""
    echo "  Available networks:"
    echo ""
    local i=1
    while IFS=: read -r ssid signal security; do
        local lock=" "
        [ -n "$security" ] && [ "$security" != "--" ] && lock="🔒"
        printf "  ${BOLD}%2d)${NC} %-30s %s%% %s\n" "$i" "$ssid" "$signal" "$lock"
        i=$((i + 1))
    done <<< "$networks"

    echo ""
    echo -e "  ${BOLD} 0)${NC} Skip ${DIM}(continue without Wi-Fi)${NC}"
    echo ""
    echo -en "  ${CYAN}?${NC} Connect to [0]: "
    read -r choice
    choice="${choice:-0}"

    if [ "$choice" = "0" ]; then
        return
    fi

    local selected_ssid
    selected_ssid=$(echo "$networks" | sed -n "${choice}p" | cut -d: -f1)

    if [ -z "$selected_ssid" ]; then
        warn "Invalid selection."
        return
    fi

    echo -en "  ${CYAN}?${NC} Password for '${selected_ssid}': "
    read -rs wifi_pass
    echo ""

    info "Connecting to ${selected_ssid}..."
    if nmcli device wifi connect "$selected_ssid" password "$wifi_pass" 2>/dev/null; then
        ok "Connected to ${selected_ssid}"
    else
        warn "Connection failed. You may need to connect manually."
        echo -en "  ${CYAN}?${NC} Press Enter to continue... "
        read -r _
    fi
}

# ── Timezone Selection ─────────────────────────────────────────────────────

select_timezone() {
    section "Timezone"

    if [ "$MODE" = "unattended" ]; then
        info "Timezone: ${SELECTED_TIMEZONE}"
        return
    fi

    # Common timezones grouped by region
    local regions=(
        "Americas"
        "Europe"
        "Asia"
        "Africa"
        "Oceania"
        "Other"
    )

    local tz_americas=(
        "America/New_York:Eastern (New York)"
        "America/Chicago:Central (Chicago)"
        "America/Denver:Mountain (Denver)"
        "America/Los_Angeles:Pacific (Los Angeles)"
        "America/Anchorage:Alaska"
        "Pacific/Honolulu:Hawaii"
        "America/Toronto:Toronto"
        "America/Vancouver:Vancouver"
        "America/Mexico_City:Mexico City"
        "America/Sao_Paulo:São Paulo"
        "America/Argentina/Buenos_Aires:Buenos Aires"
        "America/Bogota:Bogotá"
        "America/Lima:Lima"
        "America/Santiago:Santiago"
    )

    local tz_europe=(
        "Europe/London:London (GMT/BST)"
        "Europe/Brussels:Brussels (CET)"
        "Europe/Amsterdam:Amsterdam (CET)"
        "Europe/Berlin:Berlin (CET)"
        "Europe/Paris:Paris (CET)"
        "Europe/Madrid:Madrid (CET)"
        "Europe/Rome:Rome (CET)"
        "Europe/Zurich:Zurich (CET)"
        "Europe/Vienna:Vienna (CET)"
        "Europe/Stockholm:Stockholm (CET)"
        "Europe/Oslo:Oslo (CET)"
        "Europe/Copenhagen:Copenhagen (CET)"
        "Europe/Helsinki:Helsinki (EET)"
        "Europe/Warsaw:Warsaw (CET)"
        "Europe/Prague:Prague (CET)"
        "Europe/Budapest:Budapest (CET)"
        "Europe/Bucharest:Bucharest (EET)"
        "Europe/Athens:Athens (EET)"
        "Europe/Moscow:Moscow (MSK)"
        "Europe/Istanbul:Istanbul (TRT)"
        "Europe/Lisbon:Lisbon (WET)"
        "Europe/Dublin:Dublin (GMT/IST)"
    )

    local tz_asia=(
        "Asia/Tokyo:Tokyo (JST)"
        "Asia/Shanghai:Shanghai (CST)"
        "Asia/Hong_Kong:Hong Kong (HKT)"
        "Asia/Seoul:Seoul (KST)"
        "Asia/Taipei:Taipei (CST)"
        "Asia/Singapore:Singapore (SGT)"
        "Asia/Kolkata:India (IST)"
        "Asia/Dubai:Dubai (GST)"
        "Asia/Bangkok:Bangkok (ICT)"
        "Asia/Jakarta:Jakarta (WIB)"
        "Asia/Ho_Chi_Minh:Ho Chi Minh (ICT)"
        "Asia/Karachi:Karachi (PKT)"
        "Asia/Tehran:Tehran (IRST)"
        "Asia/Riyadh:Riyadh (AST)"
        "Asia/Jerusalem:Jerusalem (IST)"
    )

    local tz_africa=(
        "Africa/Cairo:Cairo (EET)"
        "Africa/Lagos:Lagos (WAT)"
        "Africa/Nairobi:Nairobi (EAT)"
        "Africa/Johannesburg:Johannesburg (SAST)"
        "Africa/Casablanca:Casablanca (WET)"
        "Africa/Accra:Accra (GMT)"
    )

    local tz_oceania=(
        "Australia/Sydney:Sydney (AEST)"
        "Australia/Melbourne:Melbourne (AEST)"
        "Australia/Perth:Perth (AWST)"
        "Australia/Brisbane:Brisbane (AEST)"
        "Pacific/Auckland:Auckland (NZST)"
        "Pacific/Fiji:Fiji (FJT)"
    )

    echo "Select your region:"
    echo ""
    local i=1
    for region in "${regions[@]}"; do
        echo -e "  ${BOLD}${i})${NC} ${region}"
        i=$((i + 1))
    done
    echo ""
    echo -en "  ${CYAN}?${NC} Region [2]: "
    read -r region_choice
    region_choice="${region_choice:-2}"

    local -n tz_list
    case "$region_choice" in
        1) tz_list=tz_americas ;;
        2) tz_list=tz_europe ;;
        3) tz_list=tz_asia ;;
        4) tz_list=tz_africa ;;
        5) tz_list=tz_oceania ;;
        6)
            echo -en "  ${CYAN}?${NC} Timezone (e.g. UTC, Etc/GMT+5): "
            read -r SELECTED_TIMEZONE
            SELECTED_TIMEZONE="${SELECTED_TIMEZONE:-UTC}"
            ok "Timezone: ${SELECTED_TIMEZONE}"
            return
            ;;
        *) tz_list=tz_europe ;;
    esac

    echo ""
    i=1
    for entry in "${tz_list[@]}"; do
        IFS=':' read -r tz_code tz_name <<< "$entry"
        printf "  ${BOLD}%2d)${NC} %-35s ${DIM}%s${NC}\n" "$i" "$tz_name" "$tz_code"
        i=$((i + 1))
    done
    echo ""
    echo -en "  ${CYAN}?${NC} Choose [1]: "
    read -r tz_choice
    tz_choice="${tz_choice:-1}"

    if [ "$tz_choice" -ge 1 ] 2>/dev/null && [ "$tz_choice" -le "${#tz_list[@]}" ]; then
        local idx=$((tz_choice - 1))
        IFS=':' read -r SELECTED_TIMEZONE _ <<< "${tz_list[$idx]}"
    else
        SELECTED_TIMEZONE="UTC"
    fi

    ok "Timezone: ${SELECTED_TIMEZONE}"
}

# ── Locale Selection ───────────────────────────────────────────────────────

select_locale() {
    section "Language & Locale"

    if [ "$MODE" = "unattended" ]; then
        info "Locale: ${SELECTED_LOCALE}"
        return
    fi

    local locales=(
        "en_US.UTF-8:English (US)"
        "en_GB.UTF-8:English (UK)"
        "de_DE.UTF-8:Deutsch (German)"
        "fr_FR.UTF-8:Français (French)"
        "es_ES.UTF-8:Español (Spanish)"
        "it_IT.UTF-8:Italiano (Italian)"
        "pt_PT.UTF-8:Português (Portuguese)"
        "pt_BR.UTF-8:Português (Brazilian)"
        "nl_NL.UTF-8:Nederlands (Dutch)"
        "sv_SE.UTF-8:Svenska (Swedish)"
        "nb_NO.UTF-8:Norsk (Norwegian)"
        "da_DK.UTF-8:Dansk (Danish)"
        "fi_FI.UTF-8:Suomi (Finnish)"
        "pl_PL.UTF-8:Polski (Polish)"
        "cs_CZ.UTF-8:Čeština (Czech)"
        "hu_HU.UTF-8:Magyar (Hungarian)"
        "ru_RU.UTF-8:Русский (Russian)"
        "ja_JP.UTF-8:日本語 (Japanese)"
        "ko_KR.UTF-8:한국어 (Korean)"
        "zh_CN.UTF-8:中文 (Chinese Simplified)"
    )

    echo "Select your language:"
    echo ""
    local i=1
    for entry in "${locales[@]}"; do
        IFS=':' read -r code name <<< "$entry"
        local marker="  "
        [ "$code" = "en_US.UTF-8" ] && marker="${GREEN}▸ ${NC}"
        printf "  ${marker}${BOLD}%2d)${NC} %s\n" "$i" "$name"
        i=$((i + 1))
    done
    echo ""
    echo -en "  ${CYAN}?${NC} Choose [1]: "
    read -r loc_choice
    loc_choice="${loc_choice:-1}"

    if [ "$loc_choice" -ge 1 ] 2>/dev/null && [ "$loc_choice" -le "${#locales[@]}" ]; then
        local idx=$((loc_choice - 1))
        IFS=':' read -r SELECTED_LOCALE _ <<< "${locales[$idx]}"
    else
        SELECTED_LOCALE="en_US.UTF-8"
    fi

    ok "Locale: ${SELECTED_LOCALE}"
}

# ── User Account ───────────────────────────────────────────────────────────

create_user() {
    section "User Account"

    if [ "$MODE" = "unattended" ]; then
        info "User: ${SELECTED_USERNAME}"
        return
    fi

    echo -e "  ${DIM}Create your user account for this machine.${NC}"
    echo ""

    # Username
    echo -en "  ${CYAN}?${NC} Username [hecate]: "
    read -r input_user
    SELECTED_USERNAME="${input_user:-hecate}"

    # Validate username
    if ! [[ "$SELECTED_USERNAME" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
        warn "Invalid username. Using 'hecate'."
        SELECTED_USERNAME="hecate"
    fi

    # Full name (optional)
    echo -en "  ${CYAN}?${NC} Full name (optional): "
    read -r SELECTED_FULLNAME

    # Password
    local password_ok=false
    while [ "$password_ok" = false ]; do
        echo -en "  ${CYAN}?${NC} Password: "
        read -rs pass1
        echo ""

        if [ -z "$pass1" ]; then
            warn "Password cannot be empty."
            continue
        fi

        if [ "${#pass1}" -lt 4 ]; then
            warn "Password must be at least 4 characters."
            continue
        fi

        echo -en "  ${CYAN}?${NC} Confirm password: "
        read -rs pass2
        echo ""

        if [ "$pass1" != "$pass2" ]; then
            warn "Passwords do not match. Try again."
        else
            SELECTED_PASSWORD="$pass1"
            password_ok=true
        fi
    done

    echo ""
    ok "User: ${SELECTED_USERNAME}"
}

# ── Confirmation ───────────────────────────────────────────────────────────

confirm_install() {
    echo ""
    echo -e "${BOLD}${RED}WARNING: This will ERASE ALL DATA on the following disk(s):${NC}"
    echo ""
    echo -e "  ${BOLD}Target:${NC}    ${SELECTED_DISK}"
    echo -e "  ${BOLD}Role:${NC}      ${SELECTED_ROLE}"
    echo -e "  ${BOLD}Hostname:${NC}  ${SELECTED_HOSTNAME}"
    echo -e "  ${BOLD}Layout:${NC}    ${SELECTED_DISKO_LAYOUT}"
    echo -e "  ${BOLD}Keyboard:${NC}  ${SELECTED_KEYBOARD}"
    echo -e "  ${BOLD}Timezone:${NC}  ${SELECTED_TIMEZONE}"
    echo -e "  ${BOLD}Locale:${NC}    ${SELECTED_LOCALE}"
    echo -e "  ${BOLD}User:${NC}      ${SELECTED_USERNAME}"
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

    # Build extra config module with all user selections
    local extra_config="/tmp/hecate-extra-config.nix"

    # Hash password for NixOS user config
    local hashed_password=""
    if [ -n "$SELECTED_PASSWORD" ]; then
        hashed_password=$(echo "$SELECTED_PASSWORD" | mkpasswd -m sha-512 -s 2>/dev/null || \
                          openssl passwd -6 -stdin <<< "$SELECTED_PASSWORD" 2>/dev/null || \
                          echo "")
    fi

    # Build the nix config as a string, then write all at once
    local nix_body=""

    # Identity
    nix_body+="  networking.hostName = \"${SELECTED_HOSTNAME}\";"$'\n'

    # Locale & Time
    nix_body+="  time.timeZone = lib.mkForce \"${SELECTED_TIMEZONE}\";"$'\n'
    nix_body+="  i18n.defaultLocale = lib.mkForce \"${SELECTED_LOCALE}\";"$'\n'

    # Keyboard
    nix_body+="  console.keyMap = lib.mkForce \"${SELECTED_KEYBOARD}\";"$'\n'
    nix_body+="  services.xserver.xkb.layout = lib.mkDefault \"${SELECTED_KEYBOARD}\";"$'\n'

    # User account
    nix_body+="  services.hecate.user = lib.mkForce \"${SELECTED_USERNAME}\";"$'\n'
    nix_body+="  users.users.\"${SELECTED_USERNAME}\" = {"$'\n'
    nix_body+="    isNormalUser = true;"$'\n'
    nix_body+="    extraGroups = [ \"wheel\" \"podman\" \"networkmanager\" ];"$'\n'
    nix_body+="    shell = pkgs.zsh;"$'\n'
    [ -n "$SELECTED_FULLNAME" ] && \
    nix_body+="    description = \"${SELECTED_FULLNAME}\";"$'\n'
    [ -n "$hashed_password" ] && \
    nix_body+="    hashedPassword = \"${hashed_password}\";"$'\n'
    nix_body+="  };"$'\n'

    # Cluster config
    if [ "$SELECTED_ROLE" = "cluster" ] && [ -n "$CLUSTER_COOKIE" ]; then
        nix_body+="  services.hecate.cluster = {"$'\n'
        nix_body+="    cookie = \"${CLUSTER_COOKIE}\";"$'\n'
        [ -n "$CLUSTER_PEERS" ] && \
        nix_body+="    peers = [ ${CLUSTER_PEERS} ];"$'\n'
        nix_body+="  };"$'\n'
    fi

    # Laptop
    if [ -d /sys/class/power_supply ] && ls /sys/class/power_supply/BAT* &>/dev/null; then
        info "Battery detected — enabling laptop power management"
        nix_body+="  services.hecate.desktop.laptop.enable = true;"$'\n'
    fi

    # NVIDIA GPU
    if lspci 2>/dev/null | grep -qi 'nvidia.*vga\|vga.*nvidia'; then
        info "NVIDIA GPU detected — enabling proprietary driver"
        nix_body+="  services.hecate.desktop.nvidia.enable = true;"$'\n'
    fi

    cat > "$extra_config" <<NIX
{ lib, pkgs, ... }:

{
${nix_body}}
NIX

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
    echo -e "  ${BOLD}User:${NC}      ${SELECTED_USERNAME}"
    echo -e "  ${BOLD}Keyboard:${NC}  ${SELECTED_KEYBOARD}"
    echo -e "  ${BOLD}Timezone:${NC}  ${SELECTED_TIMEZONE}"
    echo -e "  ${BOLD}Locale:${NC}    ${SELECTED_LOCALE}"
    echo -e "  ${BOLD}Disk:${NC}      ${SELECTED_DISK}"
    echo ""
    # Stop recording and copy to installed system
    stop_recording

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

    # OOBE fields
    local kb; kb=$(jq -r '.keyboard // empty' "$file" 2>/dev/null || echo "")
    [ -n "$kb" ] && SELECTED_KEYBOARD="$kb"
    local tz; tz=$(jq -r '.timezone // empty' "$file" 2>/dev/null || echo "")
    [ -n "$tz" ] && SELECTED_TIMEZONE="$tz"
    local loc; loc=$(jq -r '.locale // empty' "$file" 2>/dev/null || echo "")
    [ -n "$loc" ] && SELECTED_LOCALE="$loc"
    local usr; usr=$(jq -r '.username // empty' "$file" 2>/dev/null || echo "")
    [ -n "$usr" ] && SELECTED_USERNAME="$usr"

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
            --record|-r)
                RECORD=true
                shift
                ;;
            --keyboard)
                SELECTED_KEYBOARD="$2"
                shift 2
                ;;
            --timezone)
                SELECTED_TIMEZONE="$2"
                shift 2
                ;;
            --locale)
                SELECTED_LOCALE="$2"
                shift 2
                ;;
            --username)
                SELECTED_USERNAME="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: hecate-install [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --unattended, -u    No prompts, auto-detect everything (10s countdown)"
                echo "  --interactive, -i   Confirm role/disk/hostname before wipe (default)"
                echo "  --config, -c FILE   Load settings from JSON config file"
                echo "  --record, -r        Record the installation to MP4"
                echo "  --role ROLE         Pre-set role (standalone|cluster|inference|workstation|desktop)"
                echo "  --disk DEVICE       Pre-set target disk (e.g., /dev/sda)"
                echo "  --hostname NAME     Pre-set hostname"
                echo "  --keyboard LAYOUT   Pre-set keyboard (us, de, fr, etc.)"
                echo "  --timezone TZ       Pre-set timezone (e.g., Europe/Brussels)"
                echo "  --locale LOCALE     Pre-set locale (e.g., en_US.UTF-8)"
                echo "  --username USER     Pre-set username"
                echo "  --help, -h          Show this help"
                echo ""
                echo "Config file format (JSON):"
                echo '  { "role": "desktop", "disk": "/dev/sda", "hostname": "my-node",'
                echo '    "keyboard": "us", "timezone": "America/New_York",'
                echo '    "locale": "en_US.UTF-8", "username": "alice" }'
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

    # ── Recording (if --record flag set)
    start_recording

    # ── Step 1: Keyboard (so user can type correctly for remaining steps)
    select_keyboard

    # ── Step 2: Hardware detection
    detect_hardware

    # ── Step 3: Network (Wi-Fi if needed — must be online for install)
    connect_wifi

    # ── Step 4: Role selection (auto or interactive)
    detect_role

    # ── Step 5: Target disk
    if [ -z "$SELECTED_DISK" ]; then
        select_target_disk
    else
        ok "Disk pre-set: ${SELECTED_DISK}"
    fi

    # ── Step 6: Hostname
    select_hostname

    # ── Step 7: Timezone
    select_timezone

    # ── Step 8: Language
    select_locale

    # ── Step 9: User account
    create_user

    # ── Generate disk layout
    generate_disko_config

    # ── Confirm before destructive operations
    confirm_install

    # Partition and format
    run_disko

    # Install NixOS
    run_nixos_install

    # Done — reboot
    finish_install
}

main "$@"
