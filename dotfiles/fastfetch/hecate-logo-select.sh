#!/usr/bin/env bash
#
# hecate-logo-select — Pick your hecatOS terminal logo
#
# Usage: hecate-logo-select [logo-name]
#   Without arguments: interactive selector with previews
#   With argument: set directly (e.g., hecate-logo-select flame-crown)
#
set -euo pipefail

LOGO_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/logos"
ACTIVE_LOGO="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/logo.txt"

# Colors
O='\033[38;2;249;115;22m'   # orange
A='\033[38;2;251;191;36m'   # amber
G='\033[38;2;107;114;128m'  # gray
D='\033[38;2;60;60;80m'     # dim
W='\033[38;2;224;224;232m'  # white
R='\033[0m'                 # reset

LOGOS=(
    "flame-crown:Flame Crown:Regal three-pronged fire crown (default)"
    "flowing-flame:Flowing Flame:Organic single torch shape"
    "geometric-h:Geometric H:Clean modernist letter mark"
    "twin-torches:Twin Torches:Two torches — matches the SVG logo"
    "minimal-sigil:Minimal Sigil:Abstract triangle with key insert"
    "neon-wordmark:Neon Wordmark:Big bold HECAT block letters"
    "torch-minimal:Torch Minimal:Realistic torch with cup and handle"
    "fire-diamond:Fire Diamond:Geometric diamond with fire core"
)

current_logo() {
    if [ -L "$ACTIVE_LOGO" ]; then
        basename "$(readlink -f "$ACTIVE_LOGO")" .txt
    elif [ -f "$ACTIVE_LOGO" ]; then
        echo "(custom)"
    else
        echo "(none)"
    fi
}

set_logo() {
    local name="$1"
    local source="${LOGO_DIR}/${name}.txt"

    if [ ! -f "$source" ]; then
        echo -e "${O}Error:${R} Logo '${name}' not found in ${LOGO_DIR}/"
        echo "Available: $(ls "$LOGO_DIR"/*.txt 2>/dev/null | xargs -I{} basename {} .txt | tr '\n' ' ')"
        exit 1
    fi

    ln -sf "$source" "$ACTIVE_LOGO"
    echo -e "${A}Logo set to:${R} ${name}"
    echo ""
    fastfetch 2>/dev/null || true
}

preview_logo() {
    local name="$1"
    local source="${LOGO_DIR}/${name}.txt"

    if [ ! -f "$source" ]; then
        return
    fi

    # Render the logo with colors (translate $N codes to ANSI)
    sed \
        -e "s/\\\$1/${O}/g" \
        -e "s/\\\$2/${A}/g" \
        -e "s/\\\$3/${G}/g" \
        -e "s/\\\$4/${D}/g" \
        "$source"
    echo -e "${R}"
}

show_selector() {
    local current
    current=$(current_logo)

    echo ""
    echo -e "${W}  hecatOS Logo Selector${R}"
    echo -e "${G}  Current: ${A}${current}${R}"
    echo ""

    local i=1
    for entry in "${LOGOS[@]}"; do
        IFS=':' read -r slug title desc <<< "$entry"
        local marker="  "
        [ "$slug" = "$current" ] && marker="${A}▸ ${R}"
        echo -e "  ${marker}${W}${i})${R} ${A}${title}${R}  ${G}— ${desc}${R}"
        i=$((i + 1))
    done

    echo ""
    echo -e "  ${W}p)${R} Preview a logo before choosing"
    echo -e "  ${W}q)${R} Quit"
    echo ""
    echo -en "  ${W}Choose [1-8/p/q]:${R} "
    read -r choice

    case "$choice" in
        [1-8])
            local idx=$((choice - 1))
            IFS=':' read -r slug _ _ <<< "${LOGOS[$idx]}"
            set_logo "$slug"
            ;;
        p|P)
            echo ""
            echo -en "  ${W}Preview which? [1-8]:${R} "
            read -r pchoice
            if [[ "$pchoice" =~ ^[1-8]$ ]]; then
                local pidx=$((pchoice - 1))
                IFS=':' read -r pslug ptitle _ <<< "${LOGOS[$pidx]}"
                echo ""
                echo -e "  ${W}── ${ptitle} ──${R}"
                echo ""
                preview_logo "$pslug"
                echo ""
                echo -en "  ${W}Use this logo? [y/N]:${R} "
                read -r confirm
                if [[ "$confirm" =~ ^[Yy] ]]; then
                    set_logo "$pslug"
                else
                    show_selector
                fi
            fi
            ;;
        q|Q)
            echo -e "  ${G}No changes.${R}"
            ;;
        *)
            echo -e "  ${O}Invalid choice.${R}"
            show_selector
            ;;
    esac
}

# ── Main ────────────────────────────────────────────────────────────────────

if [ ! -d "$LOGO_DIR" ]; then
    echo -e "${O}Error:${R} Logo directory not found: ${LOGO_DIR}"
    echo "Are you running hecatOS with the desktop configuration?"
    exit 1
fi

if [ $# -ge 1 ]; then
    set_logo "$1"
else
    show_selector
fi
