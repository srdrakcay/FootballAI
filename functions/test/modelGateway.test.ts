import assert from "node:assert/strict";
import test from "node:test";
import { AllowlistedModelAliasResolver } from "../src/analysis/modelGateway.js";

test("model names are resolved only through server allowlist", () => {
  const resolver = new AllowlistedModelAliasResolver({ "gemini-flash-default": { provider: "google", model: "gemini-3.5-flash" } });
  assert.equal(resolver.resolve("gemini-flash-default").model, "gemini-3.5-flash");
  assert.throws(() => resolver.resolve("client-selected-model"));
});
