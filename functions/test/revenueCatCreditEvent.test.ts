import assert from "node:assert/strict";
import test from "node:test";
import { applyCreditAdjustment, parseRevenueCatCreditEvent } from "../src/revenuecat/creditEvent.js";

test("parses CRD virtual currency adjustments", () => {
  const event = parseRevenueCatCreditEvent({
    event: {
      id: "event_1",
      type: "VIRTUAL_CURRENCY_TRANSACTION",
      app_user_id: "firebase_uid",
      product_id: "footballai_credits_5",
      transaction_id: "transaction_1",
      environment: "SANDBOX",
      event_timestamp_ms: 1_700_000_000_000,
      adjustments: [{ amount: 5, currency: { code: "CRD" } }],
    },
  });
  assert.equal(event?.creditDelta, 5);
  assert.equal(event?.uid, "firebase_uid");
});

test("ignores unrelated webhook event types", () => {
  assert.equal(parseRevenueCatCreditEvent({ event: { type: "TEST" } }), null);
});

test("applies purchases after repaying refund debt", () => {
  assert.deepEqual(
    applyCreditAdjustment({ balance: 0, refundDebt: 2, lifetimePurchased: 5, lifetimeRefunded: 2 }, 5),
    { balance: 3, refundDebt: 0, lifetimePurchased: 10, lifetimeRefunded: 2 },
  );
});

test("refunds create debt when credits were already spent", () => {
  assert.deepEqual(
    applyCreditAdjustment({ balance: 1, refundDebt: 0, lifetimePurchased: 5, lifetimeRefunded: 0 }, -5),
    { balance: 0, refundDebt: 4, lifetimePurchased: 5, lifetimeRefunded: 5 },
  );
});
