# Hecate Skills

Skills for interacting with the Hecate mesh network daemon. Used by Hecate Web, the CLI, and compatible AI coding assistants.

## Overview

Hecate is a mesh network daemon that enables AI agents to:
- Discover and announce capabilities on the mesh
- Build reputation through tracked RPC calls
- Manage UCAN-based capability tokens
- Access local LLM inference
- Manage social connections and mentorships

The daemon communicates via Unix socket at `~/.hecate/hecate-daemon/sockets/api.sock`.

---

## Health & Node Identity

### Health Check

```bash
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock http://localhost/health
```

**Response:**
```json
{"status": "healthy", "version": "0.11.2", "uptime_seconds": 3600}
```

### Get Node Identity

```bash
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock http://localhost/api/node/identity
```

**Response:**
```json
{
  "ok": true,
  "node_identity": {
    "mri": "mri:agent:io.macula/anonymous/hecate-a1b2",
    "public_key": "base64...",
    "realm": "io.macula",
    "initialized": true
  }
}
```

Node identity auto-initializes on first boot (Ed25519 keypair + MRI).

---

## Settings

### Get Settings

```bash
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock http://localhost/api/settings
```

**Response:**
```json
{
  "ok": true,
  "identity": {
    "hecate_user_id": "user-abc123",
    "linux_user": "rl",
    "hostname": "myhost",
    "github_user": "rgfaber",
    "realm": "io.macula",
    "paired": true,
    "paired_at": 1740000000,
    "initiated_at": 1739900000,
    "status": 3
  },
  "preferences": {}
}
```

### Get Identity (subset)

```bash
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock http://localhost/api/settings/identity
```

### Update Preferences

```bash
curl -X PUT --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/settings/preferences \
  -H "Content-Type: application/json" \
  -d '{"theme": "dark"}'
```

---

## Pairing

### Initiate Pairing

```bash
curl -X POST --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/pairing/initiate
```

**Response:**
```json
{
  "ok": true,
  "session_id": "uuid-here",
  "confirm_code": "123456",
  "pairing_url": "https://macula.io/pair/uuid-here?code=123456",
  "expires_in": 600
}
```

The pairing URL includes the confirmation code for seamless auto-confirmation.

### Check Pairing Status

```bash
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/pairing/status
```

**Response:**
```json
{"ok": true, "status": "pairing", "confirm_code": "123456", "expires_in": 542}
```

Status values: `idle`, `pairing`, `paired`, `failed`

### Cancel Pairing

```bash
curl -X POST --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/pairing/cancel
```

### Simple Pair (CLI/testing)

```bash
curl -X POST --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/settings/pair \
  -H "Content-Type: application/json" \
  -d '{"github_user": "rgfaber"}'
```

### Unpair

```bash
curl -X POST --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/settings/unpair
```

---

## LLM (Local Inference)

### List Available Models

```bash
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/llm/models
```

**Response:**
```json
{
  "ok": true,
  "models": [
    {"name": "llama3.2:latest", "size": 2000000000, "modified_at": "2026-01-15T10:30:00Z"}
  ]
}
```

### Chat Completion

```bash
curl -X POST --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/llm/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ],
    "stream": false
  }'
```

**Response:**
```json
{
  "ok": true,
  "content": "Hello! How can I help you today?",
  "model": "llama3.2",
  "eval_count": 15
}
```

For streaming responses, set `"stream": true` to receive Server-Sent Events (SSE).

### LLM Health Check

```bash
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/llm/health
```

### List Providers

```bash
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/llm/providers
```

### Add Provider

```bash
curl -X POST --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/llm/providers/add \
  -H "Content-Type: application/json" \
  -d '{"name": "openai", "api_key": "sk-..."}'
```

### Reload Providers

```bash
curl -X POST --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/llm/providers/reload
```

### Remove Provider

```bash
curl -X POST --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/llm/providers/:name/remove
```

### Usage / Cost Tracking

```bash
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/llm/usage/cost

# Per venture:
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/llm/usage/cost/:venture_id
```

---

## Mentorships

### Submit Learning

```bash
curl -X POST --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/mentors/learnings/submit \
  -H "Content-Type: application/json" \
  -d '{"topic": "erlang", "content": "OTP supervision trees..."}'
```

### List Learnings

```bash
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/mentors/learnings
```

### Get Learning by ID

```bash
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/mentors/learnings/:learning_id
```

### Validate / Reject / Endorse / Dispute / Resolve Learning

```bash
curl -X POST --unix-socket ... http://localhost/api/mentors/learnings/:id/validate
curl -X POST --unix-socket ... http://localhost/api/mentors/learnings/:id/reject
curl -X POST --unix-socket ... http://localhost/api/mentors/learnings/:id/endorse
curl -X POST --unix-socket ... http://localhost/api/mentors/learnings/:id/dispute
curl -X POST --unix-socket ... http://localhost/api/mentors/learnings/:id/resolve
```

### Mentor Profiles

```bash
curl --unix-socket ... http://localhost/api/mentors/profiles
curl --unix-socket ... http://localhost/api/mentors/profiles/:agent_id
```

### Mentor Subscriptions

```bash
curl -X POST --unix-socket ... http://localhost/api/mentors/subscribe
curl -X POST --unix-socket ... http://localhost/api/mentors/unsubscribe
curl --unix-socket ... http://localhost/api/mentors/subscriptions
```

### Expertise

```bash
curl -X POST --unix-socket ... http://localhost/api/mentors/expertise
curl -X POST --unix-socket ... http://localhost/api/mentors/expertise/withdraw
```

### Remote Learnings

```bash
curl --unix-socket ... http://localhost/api/mentors/remote
```

---

## Appstore (Licenses & Catalog)

### Browse Catalog

```bash
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/appstore/catalog
```

### Get Plugin Details

```bash
curl --unix-socket ... http://localhost/api/appstore/plugin/:id
```

### List Licenses

```bash
curl --unix-socket ... http://localhost/api/appstore/licenses
```

### License Lifecycle

```bash
curl -X POST --unix-socket ... http://localhost/api/appstore/licenses/initiate
curl -X POST --unix-socket ... http://localhost/api/appstore/licenses/buy
curl -X POST --unix-socket ... http://localhost/api/appstore/licenses/revoke
curl -X POST --unix-socket ... http://localhost/api/appstore/licenses/archive
curl -X POST --unix-socket ... http://localhost/api/appstore/licenses/:id/announce
curl -X POST --unix-socket ... http://localhost/api/appstore/licenses/:id/publish
```

---

## Plugins

### List Installed Plugins

```bash
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/node/plugins
```

### Install / Upgrade / Remove Plugin

```bash
curl -X POST --unix-socket ... http://localhost/api/node/plugins/install
curl -X POST --unix-socket ... http://localhost/api/node/plugins/upgrade
curl -X POST --unix-socket ... http://localhost/api/node/plugins/remove
```

---

## RPC

### Call Remote Procedure

```bash
curl -X POST --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/rpc/call \
  -H "Content-Type: application/json" \
  -d '{
    "procedure": "weather.forecast",
    "args": {"location": "Brussels"}
  }'
```

---

## Geographic Restrictions

### Check Geo Status

```bash
curl --unix-socket ... http://localhost/api/geo/status
```

### Reload Geo Database

```bash
curl -X POST --unix-socket ... http://localhost/api/geo/reload
```

### Check IP

```bash
curl --unix-socket ... http://localhost/api/geo/check/:ip
```

---

## Sidebar Configuration

### Get Sidebar Config

```bash
curl --unix-socket ... http://localhost/api/config/sidebar
```

### Update Sidebar Config

```bash
curl -X PUT --unix-socket ... http://localhost/api/config/sidebar \
  -H "Content-Type: application/json" \
  -d '{"items": [...]}'
```

---

## Streaming

### Facts Stream (SSE)

```bash
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/facts/stream
```

Server-Sent Events stream for real-time domain events.

---

## MRI Format

Macula Resource Identifiers (MRIs) follow this format:

```
mri:{type}:{realm}/{owner}/{name}
```

| Type | Description | Example |
|------|-------------|---------|
| `agent` | An agent identity | `mri:agent:io.macula/myuser/hecate-a1b2` |
| `capability` | A discoverable capability | `mri:capability:io.macula/myuser/weather` |
| `org` | An organization | `mri:org:io.macula/my-company` |

---

## Response Format

All API responses follow this format:

**Success:**
```json
{"ok": true, "result": {...}}
```

**Error:**
```json
{"ok": false, "error": "description of what went wrong"}
```

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HECATE_HOSTNAME` | Override hostname inside container | Host hostname |
| `HECATE_USER` | Override user inside container | Host user |

---

## CLI Commands

The `hecate` CLI wrapper provides convenient access:

```bash
# Service management
hecate status         # Show all hecate services
hecate start          # Start the daemon
hecate stop           # Stop the daemon
hecate restart        # Restart the daemon
hecate logs           # View daemon logs
hecate health         # Check daemon health
hecate update         # Pull latest container images
hecate reconcile      # Manual reconciliation

# Identity & pairing
hecate identity       # Show agent identity (MRI, public key)
hecate pair           # Start pairing flow

# LLM
hecate llm models     # List available LLM models
hecate llm health     # Check LLM backend status
hecate llm chat       # Chat with a model
```

---

## Desktop App

Hecate Web provides a graphical interface:

```bash
hecate-web            # Launch desktop app
```

The desktop app connects to the daemon via Unix socket and provides
studio-based workflows for LLM interaction, node management, and more.
