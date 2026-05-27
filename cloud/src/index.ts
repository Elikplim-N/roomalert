export interface Env {
  DB: D1Database;
}

// Hardware ceiling: a device may report up to this many sensor ports.
const MAX_PORTS = 6;

// Read endpoint guardrails.
const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 500;

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

interface SensorReading {
  temp?: number | null;
  conn?: boolean;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

// Turn one stored row back into the { sensors: [...] } shape devices post.
function rowToReading(row: Record<string, unknown>) {
  const sensors = [];
  for (let i = 1; i <= MAX_PORTS; i++) {
    sensors.push({
      port: i,
      temp: (row[`port_${i}_temp`] as number | null) ?? null,
      conn: row[`port_${i}_conn`] === 1,
    });
  }
  return {
    id: row.id,
    deviceId: row.device_id,
    timestamp: row.timestamp,
    createdAt: row.created_at,
    sensors,
  };
}

async function handleIngest(request: Request, env: Env): Promise<Response> {
  // Parse the JSON payload from the RoomAlert device
  const data = (await request.json()) as {
    deviceId?: string;
    timestamp?: string;
    sensors?: SensorReading[];
  };

  const deviceId = data.deviceId || 'unknown';
  const timestamp = data.timestamp || new Date().toISOString();
  const sensors = Array.isArray(data.sensors) ? data.sensors : [];

  // Build the column/value lists for ports 1..MAX_PORTS. A device that
  // reports fewer ports (e.g. a 2W or 5W unit) simply leaves the extra
  // ports null/disconnected.
  const columns: string[] = ['device_id', 'timestamp'];
  const values: (string | number | null)[] = [deviceId, timestamp];

  for (let i = 0; i < MAX_PORTS; i++) {
    const reading = sensors[i] ?? null;
    const rawTemp = reading ? reading.temp : null;
    const temp =
      rawTemp == null || !Number.isFinite(Number(rawTemp))
        ? null
        : Number(rawTemp);
    columns.push(`port_${i + 1}_temp`, `port_${i + 1}_conn`);
    values.push(temp, reading && reading.conn ? 1 : 0);
  }

  const placeholders = columns.map(() => '?').join(', ');
  const stmt = env.DB.prepare(
    `INSERT INTO telemetry_logs (${columns.join(', ')}) VALUES (${placeholders})`,
  );

  await stmt.bind(...values).run();

  return json({ success: true });
}

// GET /api/telemetry?deviceId=<id>&limit=<n>
// Returns the most recent readings (newest first) for the dashboard app.
async function handleRead(url: URL, env: Env): Promise<Response> {
  const deviceId = url.searchParams.get('deviceId');

  const rawLimit = parseInt(url.searchParams.get('limit') ?? '', 10);
  const limit = Number.isFinite(rawLimit)
    ? Math.min(Math.max(rawLimit, 1), MAX_LIMIT)
    : DEFAULT_LIMIT;

  const stmt = deviceId
    ? env.DB.prepare(
        'SELECT * FROM telemetry_logs WHERE device_id = ? ORDER BY id DESC LIMIT ?',
      ).bind(deviceId, limit)
    : env.DB.prepare(
        'SELECT * FROM telemetry_logs ORDER BY id DESC LIMIT ?',
      ).bind(limit);

  const { results } = await stmt.all<Record<string, unknown>>();
  const readings = (results ?? []).map(rowToReading);

  return json({ deviceId: deviceId ?? null, count: readings.length, readings });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    try {
      // Reads: dashboard app pulls recent telemetry.
      if (request.method === 'GET' && url.pathname === '/api/telemetry') {
        return await handleRead(url, env);
      }

      // Ingest: devices POST telemetry (path-agnostic for firmware compatibility).
      if (request.method === 'POST') {
        return await handleIngest(request, env);
      }

      return new Response('Method Not Allowed', {
        status: 405,
        headers: CORS_HEADERS,
      });
    } catch (error) {
      console.error(error);
      return json({ error: 'Failed to process request' }, 500);
    }
  },
};
