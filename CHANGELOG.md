# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.12.0] - 2026-04-20

> Version numbering jumps from 0.3.0 to 0.12.0 to match the latest git tag
> (v0.11.2). The entries between 0.3.0 and this release were not captured in
> this file; consult `git log v0.3.0..v0.11.2` for that history.

### Added

- `COMPATIBILITY.md` — matrix of hecate-install ↔ hecate-daemon versions,
  install-path status, feature-per-minimum-daemon-version. Pairs with the
  hecate-daemon v0.18.0 release that ships Briefcase.
- `scripts/install-tools-arch.sh` — idempotent developer-workstation tool
  installer (pacman + AUR packages, skips already-installed).

### Changed

- **Default daemon image tag is now `:latest`** (was `:main`).
  `install.sh` / `install-hecate-node.sh` / `scripts/hecate-install-arch.sh` /
  `archiso/airootfs/usr/local/bin/hecate-install` /
  `scripts/fix-beam-docker.sh` / `scripts/migrate-hecate-to-fast.sh` /
  `ansible/inventory.example.ini` all updated. Bleeding-edge opt-in via
  `HECATE_TAG=main`; deterministic pin via `HECATE_TAG=v0.18.0`.
- `ansible/inventory.example.ini` — daemon image pin bumped from `:0.8.0`
  (8 minor versions behind) to `:latest`.
- `README.md` install-paths table lists all three active paths (Arch live
  ISO, install.sh, Ansible) with status indicators, and points at
  `COMPATIBILITY.md` for version guidance.

### Removed

- **NixOS flake** — `flake.nix`, `flake.lock`, and the associated
  NixOS-specific directories (`modules/`, `disko/`, `hardware/`, `home/`,
  `configurations/`, `tests/*.nix`, `packages/*.nix`) and scripts
  (`build-iso.sh`, `scripts/deploy-nixos-beam.sh`, `scripts/nix-build-iso.sh`,
  `scripts/hecate-install.sh`). The flake had drifted from the current
  hecate-daemon and the team chose to consolidate on the Arch live ISO /
  Ansible / `install.sh` paths. Git history preserves the NixOS state if
  it ever needs to come back.

## [0.3.0] - 2026-02-21

### Added

- **NixOS flake for bootable USB/ISO/SD images** ("Macula on a Stick")
  - `flake.nix` entry point with build targets for ISO, SD card, VM tests
  - Node role configurations: standalone, cluster, inference, workstation
  - Hardware profiles: beam-node (Celeron J4105), generic-x86, generic-arm64
  - 12 composable NixOS modules:
    - `hecate-directories` — tmpfiles rules for ~/.hecate/ tree
    - `hecate-reconciler` — GitOps reconciler package + systemd user service
    - `hecate-gitops` — Seeds Quadlet .container + .env on activation
    - `hecate-firewall` — Role-aware firewall rules (mesh, EPMD, Ollama)
    - `hecate-daemon` — OCI container via Quadlet
    - `hecate-cli` — CLI binary package
    - `hecate-ollama` — Wraps NixOS services.ollama
    - `hecate-secrets` — LLM API key management
    - `hecate-firstboot` — QR code + pairing wizard (runs once)
    - `hecate-mesh` — Macula mesh configuration
    - `hecate-web` — Desktop app (workstation only)
    - `hecate-cluster` — BEAM clustering options (cookie, peers)
  - NixOS VM integration tests: boot, plugin lifecycle, firstboot
  - Firstboot wizard with responsive web UI + pairing code flow
  - Pre-configured beam00-03 cluster node definitions in flake.nix

### Build Commands

- `nix build .#iso-standalone` — Bootable ISO (standalone role)
- `nix build .#iso-cluster` — Bootable ISO (cluster role)
- `nix build .#iso-inference` — Bootable ISO (inference role)
- `nix flake check` — Run all VM integration tests

### Unchanged

- `install.sh` — Still works for existing Linux machines (any distro)
- `uninstall.sh` — Unchanged
- `ansible/` — Unchanged

## [0.2.0] - 2026-02-18

### Changed

- **Architecture: systemd + podman replaces k3s**
  - Rootless Podman containers via Quadlet `.container` files
  - systemd user services for lifecycle management
  - No Kubernetes, no root needed at runtime
- `install.sh` rewritten for new architecture
  - Installs podman instead of k3s
  - Installs reconciler instead of FluxCD
  - Seeds `~/.hecate/gitops/` with Quadlet files from hecate-gitops
  - Deploys daemon via Podman Quadlet (not DaemonSet)
  - Simplified node roles: standalone, cluster, inference
  - Drops TUI installation (replaced by hecate-web desktop app)
  - CLI wrapper uses `systemctl` instead of `kubectl`
- `uninstall.sh` rewritten for new architecture
  - Stops systemd user services
  - Removes Quadlet symlinks and container images
  - Cleans up reconciler service
- Ansible playbook updated for systemd + podman deployment
- Firewall ports simplified (no k3s-specific ports)

### Removed

- k3s installation and management
- FluxCD installation
- TUI (Go/Bubble Tea) installation
- kubeconfig management
- DaemonSet/kubectl CLI wrapper
- Bare git repo for local Flux git server

### Added

- Podman rootless container support
- Reconciler (watches `~/.hecate/gitops/`, manages systemd units)
- User lingering (`loginctl enable-linger`) for persistent services
- BEAM cluster join configuration (cookie + peers)
- inotify-tools dependency for filesystem watching
- Hecate Web (Tauri desktop app) installation

## [0.1.0] - 2026-02-02

### Added

- Initial release
- `install.sh` - One-command installer (`curl | bash`)
  - Installs k3s, FluxCD, hecate-daemon, hecate-tui
  - Hardware detection (RAM, CPU, GPU, AVX2)
  - Node role selection (standalone, server, agent, inference)
  - Ollama installation and model selection
  - Firewall configuration
- `uninstall.sh` - Clean removal script
- `SKILLS.md` - Hecate Skills for mesh operations
- Ansible playbook for multi-node deployment
