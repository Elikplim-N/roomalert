# roomalert-2W-mini — telemetry receiver (Worker + D1)

Cloudflare Worker + D1 database for the **RoomAlert** fleet. Ingests telemetry
posted by devices and serves it back to the app.

## The fleet (3 repos)

| Repo | Role |
|------|------|
| **roomalert-2W-mini** (this) | Worker + D1 — telemetry ingest + read |
| **roomAlert-6W** | ESP32 firmware (posts telemetry) |
| **RT-Sense** | Flutter app (reads telemetry) |

Active branch for in-progress work: **`claude/adoring-mccarthy-7AfQ0`**.

## Endpoints (`src/index.ts`)

- `POST /` (any path) — device ingest. Body:
  `{ deviceId, timestamp, sensors: [ { temp, conn } ] }` (1–6 sensors).
  Stores into `telemetry_logs` columns `port_1..6_temp/_conn` (extra ports null).
- `GET /api/telemetry?deviceId=<id>&limit=<n>` — app read. Returns newest-first
  `{ deviceId, count, readings: [ { id, deviceId, timestamp, createdAt,
  sensors: [ { port, temp, conn } ] } ] }`. `limit` default 50, max 500. CORS open.

Keep these JSON shapes in sync with the firmware (`uploadToCloud()`) and the
app (`lib/gateway_provider.dart`). `MAX_PORTS = 6`.

## Commands

```sh
npm install
npm test                       # vitest (workers pool) — 6 tests
npx tsc --noEmit               # typecheck
npx wrangler dev               # local dev
npx wrangler deploy            # deploy → prints the Worker URL (use as CLOUD_URL)
npx wrangler d1 migrations apply roomalert_db --remote   # run migration on live DB
```

## Open / next steps

- [ ] Run the `migrations/` SQL on the live D1 (`--remote`) — adds ports 3–6.
- [ ] Deploy; give the URL to the firmware (`CLOUD_URL`) and the app (Cloud mode).
- [ ] `wrangler.jsonc` DB has `"remote": true` — risky (dev writes hit prod DB);
      consider switching to local for development.

---

# Cloudflare Workers (platform reference)

STOP. Your knowledge of Cloudflare Workers APIs and limits may be outdated. Always retrieve current documentation before any Workers, KV, R2, D1, Durable Objects, Queues, Vectorize, AI, or Agents SDK task.

## Docs

- https://developers.cloudflare.com/workers/
- MCP: `https://docs.mcp.cloudflare.com/mcp`

For all limits and quotas, retrieve from the product's `/platform/limits/` page. eg. `/workers/platform/limits`

## Commands

| Command | Purpose |
|---------|---------|
| `npx wrangler dev` | Local development |
| `npx wrangler deploy` | Deploy to Cloudflare |
| `npx wrangler types` | Generate TypeScript types |

Run `wrangler types` after changing bindings in wrangler.jsonc.

## Node.js Compatibility

https://developers.cloudflare.com/workers/runtime-apis/nodejs/

## Errors

- **Error 1102** (CPU/Memory exceeded): Retrieve limits from `/workers/platform/limits/`
- **All errors**: https://developers.cloudflare.com/workers/observability/errors/

## Product Docs

Retrieve API references and limits from:
`/kv/` · `/r2/` · `/d1/` · `/durable-objects/` · `/queues/` · `/vectorize/` · `/workers-ai/` · `/agents/`
