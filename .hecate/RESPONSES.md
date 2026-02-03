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
