import { env, createExecutionContext, waitOnExecutionContext } from "cloudflare:test";
import { describe, it, expect, beforeAll } from "vitest";
import worker from "../src/index";

const IncomingRequest = Request<unknown, IncomingRequestCfProperties>;

beforeAll(async () => {
	await env.DB.exec(
		"CREATE TABLE IF NOT EXISTS telemetry_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, device_id TEXT NOT NULL, timestamp DATETIME NOT NULL, port_1_temp REAL, port_1_conn INTEGER, port_2_temp REAL, port_2_conn INTEGER, port_3_temp REAL, port_3_conn INTEGER, port_4_temp REAL, port_4_conn INTEGER, port_5_temp REAL, port_5_conn INTEGER, port_6_temp REAL, port_6_conn INTEGER, created_at DATETIME DEFAULT CURRENT_TIMESTAMP);",
	);
});

function postTelemetry(body: unknown) {
	return new IncomingRequest("http://example.com", {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify(body),
	});
}

describe("telemetry receiver", () => {
	it("rejects non-POST requests with 405", async () => {
		const request = new IncomingRequest("http://example.com");
		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		await waitOnExecutionContext(ctx);
		expect(response.status).toBe(405);
	});

	it("stores all six sensor ports from a 6W device", async () => {
		const sensors = Array.from({ length: 6 }, (_, i) => ({
			temp: 20 + i,
			conn: true,
		}));
		const request = postTelemetry({
			deviceId: "dev-6w",
			timestamp: "2026-05-25T00:00:00Z",
			sensors,
		});
		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		await waitOnExecutionContext(ctx);
		expect(response.status).toBe(200);

		const row = await env.DB.prepare(
			"SELECT * FROM telemetry_logs WHERE device_id = ?",
		)
			.bind("dev-6w")
			.first();
		expect(row?.port_1_temp).toBe(20);
		expect(row?.port_6_temp).toBe(25);
		expect(row?.port_6_conn).toBe(1);
	});

	it("leaves unreported ports null/disconnected for a 5W device", async () => {
		const sensors = Array.from({ length: 5 }, (_, i) => ({
			temp: 10 + i,
			conn: true,
		}));
		const request = postTelemetry({
			deviceId: "dev-5w",
			timestamp: "2026-05-25T00:01:00Z",
			sensors,
		});
		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		await waitOnExecutionContext(ctx);
		expect(response.status).toBe(200);

		const row = await env.DB.prepare(
			"SELECT * FROM telemetry_logs WHERE device_id = ?",
		)
			.bind("dev-5w")
			.first();
		expect(row?.port_5_temp).toBe(14);
		expect(row?.port_6_temp).toBeNull();
		expect(row?.port_6_conn).toBe(0);
	});
});

describe("telemetry read endpoint", () => {
	// Per-test storage is isolated, so each test seeds its own rows.
	async function ingest(body: unknown) {
		const ctx = createExecutionContext();
		await worker.fetch(postTelemetry(body), env, ctx);
		await waitOnExecutionContext(ctx);
	}

	async function get(path: string) {
		const request = new IncomingRequest(`http://example.com${path}`);
		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		await waitOnExecutionContext(ctx);
		return response;
	}

	it("returns readings filtered by deviceId in the device's posted shape", async () => {
		await ingest({
			deviceId: "read-6w",
			timestamp: "2026-05-25T00:00:00Z",
			sensors: Array.from({ length: 6 }, (_, i) => ({ temp: 20 + i, conn: true })),
		});

		const response = await get("/api/telemetry?deviceId=read-6w");
		expect(response.status).toBe(200);

		const body = (await response.json()) as {
			deviceId: string;
			count: number;
			readings: Array<{
				deviceId: string;
				sensors: Array<{ port: number; temp: number | null; conn: boolean }>;
			}>;
		};
		expect(body.deviceId).toBe("read-6w");
		expect(body.count).toBe(1);

		const reading = body.readings[0];
		expect(reading.deviceId).toBe("read-6w");
		expect(reading.sensors).toHaveLength(6);
		expect(reading.sensors[0]).toEqual({ port: 1, temp: 20, conn: true });
		expect(reading.sensors[5]).toEqual({ port: 6, temp: 25, conn: true });
	});

	it("reflects disconnected ports as null temp / conn false", async () => {
		await ingest({
			deviceId: "read-5w",
			timestamp: "2026-05-25T00:01:00Z",
			sensors: Array.from({ length: 5 }, (_, i) => ({ temp: 10 + i, conn: true })),
		});

		const response = await get("/api/telemetry?deviceId=read-5w");
		const body = (await response.json()) as {
			readings: Array<{
				sensors: Array<{ port: number; temp: number | null; conn: boolean }>;
			}>;
		};
		const reading = body.readings[0];
		expect(reading.sensors[4]).toEqual({ port: 5, temp: 14, conn: true });
		expect(reading.sensors[5]).toEqual({ port: 6, temp: null, conn: false });
	});

	it("returns newest readings first and honours the limit parameter", async () => {
		await ingest({ deviceId: "read-lim", timestamp: "2026-05-25T01:00:00Z", sensors: [{ temp: 1, conn: true }] });
		await ingest({ deviceId: "read-lim", timestamp: "2026-05-25T02:00:00Z", sensors: [{ temp: 2, conn: true }] });

		const response = await get("/api/telemetry?deviceId=read-lim&limit=1");
		const body = (await response.json()) as {
			count: number;
			readings: Array<{ timestamp: string }>;
		};
		expect(body.count).toBe(1);
		expect(body.readings[0].timestamp).toBe("2026-05-25T02:00:00Z");
	});
});
