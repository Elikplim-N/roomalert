#include "webpage.h" // Ensure this file is in the same folder
#include <Update.h>  // Built-in ESP32 OTA flash-writing helper
#include <DallasTemperature.h>
#include <ESPAsyncWebServer.h>
#include <HTTPClient.h>       // Outbound POST to the cloud receiver
#include <OneWire.h>
#include <RTClib.h>
#include <SD.h>
#include <SPI.h>
#include <WiFi.h>
#include <WiFiClientSecure.h> // HTTPS transport for the cloud receiver

// ---------------------------------------------------------------------------
// Device Configuration
// ---------------------------------------------------------------------------
// MAX_SENSORS is the hardware ceiling (this board has 6 physical ports).
// NUM_SENSORS is the active port count for THIS device variant — the only
// line to change to build a 2W/5W/6W unit. Must be between 1 and MAX_SENSORS.
#define MAX_SENSORS 6
#define NUM_SENSORS 5
static_assert(NUM_SENSORS >= 1 && NUM_SENSORS <= MAX_SENSORS,
              "NUM_SENSORS must be between 1 and MAX_SENSORS");

// ---------------------------------------------------------------------------
// Cloud Telemetry Configuration
// ---------------------------------------------------------------------------
// The device POSTs readings to the Cloudflare Worker receiver so the mobile
// app can view this unit remotely. Uploads only happen when connected to a
// router (STA mode); AP-only operation stays fully local. Leave CLOUD_URL
// empty to disable cloud uploads entirely.
#define CLOUD_URL "https://roomalert-receiver.elikplim-iot.workers.dev"                       // e.g. "https://roomalert-receiver.<acct>.workers.dev"
#define CLOUD_DEVICE_ID "roomAlert-5W"  // unique id for this unit in the cloud DB
#define CLOUD_UPLOAD_INTERVAL_MS 60000UL   // how often to push (default 60s)
#define FW_VERSION "1.0.0"
#define MODEL_NAME "roomAlert-5W"

String cloudUrl = CLOUD_URL;
String cloudDeviceId = CLOUD_DEVICE_ID;

void loadCloudConfig() {
    if (!SD.exists("/cloud.txt")) {
        File f = SD.open("/cloud.txt", FILE_WRITE);
        if (f) {
            f.println(cloudUrl);
            f.println(cloudDeviceId);
            f.close();
            Serial.println("[SD] Created /cloud.txt with defaults");
        }
        return;
    }
    File f = SD.open("/cloud.txt");
    if (f) {
        if (f.available()) cloudUrl = f.readStringUntil('\n');
        if (f.available()) cloudDeviceId = f.readStringUntil('\n');
        f.close();
        cloudUrl.trim();
        cloudDeviceId.trim();
        Serial.println("[SD] Loaded /cloud.txt cloud config");
    }
}

// ---------------------------------------------------------------------------
// Hardware Pin Definitions
// ---------------------------------------------------------------------------
const uint8_t SENSOR_PINS[MAX_SENSORS] = {13, 14, 27, 16, 4, 17};
#define RELAY_PIN 33              // moved from DAC pin 25 → plain GPIO 33
#define RELAY_ACTIVE_LOW true   // CONFIRMED: relay triggers on LOW (active-low board)
#define RELAY_ON  (RELAY_ACTIVE_LOW ? LOW  : HIGH)
#define RELAY_OFF (RELAY_ACTIVE_LOW ? HIGH : LOW)
#define BUZZER_PIN 32
#define SD_CS 5
const uint8_t LED_PINS[MAX_SENSORS] = {2, 3, 15, 26, 25, 12}; // Zone 1-6 LEDs (Zone 2 on RX0/3 since NO pin 0)

// ---------------------------------------------------------------------------
// Objects & State
// ---------------------------------------------------------------------------
const char *ssid = "RoomAlert";
const char *pass = "12345678";

AsyncWebServer server(80);
RTC_DS3231 rtc;
unsigned long buzzerOffTime = 0;

// Discrete OneWire instances, one per physical bus
OneWire oneWire_bus[MAX_SENSORS] = {OneWire(SENSOR_PINS[0]), OneWire(SENSOR_PINS[1]),
                          OneWire(SENSOR_PINS[2]), OneWire(SENSOR_PINS[3]),
                          OneWire(SENSOR_PINS[4]), OneWire(SENSOR_PINS[5])};
DallasTemperature sensors[MAX_SENSORS] = {
    DallasTemperature(&oneWire_bus[0]), DallasTemperature(&oneWire_bus[1]),
    DallasTemperature(&oneWire_bus[2]), DallasTemperature(&oneWire_bus[3]),
    DallasTemperature(&oneWire_bus[4]), DallasTemperature(&oneWire_bus[5])};

float currentTemps[MAX_SENSORS];
bool relayState = false;
float globalMaxTemp = 125.0;
float globalMinTemp = -55.0;
unsigned long lastBlink = 0;
bool blinkState = false;
char cachedTime[12] = "00:00:00";
String zoneNames[MAX_SENSORS] = {"Zone 1", "Zone 2", "Zone 3", "Zone 4", "Zone 5", "Zone 6"};
float sensorOffsets[MAX_SENSORS] = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0};

// ---------------------------------------------------------------------------
// SD Card Helpers
// ---------------------------------------------------------------------------
void saveZoneNames() {
    File f = SD.open("/names.txt", FILE_WRITE);
    if (f) {
        for (int i = 0; i < NUM_SENSORS; i++) { f.println(zoneNames[i]); }
        f.close();
    }
}
void loadZoneNames() {
    if (!SD.exists("/names.txt")) return;
    File f = SD.open("/names.txt");
    if (f) {
        for (int i = 0; i < NUM_SENSORS; i++) {
            if (f.available()) zoneNames[i] = f.readStringUntil('\n');
            zoneNames[i].trim();
        }
        f.close();
    }
}
void saveOffsets() {
    File f = SD.open("/offsets.txt", FILE_WRITE);
    if (f) {
        for (int i = 0; i < NUM_SENSORS; i++) { f.println(sensorOffsets[i], 2); }
        f.close();
    }
}
void loadOffsets() {
    if (!SD.exists("/offsets.txt")) return;
    File f = SD.open("/offsets.txt");
    if (f) {
        for (int i = 0; i < NUM_SENSORS; i++) {
            if (f.available()) {
                String line = f.readStringUntil('\n');
                line.trim();
                sensorOffsets[i] = line.toFloat();
            }
        }
        f.close();
    }
}

String savedWifiSsid = "";
String savedWifiPass = "";

void saveWifi(String s, String p) {
    File f = SD.open("/wifi.txt", FILE_WRITE);
    if (f) { f.println(s); f.println(p); f.close(); }
}
void loadWifi() {
    if (!SD.exists("/wifi.txt")) return;
    File f = SD.open("/wifi.txt");
    if (f) {
        if (f.available()) savedWifiSsid = f.readStringUntil('\n');
        if (f.available()) savedWifiPass = f.readStringUntil('\n');
        f.close();
        savedWifiSsid.trim();
        savedWifiPass.trim();
    }
}

// ---------------------------------------------------------------------------
// Async Logic: Handlers
// ---------------------------------------------------------------------------

// Helper: Basic Authentication Check
bool isAuthorized(AsyncWebServerRequest *request) {
  if (!request->authenticate("admin", "admin")) {
    request->requestAuthentication("Hub Admin Access");
    return false;
  }
  return true;
}

void setupServer() {
  // 1. Serve the Main UI
  server.on("/", HTTP_GET, [](AsyncWebServerRequest *request) {
    AsyncWebServerResponse *response = request->beginResponse_P(
        200, "text/html", (const uint8_t *)dashboard_html,
        sizeof(dashboard_html) - 1);
    request->send(response);
  });

  // 2. API Status Endpoint (JSON)
  server.on("/api/status", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (!isAuthorized(request))
      return;

    unsigned long uptimeSecs = millis() / 1000;

    // Add SD status
    uint64_t cardSize = SD.cardSize() / (1024 * 1024 * 1024); // GB
    uint64_t usedSpace = SD.usedBytes() / (1024 * 1024);      // MB
    uint64_t totalSpace = SD.totalBytes() / (1024 * 1024);    // MB
    int percentUsed = (totalSpace > 0) ? (usedSpace * 100) / totalSpace : 0;

    String json = "{";
    json += "\"deviceId\":\"" + cloudDeviceId + "\",";
    json += "\"mac\":\"" + WiFi.macAddress() + "\",";
    json += "\"fw\":\"" + String(FW_VERSION) + "\",";
    json += "\"model\":\"" + String(MODEL_NAME) + "\",";
    json += "\"time\":\"" + String(cachedTime) + "\",";
    json += "\"uptime\":" + String(uptimeSecs) + ",";
    json += "\"sd\":{\"cap\":" + String((unsigned long)cardSize) +
            ",\"used\":" + String(percentUsed) + "},";
    json += "\"relay\":" + String(relayState ? "true" : "false") + ",";
    json += "\"ip\":\"" + (WiFi.status() == WL_CONNECTED ? WiFi.localIP().toString() : WiFi.softAPIP().toString()) + "\",";
    json += "\"thresholds\":{\"max\":" + String(globalMaxTemp) + ",\"min\":" + String(globalMinTemp) + "},";
    json += "\"offsets\":[";
    for (int i = 0; i < NUM_SENSORS; i++) {
      json += String(sensorOffsets[i], 2);
      if (i < NUM_SENSORS - 1) json += ",";
    }
    json += "],";
    json += "\"ports\":[";
    for (int i = 0; i < NUM_SENSORS; i++) {
      bool conn = (currentTemps[i] > -100.0);
      json += "{\"id\":" + String(i + 1) + ",\"name\":\"" + zoneNames[i] + "\",\"temp\":" + String(conn ? currentTemps[i] : 0.0) + ",\"conn\":" + (conn ? "true" : "false") + "}";
      if (i < NUM_SENSORS - 1)
        json += ",";
    }
    json += "]}";
    request->send(200, "application/json", json);
  });

  // 3. Relay Control (reads ?state=1 or ?state=0)
  server.on("/api/relay", HTTP_POST, [](AsyncWebServerRequest *request) {
    Serial.println("[RELAY] Endpoint hit");
    if (!isAuthorized(request)) {
      Serial.println("[RELAY] AUTH FAILED");
      return;
    }
    Serial.println("[RELAY] Auth OK");
    if (request->hasParam("state")) {
      String val = request->getParam("state")->value();
      relayState = (val == "1");
      Serial.printf("[RELAY] state='%s' -> %s\n", val.c_str(), relayState ? "ON" : "OFF");
    } else {
      relayState = !relayState;
      Serial.printf("[RELAY] toggled -> %s\n", relayState ? "ON" : "OFF");
    }
    int pinVal = relayState ? RELAY_ON : RELAY_OFF;
    Serial.printf("[RELAY] pin %d = %s\n", RELAY_PIN, pinVal == LOW ? "LOW" : "HIGH");
    digitalWrite(RELAY_PIN, pinVal);
    String resp = "{\"status\":\"ok\",\"relay\":" +
                  String(relayState ? "true" : "false") + "}";
    request->send(200, "application/json", resp);
  });

  // 3.5 Buzzer Test
  server.on("/api/buzzer", HTTP_POST, [](AsyncWebServerRequest *request) {
    if (!isAuthorized(request))
      return;
    digitalWrite(BUZZER_PIN, HIGH);
    buzzerOffTime = millis() + 500; // Turn off non-blocking in loop after 500ms
    request->send(200, "application/json", "{\"status\":\"ok\"}");
  });

  // 3.6 Threshold Control
  server.on("/api/thresholds", HTTP_POST, [](AsyncWebServerRequest *request) {
    if (!isAuthorized(request)) return;
    if (request->hasParam("max")) globalMaxTemp = request->getParam("max")->value().toFloat();
    if (request->hasParam("min")) globalMinTemp = request->getParam("min")->value().toFloat();
    request->send(200, "application/json", "{\"status\":\"ok\"}");
  });

  // 3.7 Zone Rename (saves to SD card)
  server.on("/api/rename", HTTP_POST, [](AsyncWebServerRequest *request) {
    if (!isAuthorized(request)) return;
    if (request->hasParam("id") && request->hasParam("name")) {
        int idx = request->getParam("id")->value().toInt() - 1;
        if (idx >= 0 && idx < NUM_SENSORS) {
            zoneNames[idx] = request->getParam("name")->value();
            saveZoneNames();
        }
    }
    request->send(200, "application/json", "{\"status\":\"ok\"}");
  });

  // 3.8 Sensor Calibration Offset
  server.on("/api/offset", HTTP_POST, [](AsyncWebServerRequest *request) {
    if (!isAuthorized(request)) return;
    if (request->hasParam("id") && request->hasParam("val")) {
        int idx = request->getParam("id")->value().toInt() - 1;
        if (idx >= 0 && idx < NUM_SENSORS) {
            sensorOffsets[idx] = request->getParam("val")->value().toFloat();
            saveOffsets();
        }
    }
    request->send(200, "application/json", "{\"status\":\"ok\"}");
  });

  // 3.9 WiFi Config
  server.on("/api/wifi", HTTP_POST, [](AsyncWebServerRequest *request) {
    if (!isAuthorized(request)) return;
    if (request->hasParam("ssid") && request->hasParam("pass")) {
        String s = request->getParam("ssid")->value();
        String p = request->getParam("pass")->value();
        saveWifi(s, p);
        request->send(200, "application/json", "{\"status\":\"ok\"}");
        delay(500);
        ESP.restart(); // Reboot to apply Wi-Fi settings
    } else {
        request->send(400, "application/json", "{\"status\":\"error\"}");
    }
  });

  // 4. Catch-all for Auth
  server.on("/api/auth", HTTP_POST, [](AsyncWebServerRequest *request) {
    if (isAuthorized(request))
      request->send(200, "application/json", "{\"status\":\"ok\"}");
  });

  // 5. SD Clear
  server.on("/api/sd/clear", HTTP_POST, [](AsyncWebServerRequest *request) {
    if (!isAuthorized(request))
      return;
    SD.remove("/datalog.csv");
    request->send(200, "application/json", "{\"status\":\"ok\"}");
  });

  // 5.5 RTC Time Sync (JSON Body parses epoch)
  server.on("/api/sync_time", HTTP_POST, [](AsyncWebServerRequest *request) {
    // Handled in body callback below
  }, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    if (!isAuthorized(request)) return;
    String body = "";
    for (size_t i = 0; i < len; i++) {
      body += (char)data[i];
    }
    int idx = body.indexOf("\"unixtime\":");
    if (idx != -1) {
        int start = idx + 11;
        while (start < body.length() && (body[start] == ' ' || body[start] == ':')) {
            start++;
        }
        int end = start;
        while (end < body.length() && isDigit(body[end])) {
            end++;
        }
        String epochStr = body.substring(start, end);
        uint32_t epoch = epochStr.toInt();
        if (epoch > 0) {
            rtc.adjust(DateTime(epoch));
            Serial.println("[RTC] Clock synchronized successfully via API: " + epochStr);
            request->send(200, "application/json", "{\"status\":\"ok\"}");
            return;
        }
    }
    request->send(400, "application/json", "{\"status\":\"error\"}");
  });

  // 6. SD Download — Dynamically prepend header row with current zone names
  server.on("/api/sd/download", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (!isAuthorized(request))
      return;
    if (!SD.exists("/datalog.csv")) {
      request->send(404, "text/plain", "Log is empty or missing");
      return;
    }

    // Build header row using latest zone names
    String header = "Date,Time";
    for (int i = 0; i < NUM_SENSORS; i++) {
      header += "," + zoneNames[i] + " (°C)";
    }
    header += "\n";

    File dataFile = SD.open("/datalog.csv");
    if (!dataFile) {
      request->send(500, "text/plain", "Failed to open log file");
      return;
    }

    size_t fileSize = dataFile.size();
    size_t totalSize = header.length() + fileSize;
    dataFile.close();

    // Generate a timestamped filename for the download
    DateTime now = rtc.now();
    char dlName[40];
    sprintf(dlName, "RoomAlert_%04d-%02d-%02d.csv", now.year(), now.month(), now.day());

    AsyncWebServerResponse *response = request->beginResponse(
        "text/csv", totalSize,
        [header, fileSize](uint8_t *buffer, size_t maxLen, size_t index) -> size_t {
          size_t headerLen = header.length();
          size_t written = 0;

          // Serve header bytes first
          if (index < headerLen) {
            size_t toCopy = headerLen - index;
            if (toCopy > maxLen) toCopy = maxLen;
            memcpy(buffer, header.c_str() + index, toCopy);
            written += toCopy;
            maxLen -= toCopy;
          }

          // Then serve file bytes
          if (maxLen > 0 && index + written >= headerLen) {
            size_t fileOffset = (index + written) - headerLen;
            File f = SD.open("/datalog.csv");
            if (f) {
              f.seek(fileOffset);
              size_t toRead = (fileSize - fileOffset);
              if (toRead > maxLen) toRead = maxLen;
              written += f.read(buffer + written, toRead);
              f.close();
            }
          }
          return written;
        });
    String disposition = "attachment; filename=\"" + String(dlName) + "\"";
    response->addHeader("Content-Disposition", disposition);
    request->send(response);
  });

  // 7. Reboot
  server.on("/api/reboot", HTTP_POST, [](AsyncWebServerRequest *request) {
    if (!isAuthorized(request))
      return;
    request->send(200, "application/json", "{\"status\":\"rebooting\"}");
    delay(500); // yield briefly to allow network packet to send
    ESP.restart();
  });

  // 8. OTA Firmware Update — upload a compiled .bin and reflash over Wi-Fi.
  // Completion handler: runs after the whole upload, reports result, reboots.
  server.on(
      "/api/ota", HTTP_POST,
      [](AsyncWebServerRequest *request) {
        if (!isAuthorized(request))
          return;
        bool ok = !Update.hasError();
        AsyncWebServerResponse *response = request->beginResponse(
            200, "application/json",
            ok ? "{\"status\":\"ok\"}" : "{\"status\":\"error\"}");
        response->addHeader("Connection", "close");
        request->send(response);
        if (ok) {
          delay(500); // let the response flush before we reboot
          ESP.restart();
        }
      },
      // Upload handler: receives the .bin in chunks and streams it to flash.
      [](AsyncWebServerRequest *request, String filename, size_t index,
         uint8_t *data, size_t len, bool final) {
        if (!request->authenticate("admin", "admin"))
          return; // reject unauthenticated uploads before touching flash
        if (index == 0) {
          Serial.printf("[OTA] Starting update: %s\n", filename.c_str());
          if (!Update.begin(UPDATE_SIZE_UNKNOWN))
            Update.printError(Serial);
        }
        if (Update.write(data, len) != len)
          Update.printError(Serial);
        if (final) {
          if (Update.end(true))
            Serial.printf("[OTA] Success: %u bytes. Rebooting.\n",
                          index + len);
          else
            Update.printError(Serial);
        }
      });

  // Catch preflights and 404s cleanly to prevent Internal Errors
  server.onNotFound([](AsyncWebServerRequest *request) {
    if (request->method() == HTTP_OPTIONS) {
      request->send(200);
    } else {
      request->send(404, "text/plain", "Not found");
    }
  });

  server.begin();
}

// ---------------------------------------------------------------------------
// Cloud Upload
// ---------------------------------------------------------------------------
// Build the telemetry payload and POST it to the Worker. Disconnected ports
// report temp:null/conn:false so the cloud mirrors exactly NUM_SENSORS ports.
void uploadToCloud() {
  if (cloudUrl.length() == 0) return;        // cloud disabled
  if (WiFi.status() != WL_CONNECTED) return; // no upstream link (AP-only)

  DateTime now = rtc.now();
  char isoTime[25];
  sprintf(isoTime, "%04d-%02d-%02dT%02d:%02d:%02dZ", now.year(), now.month(),
          now.day(), now.hour(), now.minute(), now.second());

  String payload = "{\"deviceId\":\"" + cloudDeviceId + "\",\"timestamp\":\"";
  payload += isoTime;
  payload += "\",\"sensors\":[";
  for (int i = 0; i < NUM_SENSORS; i++) {
    bool conn = (currentTemps[i] > -100.0);
    payload += "{\"temp\":";
    payload += conn ? String(currentTemps[i], 2) : "null";
    payload += ",\"conn\":";
    payload += conn ? "true" : "false";
    payload += "}";
    if (i < NUM_SENSORS - 1) payload += ",";
  }
  payload += "]}";

  WiFiClientSecure client;
  client.setInsecure(); // skip cert pinning; payload is non-sensitive telemetry
  HTTPClient http;
  if (http.begin(client, cloudUrl)) {
    http.addHeader("Content-Type", "application/json");
    int code = http.POST(payload);
    Serial.printf("[CLOUD] POST -> %d\n", code);
    http.end();
  } else {
    Serial.println("[CLOUD] begin() failed");
  }
}

// ---------------------------------------------------------------------------
// Core Loops
// ---------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(2000); // CRITICAL: Let power rails and capacitors charge up
  Serial.println("\n--- [System Booting] ---");

  // 0. Initialize Sensors & Outputs
  for (int i = 0; i < NUM_SENSORS; i++) {
    sensors[i].begin();
    sensors[i].setWaitForConversion(false); // Non-blocking!
    sensors[i].requestTemperatures();       // Start the first 750ms conversion
    currentTemps[i] = -127.0;               // Assume disconnected at boot
  }
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, RELAY_OFF); // Start relay OFF (respects active-low/high)
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, HIGH);
  delay(200);
  digitalWrite(BUZZER_PIN, LOW);
  for (int i = 0; i < NUM_SENSORS; i++) {
    pinMode(LED_PINS[i], OUTPUT);
    digitalWrite(LED_PINS[i], LOW);
  }

  // 1. Initialize I2C (RTC) - DO THIS FIRST while power is cleanest
  Wire.begin(21, 22);
  delay(100);
  if (!rtc.begin()) {
    Serial.println("!!! RTC Fail - Check pins 21/22 and 3.3V");
  } else {
    Serial.println("RTC: Online.");
  }

  // 2. Initialize SPI (SD) - Do this before turning on the "Noisy" WiFi
  if (!SD.begin(SD_CS)) {
    Serial.println("!!! SD Fail - Check CS Pin 5 and Card Voltage");
  } else {
    Serial.println("SD Card: Online.");
    loadZoneNames();   // Restore custom zone names from SD
    loadOffsets();     // Restore sensor calibration offsets from SD
    loadWifi();        // Restore router Wi-Fi credentials from SD
    loadCloudConfig(); // Restore cloud configuration from SD
  }

  // 3. Setup WiFi Mode (AP + Station fallback logic)
  if (savedWifiSsid.length() > 0) {
      WiFi.mode(WIFI_AP_STA);
      WiFi.begin(savedWifiSsid.c_str(), savedWifiPass.c_str());
      unsigned long startM = millis();
      Serial.print("Connecting to router: ");
      Serial.print(savedWifiSsid);
      while (WiFi.status() != WL_CONNECTED && millis() - startM < 8000) {
          delay(500);
          Serial.print(".");
      }
      Serial.println();
      if(WiFi.status() == WL_CONNECTED) {
          Serial.print("Router Connected! Local IP: ");
          Serial.println(WiFi.localIP());
      } else {
          Serial.println("Router Connection Failed. Falling back to AP Mode only.");
          WiFi.mode(WIFI_AP);
      }
  } else {
      WiFi.mode(WIFI_AP);
  }
  delay(100);

  // 4. Start SoftAP (Always active so you never lose control)
  if (WiFi.softAP(ssid, pass)) {
    Serial.println("Access Point: Active");
  }

  // 5. THE "TCP LOCK" FIX
  // We wait a full second to let the LWIP (network) stack stabilize
  // before we let AsyncWebServer touch it.
  Serial.println("Waiting for network stack lock...");
  delay(1500);

  // 6. Start Server
  setupServer();
  Serial.println("--- [System Ready] ---");
  Serial.print("AP IP:     "); Serial.println(WiFi.softAPIP());
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("Router IP: "); Serial.println(WiFi.localIP());
  }
}

void loop() {
  static unsigned long lastUpdate = 0;
  static unsigned long lastLog = 0;
  static unsigned long lastCloud = 0;

  // Update Sensors every 2 seconds (Non-blocking & Hot-swappable)
  if (millis() - lastUpdate > 2000) {
    for (int i = 0; i < NUM_SENSORS; i++) {
      // 1. Read the conversion requested 2 seconds ago
      float t = sensors[i].getTempCByIndex(0);
      currentTemps[i] = (t == DEVICE_DISCONNECTED_C) ? -127.0 : (t + sensorOffsets[i]);

      // 2. Re-scan bus to detect newly plugged/unplugged sensors (Hot-swap!)
      sensors[i].begin();
      sensors[i].setWaitForConversion(
          false); // begin() resets this to true, so we MUST disable it again

      // 3. Request the NEXT conversion (takes 750ms in the background)
      sensors[i].requestTemperatures();
    }

    DateTime now = rtc.now();
    sprintf(cachedTime, "%02d:%02d:%02d", now.hour(), now.minute(),
            now.second());
    lastUpdate = millis();
  }

  // Update LED indicators (non-blocking, 500ms blink for out of bounds)
  if (millis() - lastBlink > 500) {
    blinkState = !blinkState;
    lastBlink  = millis();
  }
  for (int i = 0; i < NUM_SENSORS; i++) {
    if (currentTemps[i] <= -100.0) {
      digitalWrite(LED_PINS[i], LOW); // Disconnected = OFF
    } else if (currentTemps[i] > globalMaxTemp || currentTemps[i] < globalMinTemp) {
      digitalWrite(LED_PINS[i], blinkState ? HIGH : LOW); // Out of bounds = FLASH
    } else {
      digitalWrite(LED_PINS[i], HIGH); // Normal = ON
    }
  }

  // Handle Buzzer non-blocking timeout
  if (buzzerOffTime > 0 && millis() > buzzerOffTime) {
    digitalWrite(BUZZER_PIN, LOW);
    buzzerOffTime = 0;
  }

  // Log to SD every 30 seconds
  if (millis() - lastLog > 30000) {
    File dataFile = SD.open("/datalog.csv", FILE_APPEND);
    if (dataFile) {
      // Write date + time
      DateTime now = rtc.now();
      char dateBuf[12];
      sprintf(dateBuf, "%04d-%02d-%02d", now.year(), now.month(), now.day());
      dataFile.print(dateBuf);
      dataFile.print(",");
      dataFile.print(cachedTime);
      // Write temperature values (empty cell if sensor disconnected)
      for (int i = 0; i < NUM_SENSORS; i++) {
        dataFile.print(",");
        if (currentTemps[i] > -100.0) {
          dataFile.print(currentTemps[i], 1);
        }
        // else: leave cell empty for disconnected sensor
      }
      dataFile.println();
      dataFile.close();
    }
    lastLog = millis();
  }

  // Push telemetry to the cloud receiver on its own interval (no-op if
  // CLOUD_URL is empty or we're not connected to a router).
  if (millis() - lastCloud > CLOUD_UPLOAD_INTERVAL_MS) {
    uploadToCloud();
    lastCloud = millis();
  }
}

