# RoomAlert monorepo — agent handoff

One repo, three deployable pieces. Each subfolder has its own detailed
`AGENTS.md` — read the relevant one before working in it.

| Folder | Stack | Detailed guide |
|--------|-------|----------------|
| `firmware/` | ESP32 / Arduino C++ | `firmware/AGENTS.md` |
| `cloud/` | Cloudflare Worker + D1 (TypeScript) | `cloud/AGENTS.md` |
| `app/` | Flutter / Dart | `app/AGENTS.md` |

## Golden rule: the data contract spans all three folders

A device reports 1–6 sensor ports. Disconnected ports = `temp: null, conn: false`.

- Firmware → Cloud (`POST`): `{ deviceId, timestamp, sensors: [{ temp, conn }] }`
- Cloud → App (`GET /api/telemetry`): `{ readings: [{ timestamp, sensors: [{ port, temp, conn }] }] }`
- Device → App direct (`GET /api/status`): `{ ports: [{ id, name, temp, conn }] }`

Changing any of these means changing the matching parse/serialize code in the
other folders. Don't break the contract.

## Build / test commands

```sh
# cloud
cd cloud && npm install && npm test && npx tsc --noEmit

# app
cd app && flutter pub get && flutter analyze

# firmware: compile in Arduino IDE (no CLI build); keep webpage.h beside the .ino
```

## Open / next steps (carried over from initial build)

- [ ] `app/`: run `flutter analyze` + manually test each mode — code was written
      without a Flutter toolchain available, so it is not analyzer-verified.
- [ ] `firmware/`: compile in Arduino IDE; cloud-upload + OTA code was not
      compiler-verified. Set a real `CLOUD_URL`.
- [ ] `cloud/`: deploy, run the D1 migration on the live DB (`--remote`), and
      reconsider `wrangler.jsonc` DB `"remote": true` (dev hits prod DB).
- [ ] Wire the same Worker URL + `deviceId` into firmware and app for cloud mode.
- [ ] Settings aren't persisted in the app (add `shared_preferences`).
