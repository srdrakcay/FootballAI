/**
 * Pure credit arithmetic. Every Firestore transaction that touches a wallet goes through these
 * functions so the rules (never negative, reserved credits are not spendable twice, every change
 * leaves a ledger entry) live in one tested place.
 */
export interface WalletState {
  balance: number;
  reservedCredits: number;
  refundDebt: number;
  lifetimeGranted: number;
  lifetimePurchased: number;
  lifetimeSpent: number;
  lifetimeRefunded: number;
}

export type LedgerKind = "welcome_grant" | "purchase" | "refund" | "analysis_unlock" | "adjustment";

export interface LedgerEntry {
  schemaVersion: 1;
  kind: LedgerKind;
  delta: number;
  balanceAfter: number;
  fixtureKey: string | null;
  analysisId: string | null;
  productId: string | null;
  label: string | null;
}

export interface PublicWallet {
  balance: number;
  reserved: number;
  available: number;
  analysisCreditCost: number;
}

export class InsufficientCreditsError extends Error {
  constructor(public readonly available: number, public readonly required: number) {
    super("INSUFFICIENT_CREDITS");
  }
}

export const welcomeCredits = 1;

export function readWallet(data: Readonly<Record<string, unknown>> | undefined): WalletState {
  return {
    balance: count(data?.balance),
    reservedCredits: count(data?.reservedCredits),
    refundDebt: count(data?.refundDebt),
    lifetimeGranted: count(data?.lifetimeGranted),
    lifetimePurchased: count(data?.lifetimePurchased),
    lifetimeSpent: count(data?.lifetimeSpent),
    lifetimeRefunded: count(data?.lifetimeRefunded),
  };
}

export function availableCredits(wallet: WalletState): number {
  return Math.max(0, wallet.balance - wallet.reservedCredits);
}

export function publicWallet(wallet: WalletState, analysisCreditCost: number): PublicWallet {
  return {
    balance: wallet.balance,
    reserved: Math.min(wallet.reservedCredits, wallet.balance),
    available: availableCredits(wallet),
    analysisCreditCost,
  };
}

export function newWallet(migratedBalance?: number): WalletState {
  const granted = migratedBalance === undefined ? welcomeCredits : count(migratedBalance);
  return {
    balance: granted,
    reservedCredits: 0,
    refundDebt: 0,
    lifetimeGranted: granted,
    lifetimePurchased: 0,
    lifetimeSpent: 0,
    lifetimeRefunded: 0,
  };
}

/** Holds credits for an in-flight generation so parallel requests cannot spend the same credit. */
export function reserve(wallet: WalletState, cost: number): WalletState {
  const required = positive(cost);
  const available = availableCredits(wallet);
  if (available < required) throw new InsufficientCreditsError(available, required);
  return { ...wallet, reservedCredits: wallet.reservedCredits + required };
}

export function release(wallet: WalletState, cost: number): WalletState {
  return { ...wallet, reservedCredits: Math.max(0, wallet.reservedCredits - positive(cost)) };
}

/** Converts a reservation into a spend. */
export function commitReservation(wallet: WalletState, cost: number): WalletState {
  const required = positive(cost);
  if (wallet.balance < required) throw new InsufficientCreditsError(wallet.balance, required);
  return {
    ...wallet,
    balance: wallet.balance - required,
    reservedCredits: Math.max(0, wallet.reservedCredits - required),
    lifetimeSpent: wallet.lifetimeSpent + required,
  };
}

/** Spends without a prior reservation (an already generated analysis being unlocked). */
export function spendDirect(wallet: WalletState, cost: number): WalletState {
  const required = positive(cost);
  const available = availableCredits(wallet);
  if (available < required) throw new InsufficientCreditsError(available, required);
  return { ...wallet, balance: wallet.balance - required, lifetimeSpent: wallet.lifetimeSpent + required };
}

/** Purchases pay off refund debt first; refunds never push the balance below zero. */
export function applyStoreAdjustment(wallet: WalletState, delta: number): WalletState {
  if (!Number.isSafeInteger(delta) || delta === 0) return wallet;
  if (delta > 0) {
    const debtPayment = Math.min(wallet.refundDebt, delta);
    return {
      ...wallet,
      balance: wallet.balance + delta - debtPayment,
      refundDebt: wallet.refundDebt - debtPayment,
      lifetimePurchased: wallet.lifetimePurchased + delta,
    };
  }
  const removal = Math.abs(delta);
  const removedFromBalance = Math.min(wallet.balance, removal);
  return {
    ...wallet,
    balance: wallet.balance - removedFromBalance,
    reservedCredits: Math.min(wallet.reservedCredits, wallet.balance - removedFromBalance),
    refundDebt: wallet.refundDebt + removal - removedFromBalance,
    lifetimeRefunded: wallet.lifetimeRefunded + removal,
  };
}

export function ledgerEntry(
  kind: LedgerKind,
  before: WalletState,
  after: WalletState,
  references: Partial<Pick<LedgerEntry, "fixtureKey" | "analysisId" | "productId" | "label">> = {},
): LedgerEntry {
  return {
    schemaVersion: 1,
    kind,
    delta: after.balance - before.balance,
    balanceAfter: after.balance,
    fixtureKey: references.fixtureKey ?? null,
    analysisId: references.analysisId ?? null,
    productId: references.productId ?? null,
    label: references.label ? references.label.slice(0, 120) : null,
  };
}

function count(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : 0;
}

function positive(value: number): number {
  return Number.isSafeInteger(value) && value > 0 ? value : 1;
}
