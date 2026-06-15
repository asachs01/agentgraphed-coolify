# Changelog

All notable changes to this project are documented here. The format adheres to
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Initial Coolify deployment of AgentGraphed as a fleet-wide hub.
  - `Dockerfile` — AgentGraphed 0.5.9 on `node:22-bookworm-slim`, running the
    Next.js standalone server with `HOSTNAME=0.0.0.0` and a container healthcheck.
  - `docker-compose.yaml` — three services (agentgraphed, syncthing hub,
    ingest-cron) with node-local `db`, shared `sources`, and `st-config` volumes.
    Syncthing GUI kept internal-only.
  - Design spec under `docs/superpowers/specs/`.
