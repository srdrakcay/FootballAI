import assert from "node:assert/strict";
import test from "node:test";
import { FootballDataClient, FootballDataProviderError, parseFootballDataRateLimit } from "../src/fixtures/footballDataClient.js";

test("sends the server secret only as X-Auth-Token and parses quota headers", async () => {
  let observedHeader: string | null = null;
  const client = new FootballDataClient({
    token: "server-secret",
    maximumAttempts: 1,
    fetch: async (_input, init) => {
      observedHeader = new Headers(init?.headers).get("X-Auth-Token");
      return new Response(JSON.stringify({ matches: [] }), {
        status: 200,
        headers: { "Content-Type": "application/json", "X-Requests-Available-Minute": "9", "X-RequestCounter-Reset": "21" },
      });
    },
  });

  const response = await client.getCompetitionMatches<{ matches: unknown[] }>("pl", { status: "SCHEDULED" });
  assert.equal(observedHeader, "server-secret");
  assert.deepEqual(response.data, { matches: [] });
  assert.equal(response.rateLimit.remainingThisMinute, 9);
  assert.equal(response.rateLimit.resetAfterSeconds, 21);
});

test("automatically waits for the reset window after quota reaches zero", async () => {
  let requests = 0;
  const delays: number[] = [];
  let now = 1_000;
  const client = new FootballDataClient({
    token: "server-secret",
    maximumAttempts: 1,
    now: () => now,
    sleep: async (milliseconds) => { delays.push(milliseconds); now += milliseconds; },
    fetch: async () => {
      requests += 1;
      return new Response("{}", { status: 200, headers: requests === 1 ? { "X-Requests-Available-Minute": "0", "X-RequestCounter-Reset": "7" } : {} });
    },
  });

  await client.getMatch(1);
  await client.getMatch(2);
  assert.deepEqual(delays, [7_000]);
});

test("retries 429 after Retry-After without exposing provider response bodies", async () => {
  let requests = 0;
  const delays: number[] = [];
  let now = 0;
  const client = new FootballDataClient({
    token: "server-secret",
    now: () => now,
    sleep: async (milliseconds) => { delays.push(milliseconds); now += milliseconds; },
    fetch: async () => {
      requests += 1;
      if (requests === 1) return new Response("sensitive provider message", { status: 429, headers: { "Retry-After": "2" } });
      return new Response("{}", { status: 200 });
    },
  });

  await client.getMatch(1);
  assert.equal(requests, 2);
  assert.deepEqual(delays, [2_000]);
});

test("fails closed for non-retryable provider errors", async () => {
  const client = new FootballDataClient({ token: "server-secret", fetch: async () => new Response("forbidden detail", { status: 403 }) });
  await assert.rejects(client.getMatch(1), (error: unknown) => {
    assert.ok(error instanceof FootballDataProviderError);
    assert.equal(error.status, 403);
    assert.equal(error.message, "FOOTBALL_PROVIDER_UNAVAILABLE");
    assert.equal(error.message.includes("forbidden"), false);
    return true;
  });
});

test("parses malformed rate headers as unavailable", () => {
  assert.deepEqual(parseFootballDataRateLimit(new Headers({ "X-Requests-Available-Minute": "unknown" })), {
    remainingThisMinute: null,
    resetAfterSeconds: null,
    retryAfterSeconds: null,
  });
});
