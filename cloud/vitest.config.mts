import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";

export default defineWorkersConfig({
	test: {
		poolOptions: {
			workers: {
				// Use a test-only wrangler config so the suite runs against a local
				// in-memory D1 instead of the remote production database declared in
				// wrangler.jsonc.
				wrangler: { configPath: "./wrangler.test.jsonc" },
			},
		},
	},
});
