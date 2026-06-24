
---

## Cutover to the Coolify hub (2026-06-23)

The hub moved from the mini to the in-Coolify Syncthing container.

- **Coolify hub device:** `2UXEJQY-PQMA4RM-CGNVCHP-Z6FJ3UM-OMOESEV-Z5B2NR6-FGB3T4M-YSLJFQD`
  (sync port published on `192.168.156.232:22000`; GUI internal-only — reach it via
  `docker exec <syncthing-container> syncthing cli ...` on srv2).
- Hub receive-only folders write into the `sources` volume:
  - `ag-claude-mini` -> `/var/syncthing/sources/claude/mini`
  - `cvsqq-kggtn`    -> `/var/syncthing/sources/claude/wyre_mbp`
- **mini**: now a pure spoke — shares `~/.claude/projects` **send-only** (folder
  `ag-claude-mini`) directly to the hub. Its local AgentGraphed launchd agents
  (`com.agentgraphed.server`, `com.agentgraphed.ingest`) are **retired** (booted
  out; plists kept for revert). Syncthing still runs on the mini.

### Finishing wyre_mbp (do when the laptop is awake)

wyre_mbp already shares `~/.claude/projects` as folder `cvsqq-kggtn`. Point it at
the Coolify hub (the hub side is already staged):

```bash
ST=$(command -v syncthing)
KEY=$(awk -F'[<>]' '/<apikey>/{print $3; exit}' "$HOME/Library/Application Support/Syncthing/config.xml")
CLI(){ "$ST" cli --gui-address 127.0.0.1:8384 --gui-apikey "$KEY" "$@"; }
CLI config devices add --device-id 2UXEJQY-PQMA4RM-CGNVCHP-Z6FJ3UM-OMOESEV-Z5B2NR6-FGB3T4M-YSLJFQD \
    --name agentgraphed-hub --addresses "tcp://192.168.156.232:22000,dynamic"
CLI config folders cvsqq-kggtn devices add --device-id 2UXEJQY-PQMA4RM-CGNVCHP-Z6FJ3UM-OMOESEV-Z5B2NR6-FGB3T4M-YSLJFQD
```

Then (optional) remove the mini from `cvsqq-kggtn` on wyre so it only talks to
the hub, fully decommissioning the mini's relay role.
