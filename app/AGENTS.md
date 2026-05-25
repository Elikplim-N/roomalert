# RT-Sense (T-Sense app) — agent handoff

Flutter dashboard app for the **RoomAlert** temperature-monitoring fleet.
One Dart codebase targets Android, iOS, desktop, and web.

> This repo was consolidated onto Flutter. The old React/Vite/Tauri/Capacitor
> stack and a redundant single-sensor `esp32_gateway.ino` were **deleted** —
> do not reintroduce them.

## The fleet (3 repos)

| Repo | Role |
|------|------|
| **RT-Sense** (this) | Flutter app — views sensor data |
| **roomAlert-6W** | ESP32 firmware — reads 1–6 DS18B20 sensors, serves local API, uploads to cloud |
| **roomalert-2W-mini** | Cloudflare Worker + D1 — receives & serves telemetry |

Active branch for in-progress work: **`claude/adoring-mccarthy-7AfQ0`**.

## How the app gets data (3 modes, see `lib/gateway_provider.dart`)

1. **Simulated** — fake values, no hardware. Choose 1–6 ports.
2. **ESP32 Wi-Fi** — `GET http://<device-ip>/api/status` with HTTP Basic Auth
   (default `admin`/`admin`). Parses the `ports[]` array.
3. **Cloud** — `GET <workerUrl>/api/telemetry?deviceId=<id>&limit=50`.

## Data contract (DO NOT break — shared across all 3 repos)

Device local API `GET /api/status` returns (among other fields):
```json
{ "ports": [ { "id": 1, "name": "Zone 1", "temp": 23.5, "conn": true } ] }
```

Worker read API `GET /api/telemetry?deviceId=X` returns:
```json
{ "deviceId": "X", "count": 1,
  "readings": [
    { "timestamp": "...", "sensors": [ { "port": 1, "temp": 23.5, "conn": true } ] }
  ] }
```
`temp` is `null` and `conn` is `false` for a disconnected port. A unit reports
1–6 ports (the firmware `NUM_SENSORS` constant). `maxSensors = 6` everywhere.

## Layout

- `lib/gateway_provider.dart` — state + the 3 connection/polling modes.
- `lib/main.dart` — UI: sensor grid, per-zone trend chart, settings modal.

## Commands

```sh
flutter pub get        # install deps
flutter analyze        # static analysis — RUN THIS (was not run in the cloud env)
flutter run -d chrome  # run in browser (or -d <device>)
flutter test           # if/when tests are added (none yet)
```

## Open / next steps

- [ ] Run `flutter analyze` and fix anything — code was written without a local
      Flutter toolchain available, so it has not been analyzer-verified.
- [ ] Manually test each mode: Simulated (no setup), then Wi-Fi, then Cloud.
- [ ] Cloud mode needs the Worker deployed and the device uploading — set the
      same Worker URL + `deviceId` here and in the firmware.
- [ ] No automated tests yet — consider widget tests for the provider parsing.
- [ ] Settings are not persisted across launches (add `shared_preferences`).
