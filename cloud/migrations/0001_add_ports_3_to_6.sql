-- Add sensor ports 3..6 to an existing telemetry_logs table that originally
-- only stored ports 1 and 2. Safe to run once against the live D1 database:
--   npx wrangler d1 execute roomalert_db --remote --file=migrations/0001_add_ports_3_to_6.sql
ALTER TABLE telemetry_logs ADD COLUMN port_3_temp REAL;
ALTER TABLE telemetry_logs ADD COLUMN port_3_conn INTEGER;
ALTER TABLE telemetry_logs ADD COLUMN port_4_temp REAL;
ALTER TABLE telemetry_logs ADD COLUMN port_4_conn INTEGER;
ALTER TABLE telemetry_logs ADD COLUMN port_5_temp REAL;
ALTER TABLE telemetry_logs ADD COLUMN port_5_conn INTEGER;
ALTER TABLE telemetry_logs ADD COLUMN port_6_temp REAL;
ALTER TABLE telemetry_logs ADD COLUMN port_6_conn INTEGER;
