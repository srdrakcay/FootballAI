export interface RevenueCatCreditEvent {
  eventId: string;
  uid: string;
  creditDelta: number;
  productId: string | null;
  transactionId: string | null;
  environment: string | null;
  occurredAtMs: number;
}

interface RevenueCatAdjustment {
  amount?: unknown;
  currency?: { code?: unknown } | null;
}

export interface CreditBalanceState {
  balance: number;
  refundDebt: number;
  lifetimePurchased: number;
  lifetimeRefunded: number;
}

export function parseRevenueCatCreditEvent(payload: unknown): RevenueCatCreditEvent | null {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) throw new Error("INVALID_WEBHOOK_BODY");
  const event = (payload as { event?: unknown }).event;
  if (!event || typeof event !== "object" || Array.isArray(event)) throw new Error("INVALID_WEBHOOK_EVENT");
  const value = event as Record<string, unknown>;
  if (value.type !== "VIRTUAL_CURRENCY_TRANSACTION") return null;

  const eventId = requiredString(value.id, "INVALID_EVENT_ID", 200);
  const uid = requiredString(value.app_user_id, "INVALID_APP_USER_ID", 128);
  const adjustments = value.adjustments;
  if (!Array.isArray(adjustments)) throw new Error("INVALID_ADJUSTMENTS");

  const creditDelta = adjustments.reduce((sum, adjustment) => {
    const item = adjustment as RevenueCatAdjustment;
    if (item?.currency?.code !== "CRD") return sum;
    const amount = Number(item.amount);
    if (!Number.isSafeInteger(amount) || Math.abs(amount) > 100_000) throw new Error("INVALID_CREDIT_ADJUSTMENT");
    return sum + amount;
  }, 0);

  return {
    eventId,
    uid,
    creditDelta,
    productId: optionalString(value.product_id, 200),
    transactionId: optionalString(value.transaction_id, 300),
    environment: optionalString(value.environment, 30),
    occurredAtMs: safeTimestamp(value.event_timestamp_ms),
  };
}

export function applyCreditAdjustment(current: Partial<CreditBalanceState>, delta: number): CreditBalanceState {
  const balance = nonNegativeInteger(current.balance);
  const refundDebt = nonNegativeInteger(current.refundDebt);
  const lifetimePurchased = nonNegativeInteger(current.lifetimePurchased);
  const lifetimeRefunded = nonNegativeInteger(current.lifetimeRefunded);

  if (delta >= 0) {
    const debtPayment = Math.min(refundDebt, delta);
    return {
      balance: balance + delta - debtPayment,
      refundDebt: refundDebt - debtPayment,
      lifetimePurchased: lifetimePurchased + delta,
      lifetimeRefunded,
    };
  }

  const removal = Math.abs(delta);
  const removedFromBalance = Math.min(balance, removal);
  return {
    balance: balance - removedFromBalance,
    refundDebt: refundDebt + removal - removedFromBalance,
    lifetimePurchased,
    lifetimeRefunded: lifetimeRefunded + removal,
  };
}

function requiredString(value: unknown, errorCode: string, maxLength: number): string {
  if (typeof value !== "string" || value.length === 0 || value.length > maxLength) throw new Error(errorCode);
  return value;
}

function optionalString(value: unknown, maxLength: number): string | null {
  return typeof value === "string" && value.length > 0 && value.length <= maxLength ? value : null;
}

function safeTimestamp(value: unknown): number {
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : Date.now();
}

function nonNegativeInteger(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : 0;
}
