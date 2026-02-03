# Apprentice Responses

*Write here when you need Hecate's attention.*

---

Types: `COMPLETE`, `QUESTION`, `BLOCKED`, `DECISION`, `UPDATE`

---

## Messages

*(Write below this line)*

---

## 2026-02-03 COMPLETE: Install Script Hardened (No jq Dependency)

### Summary

The `install.sh` script has been hardened to work on systems without `jq`:

1. **Removed ALL jq usages**
   - All JSON parsing now uses `grep -o` and `sed`
   - Works on minimal systems (Alpine, base Ubuntu, etc.)

2. **Auto-PATH configuration**
   - Detects user's shell profile (`.zshrc` > `.bashrc` > `.profile`)
   - Adds PATH export if not present
   - Exports for current session immediately

3. **Bash strict mode fix**
   - `${ZSH_VERSION:-}` instead of `$ZSH_VERSION` for `set -u` compatibility

### Test Results (beam00.lab)

```
[OK] Identity created: mri:agent:io.macula/anonymous/hecate-635a

  Confirmation code:  949477
  Open this URL to confirm:
  https://macula.io/pair/019c231e-faea-7c45-a46c-e9295ff5bf84

[OK] Paired successfully!
```

**Full end-to-end flow works without jq installed.**

### Related Work (macula-realm)

Fixed two bugs in `macula-io/macula-realm` that were blocking the pairing flow:

**1. LiveView form input bug** (`apps/macula_realm_web/lib/macula_realm_web/live/pair_device_live.ex`)
- Was using `phx-keyup` with `phx-value-code={@code_input}` (sends stale value from assigns)
- Fixed to use `phx-change` on form with `name="code"` input (sends actual input value)

**2. Auth redirect bug** (`apps/macula_realm_web/lib/macula_realm_web/plugs/auth.ex`)
- `require_authenticated_user` was redirecting to `/` instead of `/sign-in`
- Fixed to redirect to `/sign-in` with `return_to` URL stored in session
- `auth_controller.ex` updated to check session for `return_to` after OAuth callback

**Both deployed to macula.io and verified working.**

### Commits

**hecate-node:**
- `fix: Remove jq dependency, auto-configure PATH`
- `fix: Handle unset ZSH_VERSION in bash strict mode`

**macula-realm:**
- `fix: Use phx-change on form for pairing code input`
- `fix: Redirect unauthenticated users to /sign-in with return_to`

---

*Ready for next tasks.* 🗝️

---

## 2026-02-03 COMPLETE: Cross-Repo Verification & SKILLS.md Audit

### Task Reference
- 🟡 MEDIUM: Review Install Script
- 🟢 LOW: SKILLS.md Review

---

### Cross-Repo Verification Summary

Verified actual implementations against documentation across:
- `hecate-daemon` (Erlang API)
- `hecate-node` (installer, CLI wrapper, SKILLS.md)
- `hecate-tui` (Go TUI)
- `macula-realm` (pairing backend)

---

### Install Script Review (`install.sh`)

**Status: ✅ CORRECT**

The CLI wrapper (lines 866-1055) matches the daemon API:
- `hecate health` → `GET /health` ✅
- `hecate identity` → `GET /identity` ✅
- `hecate init` → `POST /identity/init` ✅
- `hecate pair` → `POST /api/pairing/start`, `GET /api/pairing/status` ✅
- `hecate llm models` → `GET /api/llm/models` ✅
- `hecate llm health` → `GET /api/llm/health` ✅
- `hecate llm chat` → `POST /api/llm/chat` ✅

---

### Uninstall Script Review (`uninstall.sh`)

**Gap: PATH entries not cleaned up** (still valid)

---

### SKILLS.md Review - CRITICAL DRIFT FOUND

**🔴 SKILLS.md is significantly out of sync with actual daemon API**

#### Endpoints That Don't Exist (documented but NOT in daemon):

| Documented | Reality |
|------------|---------|
| `POST /rpc/register` | ❌ Does not exist |
| `POST /rpc/call` | ❌ Does not exist |
| `POST /pubsub/subscribe` | ❌ Wrong path |
| `POST /pubsub/publish` | ❌ Does not exist |
| `GET /pubsub/subscriptions` | ❌ Wrong path |
| `GET /social/followers` | ❌ Missing `:agent_identity` param |
| `GET /social/following` | ❌ Missing `:agent_identity` param |
| `GET /ucan/granted` | ❌ Does not exist |
| `GET /ucan/received` | ❌ Does not exist |

#### Correct Endpoints (from hecate_api_app.erl):

**Capabilities:**
- `POST /capabilities/announce`
- `POST /capabilities/discover` (not GET!)
- `GET /capabilities/:mri`
- `PUT /capabilities/:mri/update`
- `DELETE /capabilities/:mri/retract`

**Subscriptions (not PubSub!):**
- `GET /subscriptions`
- `POST /subscriptions/subscribe`
- `DELETE /subscriptions/unsubscribe`
- `GET /subscriptions/stats`

**Social:**
- `POST /social/follow`
- `POST /social/unfollow`
- `POST /social/endorse`
- `DELETE /social/endorsement/revoke`
- `GET /social/followers/:agent_identity`
- `GET /social/following/:agent_identity`
- `GET /social/endorsements/:agent_identity`
- `GET /social/graph/:agent_identity`

**RPC (tracking only):**
- `POST /rpc/track`

**UCAN:**
- `POST /ucan/grant`
- `DELETE /ucan/revoke/:capability_id`
- `GET /ucan/capabilities`
- `GET /ucan/verify/:capability_id`
- `POST /ucan/verify`

**Identity:**
- `GET /identity`
- `POST /identity/init`

**Pairing:**
- `POST /api/pairing/start`
- `GET /api/pairing/status`
- `POST /api/pairing/cancel`

**LLM:**
- `GET /api/llm/models`
- `POST /api/llm/chat`
- `GET /api/llm/health`

**Agents:**
- `GET /agents`
- `POST /agents/register`
- `GET /agents/:agent_identity`
- `PUT /agents/:agent_identity/update`

**Reputation:**
- `GET /reputation/:agent_identity`
- `GET /rpc-calls`
- `GET /disputes`

---

### macula-realm Pairing - Missing Route

**Found:** `PairingSessionController.confirm/2` action exists but **route is not defined** in router.ex.

Should be: `POST /api/v1/pairing/sessions/:id/confirm`

---

### hecate-tui Status

Currently read-only, calls:
- `GET /health`
- `GET /identity`
- `GET /capabilities/discover` (note: should be POST per daemon)
- `GET /rpc/procedures` (note: endpoint doesn't exist in daemon!)
- `GET /subscriptions`

**Potential bug:** TUI may be calling endpoints that don't exist or using wrong methods.

---

### Summary

| Finding | Severity | Action |
|---------|----------|--------|
| Install script CLI wrapper | ✅ Good | None |
| Uninstall PATH cleanup | 🟡 Medium | Add cleanup |
| **SKILLS.md accuracy** | 🔴 **Critical** | **Complete rewrite needed** |
| macula-realm missing route | 🟡 Medium | Add confirm route |
| hecate-tui endpoint mismatch | 🟡 Medium | Verify/fix API calls |

**Recommendation:** SKILLS.md needs complete rewrite to match actual daemon API in `hecate_api_app.erl`.

*Cross-repo verification complete.* 🗝️
