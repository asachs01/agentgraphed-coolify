# AgentGraphed packaged for a long-lived service.
#
# node:22 (glibc/bookworm) is deliberate: AgentGraphed pins better-sqlite3 ^11,
# which ships a prebuilt binary for Node 22's ABI on linux-x64 — so the install
# is a fast prebuild download, no native compile, no Alpine/musl headaches.
FROM node:22-bookworm-slim

# curl: used by the container HEALTHCHECK below.
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Pin the AgentGraphed version so image builds are reproducible. Bump + redeploy
# to upgrade.
ARG AGENTGRAPHED_VERSION=0.5.9

WORKDIR /opt/agentgraphed
RUN npm init -y >/dev/null 2>&1 \
 && npm install "agentgraphed@${AGENTGRAPHED_VERSION}" --no-audit --no-fund \
 && npm cache clean --force >/dev/null 2>&1

ENV NODE_ENV=production \
    PORT=3737 \
    HOSTNAME=0.0.0.0

# Run the Next.js standalone server directly (fixed port, no browser auto-open).
WORKDIR /opt/agentgraphed/node_modules/agentgraphed/.next/standalone
EXPOSE 3737

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -fsS -m 4 -o /dev/null http://127.0.0.1:3737/ || exit 1

CMD ["node", "server.js"]
