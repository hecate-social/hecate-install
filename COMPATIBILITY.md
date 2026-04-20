# Compatibility Matrix

Tracks which hecate-install versions pair with which hecate-daemon versions,
and flags known drift.

**Last updated:** 2026-04-20.

---

## Current (rolling)

| hecate-install | hecate-daemon | Status |
|---|---|---|
| `main` (unreleased) | `0.16.x` (`:main` tag) | Live — tracks latest CI builds |

Most install paths in `main` pin the daemon to `ghcr.io/hecate-social/hecate-daemon:main`. With podman auto-update enabled, nodes pull new daemon builds automatically as CI merges land.

---

## Released

| hecate-install | hecate-daemon (tested) | Notes |
|---|---|---|
| `0.3.0` (2026-02-21) | `0.12.x` approx. | NixOS flake, pre-Briefcase, pre-MPong |
| `0.2.x` and earlier | `0.8.x` or older | k3s-based; DO NOT USE — superseded by podman + systemd --user |

---

## Install paths (status)

Three paths coexist today. The team is consolidating; use this table to
choose.

| Path | Location | Status | Use when |
|---|---|---|---|
| **Arch/CachyOS installer** | `scripts/hecate-install-arch.sh`, `archiso/` | 🟢 Active — most recent commits | You want a bootable live ISO for x86_64 laptops |
| **NixOS flake** | `flake.nix`, `modules/` | 🟡 Exploratory — not retested against current daemon | You prefer NixOS and are willing to debug |
| **Ansible** | `ansible/` | 🟡 For existing SSH-accessible machines | Reconfigure a fleet of Ubuntu/Debian nodes you already own |

The NixOS flake and Arch installer will be merged or one archived; see `.hecate/QUEUE.md` for the current consolidation work.

---

## Determinism vs freshness

Pick the tradeoff per deployment tier:

| Tier | Image tag | Why |
|---|---|---|
| Dev / home lab | `:main` | Always fresh; auto-update via podman |
| Staging / BEAM cluster | `:main` with alerting | Catch regressions on real hardware |
| Production / customer nodes | pinned semver (`:0.16.5`) | Deterministic rollback; upgrade on your schedule |

Pinned semver + podman auto-update still works — set `AutoUpdate=registry` and bump the tag only when you cut a release.

---

## Feature availability by daemon version

Minimum daemon versions for major user-visible capabilities:

| Capability | Introduced in |
|---|---|
| Pairing flow (Portal ↔ daemon) | `0.9.x` |
| Realm memberships | `0.10.x` |
| Site lifecycle | `0.11.x` |
| Plugin lifecycle (OCI install/upgrade) | `0.13.x` |
| MPong demo | `0.14.x` |
| **Briefcase** (realm-synced files) | `0.17.x` (planned; Phase 1 PRs #5–8 + Phase 2 #9) |

If you pin below these versions, the respective UI tabs in `hecate-web` will be empty or return 404.

---

## Checking at runtime

The daemon reports its version on the health endpoint:

```
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
     http://localhost/health
```

Response includes `{ "version": "0.16.5" }` (or similar). Use this to verify
the deployed version matches what you expect.
