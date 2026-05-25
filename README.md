# RoomAlert

Temperature-monitoring system for the RoomAlert fleet, in one repo:

```
roomalert/
├── firmware/   ESP32 (Arduino) — reads 1–6 DS18B20 sensors, local web UI, OTA, cloud upload
├── cloud/      Cloudflare Worker + D1 — receives telemetry and serves it to the app
└── app/        Flutter app — views sensor data (Android / iOS / desktop / web)
```

## How the three pieces connect

```
 ┌──────────┐   POST telemetry    ┌──────────┐   GET /api/telemetry   ┌──────────┐
 │ firmware │ ──────────────────▶ │  cloud   │ ─────────────────────▶ │   app    │
 │ (ESP32)  │                     │ (Worker) │                        │ (Flutter)│
 └────┬─────┘                     └──────────┘                        └────┬─────┘
      │                                                                    │
      └────────── GET /api/status  (direct Wi-Fi, same LAN) ───────────────┘
```

The app has three data modes: **Simulated** (no hardware), **ESP32 Wi-Fi**
(direct LAN, reads the device's `/api/status`), and **Cloud** (reads the
Worker's `/api/telemetry`, works from anywhere).

## Shared data contract

A unit reports **1–6 sensor ports** (set by `NUM_SENSORS` in the firmware;
`maxSensors`/`MAX_PORTS` = 6 in the app and Worker). Disconnected ports use
`temp: null`, `conn: false`. Keep these JSON shapes in sync across all three
folders — see each folder's `AGENTS.md`.

## Quick start per piece

| Folder | Commands |
|--------|----------|
| `firmware/` | Open `mrichbiggerDevice.ino` in Arduino IDE → Verify → Upload |
| `cloud/` | `cd cloud && npm install && npm test && npx wrangler deploy` |
| `app/` | `cd app && flutter pub get && flutter analyze && flutter run -d chrome` |

## Wiring the cloud path end-to-end

1. `cd cloud && npx wrangler deploy` → note the printed Worker URL.
2. `npx wrangler d1 migrations apply roomalert_db --remote` (adds ports 3–6).
3. Put that URL + a `deviceId` in **both** `firmware/` (`CLOUD_URL`,
   `CLOUD_DEVICE_ID`) and the **app** (Settings → Cloud). They must match.
