import assert from "node:assert/strict";
import test from "node:test";
import { InMemoryAnalysisCoordinator } from "../src/quota/coordinator.js";

const now = new Date("2026-07-15T12:00:00Z");
const command = (uid: string, clientRequestId: string, version = "version-A") => ({
  uid, clientRequestId, analysisVersionId: version, periodUTC: "2026-07",
  plan: "free" as const, freeLimit: 3, now,
});

test("100 concurrent callers join one deterministic request and one user ledger entry", async () => {
  const coordinator = new InMemoryAnalysisCoordinator();
  const results = await Promise.all(Array.from({ length: 100 }, (_, index) => coordinator.reserveOrJoin(command("user-1", `client-${index}`))));
  assert.equal(new Set(results.map((result) => result.requestId)).size, 1);
  assert.equal(coordinator.usage("user-1", "2026-07").length, 1);

  const leases = await Promise.all(Array.from({ length: 100 }, (_, index) => coordinator.acquireLease("version-A", `worker-${index}`, now, 90)));
  assert.equal(leases.filter((lease) => lease.acquired).length, 1);
});

test("cache identity does not affect unique-view quota and reopen is free", async () => {
  const coordinator = new InMemoryAnalysisCoordinator();
  await coordinator.reserveOrJoin(command("user-1", "first"));
  await coordinator.reserveOrJoin(command("user-1", "reopen"));
  assert.deepEqual(coordinator.usage("user-1", "2026-07"), [{ analysisVersionId: "version-A", state: "reserved" }]);
});

test("quota is released on permanent failure", async () => {
  const coordinator = new InMemoryAnalysisCoordinator();
  await coordinator.reserveOrJoin(command("user-1", "first"));
  const lease = await coordinator.acquireLease("version-A", "worker", now, 90);
  await coordinator.failPermanent("version-A", "worker", lease.leaseEpoch!, new Date(now.getTime() + 1_000));
  assert.equal(coordinator.usage("user-1", "2026-07")[0]?.state, "released");
});

test("expired lease is recovered and late worker cannot overwrite", async () => {
  const coordinator = new InMemoryAnalysisCoordinator();
  await coordinator.reserveOrJoin(command("user-1", "first"));
  const first = await coordinator.acquireLease("version-A", "old-worker", now, 30);
  const afterExpiry = new Date(now.getTime() + 31_000);
  assert.equal(await coordinator.recoverExpiredLeases(afterExpiry, 2), 1);
  const second = await coordinator.acquireLease("version-A", "new-worker", afterExpiry, 30);
  assert.equal(second.acquired, true);
  await assert.rejects(() => coordinator.complete("version-A", "old-worker", first.leaseEpoch!, "late-analysis", new Date(afterExpiry.getTime() + 1_000)));
  await coordinator.beginValidation("version-A", "new-worker", second.leaseEpoch!, new Date(afterExpiry.getTime() + 1_000));
  await coordinator.complete("version-A", "new-worker", second.leaseEpoch!, "current-analysis", new Date(afterExpiry.getTime() + 2_000));
  assert.deepEqual(coordinator.workSnapshot("version-A"), { state: "ready", attempt: 2, leaseEpoch: 2, analysisId: "current-analysis" });
  assert.equal(coordinator.usage("user-1", "2026-07")[0]?.state, "committed");
  assert.deepEqual(coordinator.committedLedger("user-1", "2026-07"), [{ analysisVersionId: "version-A", kind: "analysis_view_committed" }]);
});

test("free quota counts unique versions and premium bypasses product quota", async () => {
  const coordinator = new InMemoryAnalysisCoordinator();
  for (const version of ["A", "B", "C"]) await coordinator.reserveOrJoin(command("user-1", version, version));
  await assert.rejects(() => coordinator.reserveOrJoin(command("user-1", "D", "D")));
  await coordinator.reserveOrJoin({ ...command("premium", "D", "D"), plan: "premium", freeLimit: 0 });
});
