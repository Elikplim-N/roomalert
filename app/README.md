# T-Sense

Flutter dashboard app for the RoomAlert temperature monitoring fleet
(Android, iOS, desktop, web from one codebase).

## Data sources

The app reads from a device in one of three modes (Settings → Connection):

- **Simulated** — fake wandering values, no hardware. Pick 1–6 ports.
- **ESP32 Wi-Fi** — direct LAN poll of the device's `GET /api/status`
  (HTTP Basic Auth, default `admin`/`admin`). Use the device IP (SoftAP
  default `192.168.4.1`).
- **Cloud** — polls the Cloudflare Worker receiver's
  `GET /api/telemetry?deviceId=<id>` read endpoint, for remote/off-LAN
  viewing. Set the Worker URL and the device's id.

All modes surface 1–6 sensor ports, matching the firmware's `NUM_SENSORS`
build constant. Tap a sensor card to chart that zone's trend.

## Related repos

- `roomAlert-6W` — ESP32 firmware (local `/api/status`, cloud upload).
- `roomalert-2W-mini` — Cloudflare Worker + D1 (telemetry ingest + read).

## Run

```sh
flutter pub get
flutter run            # or: flutter run -d chrome
```
