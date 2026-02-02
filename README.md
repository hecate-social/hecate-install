# Hecate Node

One-command installer for the complete Hecate stack.

## Quick Install

```bash
curl -fsSL https://hecate.social/install.sh | bash
```

## What Gets Installed

| Component | Description |
|-----------|-------------|
| **Hecate Daemon** | Erlang mesh network daemon (port 4444) |
| **Hecate TUI** | Terminal UI for monitoring and management |
| **Hecate Skills** | Claude Code integration for mesh operations |
| **BEAM Runtime** | Erlang OTP 27+ and Elixir 1.18+ (via mise/asdf) |

## Installation Paths

| Path | Contents |
|------|----------|
| `~/.local/bin/hecate` | Daemon binary |
| `~/.local/bin/hecate-tui` | TUI binary |
| `~/.hecate/` | Data directory (config, logs, state) |
| `~/.claude/HECATE_SKILLS.md` | Claude Code skills |

## Post-Install: Pairing

After installation, pair your node with the mesh:

```bash
# Start the daemon
hecate start

# Run pairing (shows QR code)
hecate-tui pair
```

Scan the QR code with the Hecate mobile app or visit the displayed URL.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HECATE_VERSION` | Version to install | `latest` |
| `HECATE_INSTALL_DIR` | Data directory | `~/.hecate` |
| `HECATE_BIN_DIR` | Binary directory | `~/.local/bin` |

## Manual Installation

If you prefer manual installation:

```bash
# 1. Install BEAM runtime
mise install erlang@27 elixir@1.18

# 2. Download daemon
curl -fsSL https://github.com/hecate-social/hecate-daemon/releases/latest/download/hecate-linux-amd64.tar.gz | tar xz -C ~/.local/bin

# 3. Download TUI
curl -fsSL https://github.com/hecate-social/hecate-tui/releases/latest/download/hecate-tui-linux-amd64.tar.gz | tar xz -C ~/.local/bin

# 4. Download skills
curl -fsSL https://raw.githubusercontent.com/hecate-social/hecate-node/main/SKILLS.md -o ~/.claude/HECATE_SKILLS.md
```

## Uninstall

```bash
curl -fsSL https://hecate.social/uninstall.sh | bash
```

Or manually:

```bash
rm ~/.local/bin/hecate ~/.local/bin/hecate-tui
rm -rf ~/.hecate
rm ~/.claude/HECATE_SKILLS.md
```

## Requirements

- Linux (x86_64, arm64) or macOS (arm64, x86_64)
- curl, tar, git
- Terminal with 256 color support (for TUI)

## Components

- [hecate-daemon](https://github.com/hecate-social/hecate-daemon) - Erlang mesh daemon
- [hecate-tui](https://github.com/hecate-social/hecate-tui) - Go terminal UI

## License

Apache 2.0 - See [LICENSE](LICENSE)

## Support

- [Issues](https://github.com/hecate-social/hecate-node/issues)
- [Buy Me a Coffee](https://buymeacoffee.com/rlefever)
