# Compatibility Matrix

Tracks which hecate-install versions pair with which hecate-daemon versions,
and flags known drift.

**Last updated:** 2026-04-20.

---

## Current (rolling)

| hecate-install | hecate-daemon | Status |
|---|---|---|
| `main` (unreleased) | `0.16.x` (`:latest` tag) | Live — tracks most recent tagged release |

Install paths default to `ghcr.io/hecate-social/hecate-daemon:latest`
(multi-arch, built on every `v*` git tag). With podman `AutoUpdate=registry`,
nodes pull new daemon releases automatically as they are cut.

Developers can opt into bleeding edge with `HECATE_TAG=main` (amd64 only,
built on every `main` branch push).

---

## Released

| hecate-install | hecate-daemon (tested) | Notes |
|---|---|---|
| `0.3.0` (2026-02-21) | `0.12.x` approx. | NixOS flake, pre-Briefcase, pre-MPong |
| `0.2.x` and earlier | `0.8.x` or older | k3s-based; DO NOT USE — superseded by podman + systemd --user |

---

## Install paths

Three active paths after NixOS was retired (2026-04-20):

| Path | Location | Use when |
|---|---|---|
| **Arch live ISO** | `archiso/`, `scripts/hecate-install-arch.sh` | You want a bootable live ISO for x86_64 laptops |
| **install.sh** | `install.sh` | You already have a Linux machine and just want to provision it |
| **Ansible** | `ansible/` | You want to reconfigure a fleet of SSH-accessible nodes you already own |

The NixOS flake (`flake.nix`, `modules/`, `disko/`, `hardware/`, `home/`,
`configurations/`, `tests/*.nix`) was removed — it drifted from the active
daemon and the team chose to consolidate on the Arch/Ansible paths.
Historical state lives in git history if ever needed again.

---

## Determinism vs freshness

Pick the tradeoff per deployment tier:

| Tier | Image tag | Why |
|---|---|---|
| Production / customer nodes | `:latest` (default) | Multi-arch, tagged-release-only, auto-updates on new releases |
| Pinned production | `:v0.16.5` | Deterministic rollback; upgrade on your schedule |
| Dev / bleeding edge | `:main` | amd64 only, every main-branch push, may be unstable |

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
