#!/usr/bin/env bash
#
# Build the hecatOS live ISO
#
# Prerequisites:
#   sudo pacman -S archiso
#
# Usage:
#   sudo ./build-iso.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="${SCRIPT_DIR}/archiso"
WORK_DIR="${SCRIPT_DIR}/build/work"
OUT_DIR="${SCRIPT_DIR}/build/out"

if [ "$(id -u)" -ne 0 ]; then
    echo "Must be run as root: sudo ./build-iso.sh"
    exit 1
fi

echo "━━━ Building hecatOS ISO ━━━"
echo ""

# ── Copy installer script into the ISO ──
echo "[INFO] Bundling installer and dotfiles..."
cp "${SCRIPT_DIR}/scripts/hecate-install-arch.sh" "${PROFILE_DIR}/airootfs/usr/local/bin/hecate-install"
chmod 755 "${PROFILE_DIR}/airootfs/usr/local/bin/hecate-install"

# Bundle the full project (packages, dotfiles, configs) into the ISO
# The installer references these via SCRIPT_DIR which we set to /usr/local/share/hecate-install
mkdir -p "${PROFILE_DIR}/airootfs/usr/local/share/hecate-install"
cp -r "${SCRIPT_DIR}/packages" "${PROFILE_DIR}/airootfs/usr/local/share/hecate-install/"
cp -r "${SCRIPT_DIR}/dotfiles" "${PROFILE_DIR}/airootfs/usr/local/share/hecate-install/"
cp -r "${SCRIPT_DIR}/configs"  "${PROFILE_DIR}/airootfs/usr/local/share/hecate-install/"
# Include the installer script in the bundle too (for SCRIPT_DIR detection)
mkdir -p "${PROFILE_DIR}/airootfs/usr/local/share/hecate-install/scripts"
cp "${SCRIPT_DIR}/scripts/hecate-install-arch.sh" "${PROFILE_DIR}/airootfs/usr/local/share/hecate-install/scripts/"

# Deploy FULL dotfiles to /etc/skel so the live user gets the complete desktop
echo "[INFO] Deploying dotfiles to /etc/skel..."
skel="${PROFILE_DIR}/airootfs/etc/skel"
rm -rf "${skel}"  # Clean stale copies from previous builds
skel_config="${skel}/.config"
mkdir -p "${skel_config}"

# All dotfile directories — copy CONTENTS, not the dir itself (avoid double nesting)
for dir in hypr kitty waybar rofi nvim fastfetch; do
    if [ -d "${SCRIPT_DIR}/dotfiles/${dir}" ]; then
        mkdir -p "${skel_config}/${dir}"
        cp -r "${SCRIPT_DIR}/dotfiles/${dir}/"* "${skel_config}/${dir}/" 2>/dev/null || true
        cp -r "${SCRIPT_DIR}/dotfiles/${dir}/".* "${skel_config}/${dir}/" 2>/dev/null || true
    fi
done
# Starship
[ -f "${SCRIPT_DIR}/dotfiles/starship.toml" ] && cp "${SCRIPT_DIR}/dotfiles/starship.toml" "${skel_config}/starship.toml"
# Wallpapers
if [ -d "${SCRIPT_DIR}/dotfiles/wallpapers" ]; then
    mkdir -p "${skel_config}/hypr/wallpapers"
    cp "${SCRIPT_DIR}/dotfiles/wallpapers/"* "${skel_config}/hypr/wallpapers/" 2>/dev/null || true
fi
# Set default wallpaper symlink (relative path so it works on the ISO)
default_wp=$(ls "${skel_config}/hypr/wallpapers/"*.{png,jpg} 2>/dev/null | head -1 || echo "")
if [ -n "$default_wp" ]; then
    default_wp_name=$(basename "$default_wp")
    ln -sf "wallpapers/${default_wp_name}" "${skel_config}/hypr/wallpaper.png"
fi
# Make hyprland scripts executable
chmod +x "${skel_config}/hypr/scripts/"*.sh 2>/dev/null || true

# Zshrc for live user
cat > "${skel}/.zshrc" <<'ZSHRC'
export ZSH="/usr/share/oh-my-zsh"
ZSH_THEME=""
plugins=(git sudo docker zsh-autosuggestions zsh-syntax-highlighting)
[ -f "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh
alias c=clear cat='bat --paging=never' ls='eza -a --icons=always' ll='eza -la --icons=always'
alias v=nvim vim=nvim lg=lazygit lzd=lazydocker fm=yazi du=dust df=duf j=just
[[ $- == *i* ]] && [ -z "$TMUX" ] && [ -z "$ZELLIJ" ] && fastfetch
ZSHRC

# GTK theming for live user
mkdir -p "${skel_config}/gtk-3.0" "${skel_config}/gtk-4.0"
cat > "${skel_config}/gtk-3.0/settings.ini" <<GTK
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Cantarell 11
gtk-application-prefer-dark-theme=1
GTK
cp "${skel_config}/gtk-3.0/settings.ini" "${skel_config}/gtk-4.0/settings.ini"

# hecate user is created at boot by hecatos-live-setup service
# which uses useradd -m, copying /etc/skel to /home/hecate automatically

# ── Build ──
echo "[INFO] Running mkarchiso..."
echo ""

mkdir -p "${WORK_DIR}" "${OUT_DIR}"
mkarchiso -v -w "${WORK_DIR}" -o "${OUT_DIR}" "${PROFILE_DIR}"

echo ""
echo "━━━ hecatOS ISO built successfully ━━━"
echo ""
ls -lh "${OUT_DIR}/"*.iso
echo ""
echo "Write to USB: sudo dd bs=4M if=${OUT_DIR}/hecatos-*.iso of=/dev/sdX status=progress oflag=sync"
