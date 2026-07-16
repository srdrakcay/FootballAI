import assert from "node:assert/strict";
import test from "node:test";
import { GeminiGateway, GeminiProviderError, geminiCompatibleSchema } from "../src/analysis/geminiGateway.js";

test("Gemini gateway sends secret in header and parses structured JSON", async () => {
  let receivedHeader = "";
  let receivedBody: Record<string, unknown> | undefined;
  const gateway = new GeminiGateway({
    apiKey: "secret-key",
    model: "gemini-3.5-flash",
    responseSchema: { type: "object", properties: { status: { const: "ready" } }, required: ["status"] },
    fetch: async (_input, init) => {
      receivedHeader = new Headers(init?.headers).get("x-goog-api-key") ?? "";
      receivedBody = JSON.parse(String(init?.body)) as Record<string, unknown>;
      return new Response(JSON.stringify({
        responseId: "provider-1",
        candidates: [{ content: { parts: [{ text: "{\"status\":\"ready\"}" }] } }],
        usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 20 },
      }), { status: 200, headers: { "content-type": "application/json" } });
    },
  });

  const result = await gateway.generate({
    modelAlias: "gemini-flash-default",
    promptVersion: "football-v2.1.0",
    schemaVersion: "2.0",
    snapshot: { fixture: "safe-data" },
    timeoutMs: 1_000,
    correlationId: "correlation",
  });

  assert.equal(receivedHeader, "secret-key");
  assert.equal(JSON.stringify(receivedBody).includes("secret-key"), false);
  assert.deepEqual(result.rawJson, { status: "ready" });
  assert.equal(result.inputTokens, 100);
  assert.equal(result.outputTokens, 20);
});

test("Gemini gateway classifies rate limiting as retryable", async () => {
  const gateway = new GeminiGateway({
    apiKey: "secret-key",
    model: "gemini-3.5-flash",
    responseSchema: { type: "object" },
    fetch: async () => new Response("rate limited", { status: 429 }),
  });
  await assert.rejects(
    () => gateway.generate({
      modelAlias: "gemini-flash-default",
      promptVersion: "football-v2.1.0",
      schemaVersion: "2.0",
      snapshot: {},
      timeoutMs: 1_000,
      correlationId: "correlation",
    }),
    (error: unknown) => error instanceof GeminiProviderError && error.retryable,
  );
});

test("Gemini schema conversion replaces unsupported const and validation keywords", () => {
  assert.deepEqual(geminiCompatibleSchema({
    $schema: "ignored",
    type: "object",
    properties: {
      status: { const: "ready", pattern: "ready", minLength: 1 },
    },
  }), {
    type: "object",
    properties: {
      status: { enum: ["ready"] },
    },
  });
});
