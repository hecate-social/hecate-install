#!/usr/bin/env bash
#
# Hecate Node Installer
# Usage: curl -fsSL https://hecate.social/install.sh | bash
#
set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

HECATE_VERSION="${HECATE_VERSION:-latest}"
INSTALL_DIR="${HECATE_INSTALL_DIR:-$HOME/.hecate}"
BIN_DIR="${HECATE_BIN_DIR:-$HOME/.local/bin}"
REPO_BASE="https://github.com/hecate-social"
RAW_BASE="https://raw.githubusercontent.com/hecate-social/hecate-node/main"

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' NC=''
fi

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
fatal() { error "$@"; exit 1; }

command_exists() { command -v "$1" &>/dev/null; }

detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "darwin" ;;
        *)       fatal "Unsupported OS: $(uname -s)" ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *)             fatal "Unsupported architecture: $(uname -m)" ;;
    esac
}

get_latest_release() {
    local repo="$1"
    curl -fsSL "https://api.github.com/repos/hecate-social/${repo}/releases/latest" \
        | grep '"tag_name"' \
        | sed -E 's/.*"([^"]+)".*/\1/'
}

download_file() {
    local url="$1"
    local dest="$2"
    info "Downloading: $url"
    curl -fsSL "$url" -o "$dest"
}

# -----------------------------------------------------------------------------
# Banner
# -----------------------------------------------------------------------------

show_banner() {
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
    __  __              __
   / / / /__  _______ _/ /____
  / /_/ / _ \/ __/ _ `/ __/ -_)
 /_//_/\___/\__/\_,_/\__/\__/

EOF
    echo -e "${NC}"
    echo -e "${BOLD}Hecate Node Installer${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# Dependency Checks
# -----------------------------------------------------------------------------

check_dependencies() {
    info "Checking dependencies..."

    local missing=()

    command_exists curl || missing+=("curl")
    command_exists tar  || missing+=("tar")
    command_exists git  || missing+=("git")

    if [ ${#missing[@]} -ne 0 ]; then
        fatal "Missing required tools: ${missing[*]}"
    fi

    ok "All required tools present"
}

# -----------------------------------------------------------------------------
# Runtime Installation (Erlang + Elixir - optional, for development)
# -----------------------------------------------------------------------------

check_dev_runtime() {
    # The daemon binary includes bundled ERTS, so Erlang is NOT required to run it.
    # However, Erlang/Elixir are useful for developing agents.

    if command_exists erl && command_exists elixir; then
        ok "BEAM development runtime found (optional)"
    else
        info "BEAM runtime not found (Erlang/Elixir)"
        info "This is optional - the daemon includes bundled runtime."
        info "Install Erlang/Elixir if you want to develop agents:"
        echo ""
        echo "  curl https://mise.jdx.dev/install.sh | sh"
        echo "  mise install erlang@27 elixir@1.18"
        echo ""
    fi
}

# -----------------------------------------------------------------------------
# Hecate Daemon Installation
# -----------------------------------------------------------------------------

install_daemon() {
    info "Installing Hecate Daemon..."

    local os arch version url
    os=$(detect_os)
    arch=$(detect_arch)

    if [ "$HECATE_VERSION" = "latest" ]; then
        version=$(get_latest_release "hecate-daemon")
    else
        version="$HECATE_VERSION"
    fi

    # Download self-extracting executable (includes bundled Erlang runtime)
    url="${REPO_BASE}/hecate-daemon/releases/download/${version}/hecate-daemon-${os}-${arch}"

    mkdir -p "$BIN_DIR"

    download_file "$url" "${BIN_DIR}/hecate"
    chmod +x "${BIN_DIR}/hecate"

    ok "Hecate Daemon ${version} installed to ${BIN_DIR}/hecate"
}

# -----------------------------------------------------------------------------
# Hecate TUI Installation
# -----------------------------------------------------------------------------

install_tui() {
    info "Installing Hecate TUI..."

    local os arch version url
    os=$(detect_os)
    arch=$(detect_arch)

    if [ "$HECATE_VERSION" = "latest" ]; then
        version=$(get_latest_release "hecate-tui")
    else
        version="$HECATE_VERSION"
    fi

    url="${REPO_BASE}/hecate-tui/releases/download/${version}/hecate-tui-${os}-${arch}.tar.gz"

    mkdir -p "$BIN_DIR"
    local tmpfile
    tmpfile=$(mktemp)

    download_file "$url" "$tmpfile"
    tar -xzf "$tmpfile" -C "$BIN_DIR"
    rm -f "$tmpfile"

    chmod +x "${BIN_DIR}/hecate-tui"

    ok "Hecate TUI ${version} installed to ${BIN_DIR}/hecate-tui"
}

# -----------------------------------------------------------------------------
# Claude Skills Installation
# -----------------------------------------------------------------------------

install_skills() {
    info "Installing Hecate Skills for Claude Code..."

    local claude_dir="$HOME/.claude"
    mkdir -p "$claude_dir"

    download_file "${RAW_BASE}/SKILLS.md" "${claude_dir}/HECATE_SKILLS.md"

    # Add include to CLAUDE.md if not already present
    if [ -f "${claude_dir}/CLAUDE.md" ]; then
        if ! grep -q "HECATE_SKILLS.md" "${claude_dir}/CLAUDE.md"; then
            echo "" >> "${claude_dir}/CLAUDE.md"
            echo "## Hecate Skills" >> "${claude_dir}/CLAUDE.md"
            echo "" >> "${claude_dir}/CLAUDE.md"
            echo "See [HECATE_SKILLS.md](HECATE_SKILLS.md) for Hecate mesh integration skills." >> "${claude_dir}/CLAUDE.md"
        fi
    fi

    ok "Hecate Skills installed to ${claude_dir}/HECATE_SKILLS.md"
}

# -----------------------------------------------------------------------------
# Data Directory Setup
# -----------------------------------------------------------------------------

setup_data_dir() {
    info "Setting up Hecate data directory..."

    mkdir -p "${INSTALL_DIR}"/{data,logs,config}

    # Create default config if not exists
    if [ ! -f "${INSTALL_DIR}/config/hecate.conf" ]; then
        cat > "${INSTALL_DIR}/config/hecate.conf" << 'CONF'
# Hecate Node Configuration
# See: https://github.com/hecate-social/hecate-node

[daemon]
api_port = 4444
api_host = 127.0.0.1

[mesh]
bootstrap = ["boot.macula.io:4433"]

[logging]
level = info
CONF
    fi

    ok "Data directory created at ${INSTALL_DIR}"
}

# -----------------------------------------------------------------------------
# PATH Setup
# -----------------------------------------------------------------------------

setup_path() {
    info "Checking PATH..."

    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        warn "$BIN_DIR is not in PATH"
        echo ""
        echo "Add the following to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        echo ""
        echo "  export PATH=\"\$PATH:$BIN_DIR\""
        echo ""
    else
        ok "$BIN_DIR is in PATH"
    fi
}

# -----------------------------------------------------------------------------
# Pairing
# -----------------------------------------------------------------------------

prompt_pairing() {
    echo ""
    echo -e "${BOLD}Installation complete!${NC}"
    echo ""
    echo "To start using Hecate, you need to pair with the mesh:"
    echo ""
    echo "  1. Start the daemon:  hecate start"
    echo "  2. Run pairing:       hecate-tui pair"
    echo ""
    echo "Or run both in one command:"
    echo ""
    echo "  hecate start && hecate-tui pair"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    show_banner
    check_dependencies

    echo ""
    info "Installing Hecate Node..."
    info "  Install dir: ${INSTALL_DIR}"
    info "  Bin dir:     ${BIN_DIR}"
    info "  Version:     ${HECATE_VERSION}"
    echo ""

    setup_data_dir
    install_daemon
    check_dev_runtime
    install_tui
    install_skills
    setup_path
    prompt_pairing
}

main "$@"
