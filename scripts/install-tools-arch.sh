#!/usr/bin/env bash
#
# install-tools-arch.sh — Install hecatOS tool stack on Arch Linux
#
# Installs all tools from the hecatOS desktop that are missing on this machine.
# Skips tools already installed. Uses pacman first, yay for AUR.
#
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
skip()  { echo -e "${DIM}[SKIP]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

has() { command -v "$1" &>/dev/null; }

# ── Pacman packages ─────────────────────────────────────────────────────
# Format: "pacman-package:binary-name"
PACMAN_TOOLS=(
    # File & directory
    "dust:dust"
    "duf:duf"
    "ouch:ouch"

    # System monitoring
    "procs:procs"
    "bandwhich:bandwhich"

    # Network
    "xh:xh"
    "mtr:mtr"
    "iperf3:iperf3"
    "doggo:doggo"

    # Data processing
    "sd:sd"
    "choose:choose"
    "yq:yq"

    # Development
    "direnv:direnv"
    "watchexec:watchexec"
    "hyperfine:hyperfine"
    "tokei:tokei"
    "hexyl:hexyl"

    # Multiplexer
    "tmux:tmux"
    "zellij:zellij"

    # Docs
    "tealdeer:tldr"

    # Media & desktop
    "imv:imv"
    "cava:cava"
    "zathura:zathura"
    "zathura-pdf-mupdf:zathura"
    "qalculate-gtk:qalculate-gtk"
    "file-roller:file-roller"
    "satty:satty"
)

# ── AUR packages ────────────────────────────────────────────────────────
AUR_TOOLS=(
    "viddy-bin:viddy"
)

# ── Install ─────────────────────────────────────────────────────────────

install_pacman=()
install_aur=()

echo ""
info "Checking which tools need installing..."
echo ""

for entry in "${PACMAN_TOOLS[@]}"; do
    IFS=':' read -r pkg bin <<< "$entry"
    if has "$bin"; then
        skip "$pkg (already installed)"
    else
        install_pacman+=("$pkg")
        echo -e "  ${GREEN}+${NC} $pkg"
    fi
done

for entry in "${AUR_TOOLS[@]}"; do
    IFS=':' read -r pkg bin <<< "$entry"
    if has "$bin"; then
        skip "$pkg (already installed)"
    else
        install_aur+=("$pkg")
        echo -e "  ${GREEN}+${NC} $pkg ${DIM}(AUR)${NC}"
    fi
done

echo ""

if [ ${#install_pacman[@]} -eq 0 ] && [ ${#install_aur[@]} -eq 0 ]; then
    ok "All tools already installed!"
    exit 0
fi

info "Installing ${#install_pacman[@]} pacman + ${#install_aur[@]} AUR packages"
echo ""

if [ ${#install_pacman[@]} -gt 0 ]; then
    sudo pacman -S --needed --noconfirm "${install_pacman[@]}"
    ok "Pacman packages installed"
fi

if [ ${#install_aur[@]} -gt 0 ]; then
    if has yay; then
        yay -S --needed --noconfirm "${install_aur[@]}"
        ok "AUR packages installed"
    elif has paru; then
        paru -S --needed --noconfirm "${install_aur[@]}"
        ok "AUR packages installed"
    else
        warn "No AUR helper found (yay/paru). Install manually:"
        for pkg in "${install_aur[@]}"; do
            echo "  yay -S $pkg"
        done
    fi
fi

echo ""
ok "Done! Restart your shell or run: source ~/.zshrc"
echo ""
