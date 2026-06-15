# agentgraphed-coolify

Self-hosted [AgentGraphed](https://github.com/sudomichael/agentgraphed) (local-first
analytics for Claude Code / Codex sessions) packaged to run on **Coolify** as the
central hub for an entire fleet of workstations.

Live at: **https://agentgraphed.sachshaus.net** (behind Authentik SSO).

## How it works

```
workstations ──Syncthing (Send Only)──▶ syncthing container ──▶ sources volume
                                                                     │ (read-only)
                                              agentgraphed ◀─────────┘  → dashboard
                                              ingest-cron pokes ingest every 5 min
```

- **agentgraphed** (built from `Dockerfile`) reads `*.jsonl` sessions out of the
  shared `sources` volume and serves the dashboard on port 3737.
- **syncthing** is the sync hub. Each workstation shares its `~/.claude/projects`
  (and `~/.codex/sessions`) as a **Send Only** folder to this hub; the hub accepts
  them **Receive Only** into `sources/claude/<host>/` and `sources/codex/<host>/`.
- **ingest-cron** triggers a re-scan every 5 minutes so the dashboard stays fresh
  without anyone having a browser tab open.

## Volumes

| Volume      | Mounted                              | Notes                                   |
|-------------|--------------------------------------|-----------------------------------------|
| `db`        | agentgraphed `/data`                 | SQLite DB. **Node-local only** (WAL).   |
| `sources`   | syncthing `rw`, agentgraphed `ro`    | Synced session files, per-host folders. |
| `st-config` | syncthing `/var/syncthing/config`    | Syncthing identity + folder config.     |

The `db` volume is rebuildable from `sources` (just re-ingest), so it is not precious.

## Adding a workstation

1. Install Syncthing on the workstation; pair it with this hub's device ID.
2. Share `~/.claude/projects` as **Send Only** (folder id `agentgraphed-claude-<host>`),
   and `~/.codex/sessions` if it uses Codex.
3. On the hub, accept each folder **Receive Only** with path
   `/var/syncthing/sources/claude/<host>` (or `codex/<host>`).

Within ~5 minutes the sessions appear in the dashboard.

## Updating AgentGraphed

Bump `AGENTGRAPHED_VERSION` in the `Dockerfile`, commit, and redeploy in Coolify.

## Auth

The app has no built-in authentication, so it is **only** exposed behind Authentik
forward-auth at the Traefik layer. Never publish it without that.
