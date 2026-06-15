# Exposing agentgraphed.sachshaus.net (auth + tunnel)

Done **last**, after the stack is verified internally. The app has no built-in
auth, so it must never be reachable publicly without Authentik in front.

All values below are mirrored from the existing, working `diagrams` app.

## 1. Authentik — Proxy Provider + Application (needs an ADMIN API token)

The token supplied so far is the embedded-outpost service account (read-only:
`POST` returns 403). These calls need an admin token.

Mirror the `diagrams` provider (mode `forward_domain`):

```bash
source .secrets.env   # AUTHENTIK_URL, AUTHENTIK_ADMIN_TOKEN
AH=(-H "Authorization: Bearer $AUTHENTIK_ADMIN_TOKEN" -H "Content-Type: application/json")

# 1a. Proxy provider
curl -fsS "${AH[@]}" -X POST "$AUTHENTIK_URL/api/v3/providers/proxy/" -d '{
  "name": "agentgraphed",
  "mode": "forward_domain",
  "external_host": "https://agentgraphed.sachshaus.net",
  "authorization_flow": "577dd94e-8ed6-4c6d-ba3c-14dbaf078ac3",
  "invalidation_flow": "efa3882c-fa21-4c0b-9dc1-9300b5d0208a",
  "cookie_domain": "sachshaus.net",
  "access_token_validity": "hours=24"
}'
# -> note the returned provider pk  (call it NEWPK)

# 1b. Application bound to it
curl -fsS "${AH[@]}" -X POST "$AUTHENTIK_URL/api/v3/core/applications/" -d '{
  "name": "AgentGraphed",
  "slug": "agentgraphed",
  "provider": NEWPK
}'

# 1c. Attach provider to the embedded Traefik outpost (keep existing [3])
curl -fsS "${AH[@]}" -X PATCH \
  "$AUTHENTIK_URL/api/v3/outposts/instances/75012536-b9c3-4586-947e-720c1f1f361c/" \
  -d '{"providers": [3, NEWPK]}'
```

## 2. Coolify — domain + Traefik labels on the agentgraphed service

Set the service FQDN to `https://agentgraphed.sachshaus.net` (web service, port
3737) and apply these custom labels (same `authentik` middleware as `diagrams`,
only the host rule + port differ). Router/service names follow Coolify's
generated scheme for the compose app — confirm against the deployed labels.

```
traefik.enable=true
traefik.http.middlewares.gzip.compress=true
traefik.http.middlewares.authentik.forwardauth.address=https://auth.sachshaus.net/outpost.goauthentik.io/auth/traefik
traefik.http.middlewares.authentik.forwardauth.trustForwardHeader=true
traefik.http.middlewares.authentik.forwardauth.authResponseHeaders=X-authentik-username,X-authentik-groups,X-authentik-email,X-authentik-name,X-authentik-uid,X-authentik-jwt,X-authentik-meta-jwks,X-authentik-meta-outpost,X-authentik-meta-provider,X-authentik-meta-app,X-authentik-meta-version
traefik.http.routers.http-0-<ROUTER>.entryPoints=http
traefik.http.routers.http-0-<ROUTER>.middlewares=authentik,gzip
traefik.http.routers.http-0-<ROUTER>.rule=Host(`agentgraphed.sachshaus.net`)
traefik.http.routers.http-0-<ROUTER>.service=http-0-<ROUTER>
traefik.http.services.http-0-<ROUTER>.loadbalancer.server.port=3737
```

## 3. Cloudflare — DNS + tunnel ingress (needs CF access)

`agentgraphed.sachshaus.net` does not resolve and there is no `*.sachshaus.net`
wildcard, so add a per-host entry (mirroring how `diagrams` is published through
the existing `cloudflared` tunnel — Coolify service `emgvbr44d7yox5n9aocjxj63`):

- **DNS**: proxied CNAME `agentgraphed` → `<tunnel-id>.cfargotunnel.com`.
- **Tunnel ingress**: public hostname `agentgraphed.sachshaus.net` →
  same service `diagrams` points at (Traefik on coolify-srv2, e.g.
  `http://192.168.156.232:80`).

If the tunnel is dashboard-managed, this is two clicks in Zero Trust → Networks →
Tunnels. If config-managed, add the ingress rule alongside the `diagrams` one.

## 4. Verify

```bash
curl -sS -o /dev/null -w "%{http_code}\n" https://agentgraphed.sachshaus.net/
# expect 302 -> auth.sachshaus.net (Authentik login), NOT 200
```
A `200` without redirect means auth is NOT applied — stop and fix before cutover.
