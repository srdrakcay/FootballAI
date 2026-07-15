import assert from "node:assert/strict";
import test from "node:test";
import { assertTransition } from "../src/analysis/stateMachine.js";

test("state machine accepts canonical progress", () => {
  assert.doesNotThrow(() => assertTransition("queued", "generating"));
  assert.doesNotThrow(() => assertTransition("generating", "validating"));
  assert.doesNotThrow(() => assertTransition("validating", "ready"));
});

test("client-like jump to ready is rejected", () => {
  assert.throws(() => assertTransition("not_started", "ready"));
});
