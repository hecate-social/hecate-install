# 🔥 Hecate's Queue 🔥

*Commands from the goddess. Read and obey.*

---

## Protocol

| File | Your Access |
|------|-------------|
| `QUEUE.md` | **READ-ONLY** |
| `RESPONSES.md` | Write here |
| `STATUS.md` | Update here |

---

## Context

This is the **one-command installer** for the Hecate stack.

```bash
curl -fsSL https://hecate.social/install.sh | bash
```

Installs: daemon + TUI + Hecate Skills + BEAM runtime

---

## Active Tasks

### 🔴 HIGH [node]: Complete Rewrite of SKILLS.md

**SKILLS.md is severely out of sync with the actual daemon API.**

Cross-reference verified these fake endpoints (DO NOT EXIST):
- `POST /rpc/register` ❌
- `POST /rpc/call` ❌
- `GET /rpc/procedures` ❌
- `POST /pubsub/subscribe` ❌ (actual: `/subscriptions/subscribe`)
- `POST /pubsub/publish` ❌
- `GET /pubsub/subscriptions` ❌ (actual: `/subscriptions`)
- `GET /social/followers` ❌ (actual: `/social/followers/:agent_identity`)
- `GET /ucan/granted` ❌ (actual: `/ucan/capabilities`)
- `GET /ucan/received` ❌

**Source of truth:** `hecate-daemon/apps/hecate_api/src/hecate_api_app.erl`

**Rewrite SKILLS.md to document ONLY endpoints that exist:**

1. Health & Identity: `/health`, `/identity`, `/identity/init`
2. Pairing: `/api/pairing/start`, `/api/pairing/status`, `/api/pairing/cancel`
3. Capabilities: `/capabilities/announce`, `/capabilities/discover`, `/capabilities/:mri`, etc.
4. Social: `/social/follow`, `/social/unfollow`, `/social/followers/:agent_identity`, etc.
5. Subscriptions: `/subscriptions`, `/subscriptions/subscribe`, etc.
6. UCAN: `/ucan/grant`, `/ucan/revoke/:capability_id`, `/ucan/capabilities`, etc.
7. LLM: `/api/llm/models`, `/api/llm/chat`, `/api/llm/health`
8. Agents: `/agents`, `/agents/register`, etc.
9. Reputation: `/reputation/:agent_identity`, `/rpc-calls`, `/disputes`

**Include HTTP method for each endpoint (GET/POST/PUT/DELETE).**

---

### 🟡 MEDIUM [node]: PATH Cleanup in uninstall.sh

Installer adds PATH to shell profiles but uninstaller doesn't clean up.

Add to `uninstall.sh`:
```bash
for profile in ~/.bashrc ~/.zshrc ~/.profile; do
    if [ -f "$profile" ] && grep -q "Hecate CLI" "$profile"; then
        sed -i '/# Hecate CLI/d' "$profile"
        sed -i '/\.local\/bin/d' "$profile"
    fi
done
```

---

### 🟡 MEDIUM [tui]: Fix Endpoint Mismatch

TUI calls `/rpc/procedures` which doesn't exist in daemon.

Check `internal/client/client.go` and fix to match actual daemon API.

Cross-reference with `hecate_api_app.erl` routes.

---

## Completed Tasks

*(none yet)*

---

*— Hecate* 🗝️
