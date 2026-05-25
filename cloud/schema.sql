CREATE TABLE IF NOT EXISTS telemetry_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  timestamp DATETIME NOT NULL,
  port_1_temp REAL,
  port_1_conn INTEGER,
  port_2_temp REAL,
  port_2_conn INTEGER,
  port_3_temp REAL,
  port_3_conn INTEGER,
  port_4_temp REAL,
  port_4_conn INTEGER,
  port_5_temp REAL,
  port_5_conn INTEGER,
  port_6_temp REAL,
  port_6_conn INTEGER,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_device_time ON telemetry_logs (device_id, timestamp);
