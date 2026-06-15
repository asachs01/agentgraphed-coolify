# AgentGraphed on Coolify — Design

Date: 2026-06-15
Status: Approved (build in progress)

## Goal

Run AgentGraphed as a Coolify-managed stack at **https://agentgraphed.sachshaus.net**,
behind **Authentik** forward-auth, ingesting Claude Code / Codex sessions from all
workstations (mini, wyre_mbp, future) via a **Syncthing hub that lives in the stack**.
Retire the mini's local instance once verified.

## Why this shape

- AgentGraphed only ever reads a local directory (`AGENTGRAPHED_CLAUDE_DIR` /
  `AGENTGRAPHED_CODEX_DIR`), recursively collecting `*.jsonl`. So "remote sessions"
  just means: something populates a directory the container mounts.
- Self-contained option chosen (option A): Syncthing runs **inside** the stack and
  owns the sources volume; spokes sync to it. No dependency on the mini.

## Components (one Coolify docker-compose resource, built from a public Git repo)

1. **agentgraphed** — built from `Dockerfile` (`node:22-bookworm-slim` → `npm i
   agentgraphed@<pin>` → run `.next/standalone/server.js`, `HOSTNAME=0.0.0.0`,
   `PORT=3737`). Node 22 + glibc = working better-sqlite3 11.x prebuild, no override
   needed. Mounts `db` (rw) + `sources` (ro).
2. **syncthing** — `syncthing/syncthing` image. Mounts `sources` (rw) + `st-config`.
   Sync ports 22000/tcp+udp, 21027/udp published on the node. GUI 8384 **not**
   published (internal only).
3. **ingest-cron** — `curlimages/curl` loop: `POST http://agentgraphed:3737/api/ingest-local`
   every 5 min (the app's own timer only arms after a first page load).

## Volumes

- **db** — node-local Docker named volume (MUST NOT be NFS/CIFS; SQLite WAL needs
  real locking). Rebuildable from sources, so not precious.
- **sources** — shared: syncthing writes, agentgraphed + cron read. Layout
  `sources/claude/<host>/…`, `sources/codex/<host>/…`.
- **st-config** — Syncthing identity/config.
- One compose ⇒ same node ⇒ shared local volumes work.

## Auth & exposure

- Coolify (srv2, mirroring the existing `diagrams` app) routes
  `agentgraphed.sachshaus.net` → `agentgraphed:3737` via Traefik + the existing
  `cloudflared` tunnel.
- Authentik: create a Proxy Provider + Application for the host (forward_domain mode,
  mirroring `diagrams`), assigned to the embedded Traefik outpost; attach the
  forward-auth middleware to the Coolify route. App is unauthenticated on its own,
  so the route is exposed **last**, only after auth is confirmed.

## Data flow

```
workstation Syncthing (Send Only) ──22000──▶ syncthing container (Receive Only)
   ~/.claude/projects → sources/claude/<host>/   writes → sources volume
                                                              │ ro
   agentgraphed ◀────────────────────────────────────────────┘  ingest (5-min cron) → db
   Traefik ◀─ Authentik forward-auth ◀─ cloudflared ◀─ you @ agentgraphed.sachshaus.net
```

## Migration / cutover

1. Stand up stack on srv2, internal-only, verify it serves + ingests (empty set).
2. Add Authentik provider/app + Traefik middleware + CF ingress; expose route; verify auth.
3. Re-point mini + wyre_mbp Syncthing Send-Only folders to the Coolify Syncthing
   device; accept as Receive-Only into `sources/{claude,codex}/<host>`.
4. Verify dashboard shows all machines; unload mini launchd agents (keep install
   until happy).

## Known trade-offs

- Quota/rate-limit panel empty in-container (no local credential files).
- Remote sessions get folder-name project labels (no git on non-existent paths).
- Leaderboard stays opt-out.
- db volume is node-local: moving nodes leaves the DB behind, but it rebuilds from sources.

## Driven via

- Coolify API at http://192.168.156.236:8000 (LAN; Tailscale IP not routable from mini).
- Authentik API at https://auth.sachshaus.net (needs an **admin** token; the supplied
  outpost token is read-only — POST returns 403).
- GitHub repo asachs01/agentgraphed-coolify (public) as the Coolify build source.
