<div align="center">
  <img src="assets/avatar-terminal.jpg" alt="Hecate" width="200"/>
  <h1>Hecate Node</h1>
  <p><em>One-command installer for the complete Hecate stack with intelligent hardware detection and role-based setup.</em></p>

  [![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-support-yellow?style=flat&logo=buy-me-a-coffee)](https://buymeacoffee.com/rgfaber)
  [![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
</div>

---

## Quick Install

```bash
curl -fsSL https://hecate.io/install.sh | bash
```

## Architecture

Hecate runs as **rootless Podman containers** managed by **systemd user services**:

```
~/.hecate/gitops/           ← Source of truth (Quadlet .container files)
    ↓ reconciler watches
~/.config/containers/systemd/  ← Podman Quadlet picks up symlinks
    ↓ systemctl --user daemon-reload
systemd user services          ← Containers run as user services
```

No Kubernetes. No root. No cluster overhead.

## Node Roles

| Role | What It Does | Use Case |
|------|-------------|----------|
| **Standalone** | Full stack on one machine | Laptop, desktop, single server |
| **Cluster** | Joins BEAM cluster with peers | Multi-node home lab |
| **Inference** | Ollama-only, no daemon | Dedicated GPU server |

### Example Configurations

**Standalone workstation** (default):
```bash
curl -fsSL https://hecate.io/install.sh | bash
```

**Headless server** (no desktop app):
```bash
curl -fsSL https://hecate.io/install.sh | bash -s -- --daemon-only
```

**Cluster node** (joins BEAM cluster):
```bash
curl -fsSL https://hecate.io/install.sh | bash
# Select "Cluster" role, provide cookie and peer addresses
```

**Inference node** (GPU server):
```bash
curl -fsSL https://hecate.io/install.sh | bash
# Select "Inference" role
```

## What Gets Installed

| Component | Standalone | Cluster | Inference |
|-----------|:---------:|:-------:|:---------:|
| Podman | yes | yes | - |
| Hecate Daemon | yes | yes | - |
| Reconciler | yes | yes | - |
| Hecate Web | optional | optional | - |
| Ollama | optional | optional | yes |

## Installation Flow

1. Detect hardware (RAM, CPU, GPU, storage)
2. Select node role (standalone / cluster / inference)
3. Select features (desktop app, Ollama)
4. Install podman + enable user lingering
5. Create `~/.hecate/` directory layout
6. Seed gitops with Quadlet files from hecate-gitops
7. Install reconciler (watches gitops, manages systemd units)
8. Deploy hecate-daemon via Podman Quadlet
9. Optionally install Hecate Web + Ollama
10. Install CLI wrapper

## Installation Paths

| Path | Contents |
|------|----------|
| `~/.hecate/` | Data root |
| `~/.hecate/hecate-daemon/` | Daemon data (sqlite, sockets, etc.) |
| `~/.hecate/gitops/system/` | Core Quadlet files (always present) |
| `~/.hecate/gitops/apps/` | Plugin Quadlet files (installed on demand) |
| `~/.hecate/config/` | Node-specific configuration |
| `~/.hecate/secrets/` | LLM API keys, age keypair |
| `~/.local/bin/hecate` | CLI wrapper |
| `~/.local/bin/hecate-reconciler` | GitOps reconciler |
| `~/.local/bin/hecate-web` | Desktop app (if installed) |
| `~/.config/containers/systemd/` | Podman Quadlet units (symlinks) |
| `~/.config/systemd/user/` | Reconciler systemd service |

## Managing Services

```bash
# CLI wrapper
hecate status                    # Show all hecate services
hecate logs                      # View daemon logs
hecate health                    # Check daemon health
hecate start                     # Start daemon
hecate stop                      # Stop daemon
hecate restart                   # Restart daemon
hecate update                    # Pull latest container images
hecate reconcile                 # Manual reconciliation

# Direct systemd
systemctl --user list-units 'hecate-*'
systemctl --user status hecate-daemon
journalctl --user -u hecate-daemon -f

# Reconciler
hecate-reconciler --status       # Show desired vs actual state
hecate-reconciler --once         # One-shot reconciliation
```

## Installing Plugins

Plugins are Podman Quadlet `.container` files. To install a plugin:

```bash
# Copy plugin container files to gitops/apps/
cp hecate-traderd.container ~/.hecate/gitops/apps/
cp hecate-traderw.container ~/.hecate/gitops/apps/

# The reconciler picks them up automatically
# Or trigger manually:
hecate reconcile
```

### Available Plugins

| Plugin | Daemon | Frontend | Description |
|--------|--------|----------|-------------|
| Trader | `hecate-traderd` | `hecate-traderw` (:5174) | Trading agent |
| Martha | `hecate-marthad` | `hecate-marthaw` (:5175) | AI agent |

## Network Setup Example

```
┌─────────────────────────────────────────────────────────┐
│                     Your Network                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   ┌──────────────┐    ┌──────────────┐                  │
│   │  Inference    │    │  Workstation │                  │
│   │  (beam01)     │    │  (laptop)    │                  │
│   │              │    │              │                  │
│   │ Ollama:11434 │◄───│ daemon       │                  │
│   │ llama3.2     │    │ hecate-web   │                  │
│   │              │    │ ollama       │                  │
│   └──────────────┘    └──────────────┘                  │
│          ▲                                               │
│          │          ┌──────────────┐                     │
│          │          │  Cluster     │                     │
│          └──────────│  (beam02)    │                     │
│                     │ daemon       │                     │
│                     │ plugins      │                     │
│                     └──────────────┘                     │
│                                                          │
└─────────────────────────────────────────────────────────┘
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
| Podman install | yes | Package manager |
| Ollama install | yes | Binary in `/usr/local/bin`, systemd service |
| Firewall rules | yes | System firewall configuration |
| User lingering | yes | `loginctl enable-linger` |

All hecate services run as **user-level systemd services** — no root needed at runtime.

## Uninstall

```bash
curl -fsSL https://hecate.io/uninstall.sh | bash
```

Or manually:

```bash
# Stop services
systemctl --user stop hecate-reconciler hecate-daemon

# Remove Quadlet links
rm ~/.config/containers/systemd/hecate-*.container
systemctl --user daemon-reload

# Remove binaries
rm ~/.local/bin/hecate ~/.local/bin/hecate-reconciler ~/.local/bin/hecate-web

# Remove data
rm -rf ~/.hecate
```

## Requirements

- Linux (x86_64, arm64) or macOS (arm64, x86_64)
- curl, git
- systemd (for service management)
- For desktop app: webkit2gtk-4.1
- For AI: 4GB+ RAM (8GB+ recommended)

## Components

- [hecate-daemon](https://github.com/hecate-social/hecate-daemon) - Erlang mesh daemon
- [hecate-web](https://github.com/hecate-social/hecate-web) - Tauri desktop app
- [hecate-gitops](https://github.com/hecate-social/hecate-gitops) - Quadlet templates + reconciler

## License

Apache 2.0 - See [LICENSE](LICENSE)

## Support

- [Issues](https://github.com/hecate-social/hecate-node/issues)
- [Buy Me a Coffee](https://buymeacoffee.com/rgfaber)
