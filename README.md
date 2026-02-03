# Hecate Node

One-command installer for the complete Hecate stack with intelligent hardware detection and role-based setup.

## Quick Install

```bash
curl -fsSL https://hecate.social/install.sh | bash
```

## Node Roles

The installer asks what type of node you're setting up:

| Role | Installs | AI Setup | Use Case |
|------|----------|----------|----------|
| **Developer Workstation** | Daemon + TUI + Skills | Connect to AI node | Writing and testing agents |
| **Services Node** | Daemon only | Remote AI | Headless server hosting capabilities |
| **AI Node** | Daemon + Ollama | Local model, network-exposed | Dedicated AI server for your network |
| **All-in-one** | Everything | Local model | Self-contained development |

### Developer Workstation

Full development environment with Claude Code integration:
- Hecate daemon for mesh connectivity
- Terminal UI for monitoring
- Claude Code skills for AI-assisted development
- Connects to an AI node on your network (or local)

```bash
curl -fsSL https://hecate.social/install.sh | bash -s -- --role=workstation
```

### Services Node

Lightweight headless node for hosting services:
- Daemon only (no TUI or skills)
- Runs as systemd service (auto-start, background)
- API exposed to network (`0.0.0.0:4444`)
- Connects to AI node for inference

```bash
curl -fsSL https://hecate.social/install.sh | bash -s -- --role=services
```

### AI Node

Dedicated AI model server for your network:
- Ollama installed and configured for network access
- Large model pulled and ready to serve
- Other nodes connect to this for inference
- Shows your IP and connection URL for other nodes

```bash
curl -fsSL https://hecate.social/install.sh | bash -s -- --role=ai
```

### All-in-one

Everything running locally, no external dependencies:
- Full stack: daemon, TUI, skills, local AI
- Best for isolated development or single-machine setups

```bash
curl -fsSL https://hecate.social/install.sh | bash -s -- --role=full
```

## Features

### Intelligent Hardware Detection

The installer automatically detects and displays:
- **RAM** - Recommends appropriate model size
- **CPU cores** - Suggests role based on capacity
- **AVX2 support** - Optimizes inference performance
- **GPU** - Enables acceleration (NVIDIA, AMD, Apple Silicon)
- **Local IP** - For network configuration

### AI Node Discovery

When setting up a workstation, the installer:
1. Scans your local network for existing AI nodes
2. Tests connectivity to discovered servers
3. Lists available models on the AI node
4. Configures automatic connection

### Clear Sudo Explanations

When sudo is needed (Ollama install, systemd service), the installer:
1. Explains exactly what needs sudo and why
2. Shows the exact commands/files that will be created
3. Asks for explicit confirmation before proceeding

## Installation Options

```bash
# Interactive (recommended)
curl -fsSL https://hecate.social/install.sh | bash

# Preset role
curl -fsSL https://hecate.social/install.sh | bash -s -- --role=workstation
curl -fsSL https://hecate.social/install.sh | bash -s -- --role=services
curl -fsSL https://hecate.social/install.sh | bash -s -- --role=ai
curl -fsSL https://hecate.social/install.sh | bash -s -- --role=full

# Skip AI setup
curl -fsSL https://hecate.social/install.sh | bash -s -- --no-ai

# Non-interactive (CI/automation)
curl -fsSL https://hecate.social/install.sh | bash -s -- --headless

# Combine options
curl -fsSL https://hecate.social/install.sh | bash -s -- --role=services --no-ai
```

## What Gets Installed

| Component | Workstation | Services | AI Node | All-in-one |
|-----------|:-----------:|:--------:|:-------:|:----------:|
| Hecate Daemon | ✅ | ✅ | ✅ | ✅ |
| Hecate TUI | ✅ | ❌ | ✅ | ✅ |
| Claude Skills | ✅ | ❌ | ❌ | ✅ |
| Ollama | optional | ❌ | ✅ | ✅ |
| Systemd Service | ❌ | ✅ | optional | ❌ |

## Installation Paths

| Path | Contents |
|------|----------|
| `~/.local/bin/hecate` | Daemon binary |
| `~/.local/bin/hecate-tui` | TUI binary |
| `~/.hecate/` | Data directory |
| `~/.hecate/config/hecate.toml` | Configuration |
| `~/.claude/HECATE_SKILLS.md` | Claude Code skills |

## Configuration

The installer creates `~/.hecate/config/hecate.toml` with role-appropriate defaults:

```toml
# Role: workstation
[daemon]
api_port = 4444
api_host = "127.0.0.1"  # "0.0.0.0" for services/AI nodes

[mesh]
bootstrap = ["boot.macula.io:4433"]
realm = "io.macula"

[logging]
level = "info"

[ai]
provider = "ollama"
endpoint = "http://192.168.1.100:11434"  # Your AI node
model = "deepseek-coder:6.7b"
```

## Network Setup Example

A typical multi-node setup:

```
┌─────────────────────────────────────────────────────────────┐
│                     Your Network                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐ │
│   │   AI Node    │    │   Services   │    │  Workstation │ │
│   │  (beam01)    │    │   (beam02)   │    │  (laptop)    │ │
│   │              │    │              │    │              │ │
│   │ Ollama:11434 │◄───│  daemon:4444 │    │ daemon:4444  │ │
│   │ codellama:7b │    │  capabilities│    │ TUI + skills │ │
│   │              │◄───│              │    │              │ │
│   └──────────────┘    └──────────────┘    └──────┬───────┘ │
│          ▲                                       │          │
│          │                                       │          │
│          └───────────────────────────────────────┘          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HECATE_VERSION` | Version to install | `latest` |
| `HECATE_INSTALL_DIR` | Data directory | `~/.hecate` |
| `HECATE_BIN_DIR` | Binary directory | `~/.local/bin` |

## Sudo Requirements

The installer only requires sudo for:

| Component | Requires Sudo | Reason |
|-----------|:-------------:|--------|
| Ollama install | ✅ | Binary in `/usr/local/bin`, systemd service |
| Systemd service | ✅ | Service file in `/etc/systemd/system/` |
| Network config | ✅ | Ollama systemd override for `0.0.0.0` |

The installer clearly explains each sudo requirement and asks for confirmation.

## Uninstall

```bash
curl -fsSL https://hecate.social/uninstall.sh | bash
```

Or manually:

```bash
rm ~/.local/bin/hecate ~/.local/bin/hecate-tui
rm -rf ~/.hecate
rm ~/.claude/HECATE_SKILLS.md
sudo systemctl disable hecate 2>/dev/null
sudo rm /etc/systemd/system/hecate.service 2>/dev/null
```

## Requirements

- Linux (x86_64, arm64) or macOS (arm64, x86_64)
- curl, tar
- Terminal with 256 color support (for TUI)
- For AI: 4GB+ RAM (8GB+ recommended)

## Components

- [hecate-daemon](https://github.com/hecate-social/hecate-daemon) - Erlang mesh daemon
- [hecate-tui](https://github.com/hecate-social/hecate-tui) - Go terminal UI

## License

Apache 2.0 - See [LICENSE](LICENSE)

## Support

- [Issues](https://github.com/hecate-social/hecate-node/issues)
- [Buy Me a Coffee](https://buymeacoffee.com/rlefever)
