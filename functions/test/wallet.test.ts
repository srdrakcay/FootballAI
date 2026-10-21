import assert from "node:assert/strict";
import test from "node:test";
import {
  applyStoreAdjustment, availableCredits, commitReservation, InsufficientCreditsError,
  ledgerEntry, newWallet, publicWallet, readWallet, release, reserve, spendDirect,
} from "../src/credits/wallet.js";

test("new wallets start with zero credits by default", () => {
  const wallet = newWallet();
  assert.equal(wallet.balance, 0);
  assert.equal(wallet.lifetimeGranted, 0);
});

test("welcome credits from Remote Config are granted to new wallets", () => {
  const wallet = newWallet(undefined, 2);
  assert.equal(wallet.balance, 2);
  assert.equal(wallet.lifetimeGranted, 2);
  assert.equal(newWallet(undefined, -1).balance, 0);
});

test("migrated quota balance is kept and never negative", () => {
  assert.equal(newWallet(3).balance, 3);
  assert.equal(newWallet(-4).balance, 0);
});

test("reserved credits cannot be spent twice", () => {
  const wallet = reserve(readWallet({ balance: 1 }), 1);
  assert.equal(availableCredits(wallet), 0);
  assert.throws(() => reserve(wallet, 1), InsufficientCreditsError);
  assert.throws(() => spendDirect(wallet, 1), InsufficientCreditsError);
});

test("committing a reservation spends once and clears the hold", () => {
  const committed = commitReservation(reserve(readWallet({ balance: 3 }), 1), 1);
  assert.deepEqual([committed.balance, committed.reservedCredits, committed.lifetimeSpent], [2, 0, 1]);
});

test("releasing a reservation restores availability without touching balance", () => {
  const released = release(reserve(readWallet({ balance: 2 }), 1), 1);
  assert.deepEqual([released.balance, availableCredits(released)], [2, 2]);
  assert.equal(release(readWallet({ balance: 2 }), 5).reservedCredits, 0);
});

test("refunds never make the balance negative and become debt", () => {
  const refunded = applyStoreAdjustment(readWallet({ balance: 2 }), -5);
  assert.deepEqual([refunded.balance, refunded.refundDebt, refunded.lifetimeRefunded], [0, 3, 5]);
  const repaid = applyStoreAdjustment(refunded, 10);
  assert.deepEqual([repaid.balance, repaid.refundDebt, repaid.lifetimePurchased], [7, 0, 10]);
});

test("refund keeps reserved credits within the remaining balance", () => {
  const wallet = applyStoreAdjustment(reserve(readWallet({ balance: 2 }), 2), -1);
  assert.equal(wallet.reservedCredits <= wallet.balance, true);
});

test("public wallet reports spendable credits and ledger records the delta", () => {
  const before = readWallet({ balance: 5, reservedCredits: 1 });
  assert.deepEqual(publicWallet(before, 1), { balance: 5, reserved: 1, available: 4, analysisCreditCost: 1 });
  const after = spendDirect(before, 1);
  const entry = ledgerEntry("analysis_unlock", before, after, { label: "A – B" });
  assert.deepEqual([entry.delta, entry.balanceAfter, entry.label], [-1, 4, "A – B"]);
});

test("corrupt stored values are read as zero", () => {
  assert.deepEqual(readWallet({ balance: "abc", reservedCredits: -3 }).balance, 0);
  assert.equal(readWallet(undefined).reservedCredits, 0);
});
