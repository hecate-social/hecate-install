# Hecate Ansible Deployment

Deploy Hecate across multiple nodes with a single command.

## Quick Start

```bash
# 1. Install Ansible
pip install ansible

# 2. Copy and customize inventory
cp inventory.example.ini inventory.ini
vim inventory.ini

# 3. Deploy everything
ansible-playbook -i inventory.ini hecate.yml
```

## Inventory Structure

```ini
[cluster]
beam00.lab          # Hecate daemon nodes
beam01.lab
beam02.lab
beam03.lab

[inference]
host00.lab          # Ollama-only nodes (zero or more)
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `hecate_realm` | `io.macula` | Macula mesh realm |
| `hecate_bootstrap` | `boot.macula.io:4433` | Bootstrap server |
| `ollama_host` | `http://localhost:11434` | Ollama URL |
| `ollama_models` | `['llama3.2']` | Models to pull on inference nodes |
| `hecate_image` | `ghcr.io/hecate-social/hecate-daemon:0.8.0` | Daemon image |
| `erlang_cookie` | (generated) | BEAM cluster shared cookie |

## Usage Examples

### Deploy entire cluster
```bash
ansible-playbook -i inventory.ini hecate.yml
```

### Deploy only cluster nodes
```bash
ansible-playbook -i inventory.ini hecate.yml --tags cluster
```

### Deploy only inference nodes
```bash
ansible-playbook -i inventory.ini hecate.yml --tags inference
```

### Skip firewall configuration
```bash
ansible-playbook -i inventory.ini hecate.yml --skip-tags firewall
```

### Check cluster status
```bash
ansible-playbook -i inventory.ini hecate.yml --tags status
```

### Dry run (check mode)
```bash
ansible-playbook -i inventory.ini hecate.yml --check
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Ansible Control Node                      │
│                  (your workstation)                          │
└───────────────────────┬─────────────────────────────────────┘
                        │ SSH
        ┌───────────────┼───────────────┬───────────────┐
        ▼               ▼               ▼               ▼
┌───────────┐   ┌───────────┐   ┌───────────┐   ┌───────────┐
│  Cluster  │   │  Cluster  │   │  Cluster  │   │ Inference │
│  beam00   │◄──│  beam01   │   │  beam02   │   │  host00   │
│           │   │           │   │           │   │           │
│ podman    │   │ podman    │   │ podman    │   │  Ollama   │
│ daemon    │   │ daemon    │   │ daemon    │   │   only    │
│ reconciler│   │ reconciler│   │ reconciler│   │           │
└───────────┘   └───────────┘   └───────────┘   └───────────┘
      ▲               ▲               ▲
      └───────────────┴───────────────┘
              BEAM Clustering (pg)
```

## Roles

| Role | Description |
|------|-------------|
| `common` | Dependencies, firewall, directories |
| `hecate-node` | Podman, reconciler, daemon deployment |
| `inference` | Ollama installation and configuration |

## Firewall Ports

### Cluster Nodes
- `4433/udp` - Macula mesh (QUIC)
- `4369/tcp` - EPMD (Erlang)
- `9100/tcp` - Erlang distribution

### Inference
- `11434/tcp` - Ollama API

## Troubleshooting

### SSH connection issues
```bash
# Test connectivity
ansible -i inventory.ini all -m ping
```

### Daemon not starting
```bash
# Check service status
ansible -i inventory.ini cluster -a "systemctl --user status hecate-daemon"

# Check logs
ansible -i inventory.ini cluster -a "journalctl --user -u hecate-daemon -n 20"

# Check podman
ansible -i inventory.ini cluster -a "podman ps -a"
```

### View service status
```bash
ansible -i inventory.ini cluster -a "systemctl --user list-units 'hecate-*'"
```
