# roomAlert-6W — agent handoff

ESP32 (Arduino) firmware for the **RoomAlert** monitor: reads 1–6 DS18B20
temperature sensors, drives a relay + buzzer, serves a local web dashboard,
logs to SD, supports OTA, and uploads telemetry to the cloud.

## The fleet (3 repos)

| Repo | Role |
|------|------|
| **roomAlert-6W** (this) | ESP32 firmware |
| **RT-Sense** | Flutter app (views data) |
| **roomalert-2W-mini** | Cloudflare Worker + D1 (telemetry ingest + read) |

Active branch for in-progress work: **`claude/adoring-mccarthy-7AfQ0`**.

## Build / flash (Arduino IDE — no CLI in this repo)

- Board: **ESP32 Dev Module** (install "esp32 by Espressif").
- Libraries: `DallasTemperature`, `OneWire`, `RTClib`, `ESPAsyncWebServer`,
  `ArduinoJson`. `Update`, `WiFi`, `HTTPClient`, `WiFiClientSecure`, `SD`, `SPI`
  are built into the ESP32 core.
- Keep `webpage.h` next to `mrichbiggerDevice.ino`.
- **Verify (compile)** before flashing. There is no way to compile this in a
  cloud agent env — it must be done in the IDE on a real machine.

## Key config (top of `mrichbiggerDevice.ino`)

```cpp
#define NUM_SENSORS 6        // active ports for THIS variant (1..MAX_SENSORS=6)
#define CLOUD_URL ""         // Worker URL; empty = cloud upload disabled
#define CLOUD_DEVICE_ID "roomalert-6w-01"
#define CLOUD_UPLOAD_INTERVAL_MS 60000UL
```
Change `NUM_SENSORS` (only) to build a 2W/5W/6W unit.

## Hardware (locked in)

- Sensors: DS18B20, one per GPIO — pins `{13, 14, 27, 16, 17, 4}`, 2.2 kΩ pull-ups,
  twisted-pair + external 3-wire power (not parasitic).
- Relay GPIO 33 (active-low), buzzer GPIO 32. Everything runs at 3.3 V
  (ESP32 is NOT 5V-tolerant); 5 V rail feeds VIN + relay/buzzer.
- LEDs on `{2, 3, 15, 26, 25, 12}` — note 2/3/12 are strapping/UART pins
  (works, but not ideal for a final board revision).

## API surface (served locally; all `/api/*` use Basic Auth `admin`/`admin`)

`GET /api/status` → `{ time, uptime, sd, relay, ip, thresholds, offsets, ports:[...] }`
where `ports[i] = { id, name, temp, conn }`. The app's Wi-Fi mode reads this.
Other endpoints: `/api/relay`, `/api/buzzer`, `/api/thresholds`, `/api/rename`,
`/api/offset`, `/api/wifi`, `/api/sd/download`, `/api/sd/clear`, `/api/reboot`,
`/api/ota`.

## Cloud upload (data contract — keep in sync with the Worker)

`uploadToCloud()` POSTs to `CLOUD_URL` when connected to a router (STA):
```json
{ "deviceId": "...", "timestamp": "ISO8601",
  "sensors": [ { "temp": 23.5, "conn": true }, ... ] }
```
Disconnected ports send `temp: null, conn: false`. Only `NUM_SENSORS` ports
are sent. AP-only operation stays fully local (no upload).

## Open / next steps

- [ ] Compile in Arduino IDE — the cloud-upload code (and earlier OTA code)
      were written without a compiler available here.
- [ ] Set a real `CLOUD_URL` (the deployed Worker) before relying on cloud.
- [ ] Flash and test on real hardware.
- [ ] Consider moving `CLOUD_URL`/`deviceId` to SD config (like Wi-Fi creds)
      so they're field-configurable without recompiling.
