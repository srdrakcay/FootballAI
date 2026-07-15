import { createHash } from "node:crypto";
import { PublicError, type AnalysisState } from "../shared/contracts.js";

export type LedgerState = "reserved" | "committed" | "released";
export interface ReservationCommand {
  uid: string; clientRequestId: string; analysisVersionId: string; periodUTC: string;
  plan: "free" | "premium"; freeLimit: number; now: Date;
}
export interface ReservationResult { requestId: string; reservationId: string; state: AnalysisState; joined: boolean }
export interface LeaseResult { acquired: boolean; requestId: string; leaseEpoch?: number; state: AnalysisState }

interface WorkRecord {
  requestId: string; analysisVersionId: string; state: AnalysisState; attempt: number;
  leaseOwner?: string; leaseEpoch: number; leaseExpiresAt?: number; analysisId?: string;
}
interface ReservationRecord {
  reservationId: string; uid: string; analysisVersionId: string; periodUTC: string;
  requestId: string; state: LedgerState; createdAt: number; committedAt?: number; releasedAt?: number;
}
interface UsageLedgerRecord {
  ledgerId: string; uid: string; analysisVersionId: string; periodUTC: string;
  requestId: string; kind: "analysis_view_committed"; createdAt: number;
}

/**
 * Executable reference model for the Firestore transaction contract. Every public method is one
 * atomic transaction with no await/yield between read and write. The production adapter must keep
 * the same deterministic IDs and compare-and-set lease epoch semantics.
 */
export class InMemoryAnalysisCoordinator {
  private readonly work = new Map<string, WorkRecord>();
  private readonly reservations = new Map<string, ReservationRecord>();
  private readonly usageLedger = new Map<string, UsageLedgerRecord>();
  private readonly idempotency = new Map<string, string>();

  async reserveOrJoin(command: ReservationCommand): Promise<ReservationResult> {
    const idempotencyId = hash(`${command.uid}\u001f${command.clientRequestId}`);
    const priorVersion = this.idempotency.get(idempotencyId);
    if (priorVersion && priorVersion !== command.analysisVersionId) throw new PublicError("IDEMPOTENCY_CONFLICT", idempotencyId);

    const requestId = deterministicRequestId(command.analysisVersionId);
    const reservationId = deterministicReservationId(command.uid, command.analysisVersionId, command.periodUTC);
    const ledgerId = deterministicLedgerId(command.uid, command.analysisVersionId, command.periodUTC);
    const existingReservation = this.reservations.get(reservationId);
    const existingLedger = this.usageLedger.get(ledgerId);
    if (!existingReservation && !existingLedger && command.plan === "free") {
      const activeReservations = [...this.reservations.values()].filter((entry) => entry.uid === command.uid && entry.periodUTC === command.periodUTC && entry.state === "reserved").length;
      const committedUsage = [...this.usageLedger.values()].filter((entry) => entry.uid === command.uid && entry.periodUTC === command.periodUTC).length;
      const activeUsage = activeReservations + committedUsage;
      if (activeUsage >= boundedLimit(command.freeLimit)) throw new PublicError("QUOTA_EXHAUSTED", hash(`${command.uid}:${command.periodUTC}`));
    }

    const existingWork = this.work.get(command.analysisVersionId);
    const joined = existingWork !== undefined;
    const work = existingWork ?? { requestId, analysisVersionId: command.analysisVersionId, state: "queued", attempt: 0, leaseEpoch: 0 };
    this.work.set(command.analysisVersionId, work);
    if (!existingLedger && (!existingReservation || existingReservation.state === "released")) {
      this.reservations.set(reservationId, { reservationId, uid: command.uid, analysisVersionId: command.analysisVersionId, periodUTC: command.periodUTC, requestId, state: "reserved", createdAt: command.now.getTime() });
    }
    this.idempotency.set(idempotencyId, command.analysisVersionId);
    return { requestId, reservationId, state: work.state, joined };
  }

  async acquireLease(analysisVersionId: string, ownerId: string, now: Date, leaseSeconds: number): Promise<LeaseResult> {
    const work = this.requiredWork(analysisVersionId);
    const nowMs = now.getTime();
    const activeLease = work.state === "generating" && (work.leaseExpiresAt ?? 0) > nowMs;
    if (activeLease) return { acquired: false, requestId: work.requestId, state: work.state };
    if (!["queued", "failed_retryable", "generating"].includes(work.state)) return { acquired: false, requestId: work.requestId, state: work.state };
    work.state = "generating"; work.attempt += 1; work.leaseEpoch += 1; work.leaseOwner = ownerId;
    work.leaseExpiresAt = nowMs + boundedLeaseSeconds(leaseSeconds) * 1_000;
    return { acquired: true, requestId: work.requestId, leaseEpoch: work.leaseEpoch, state: work.state };
  }

  async beginValidation(analysisVersionId: string, ownerId: string, leaseEpoch: number, now: Date): Promise<void> {
    const work = this.assertLease(analysisVersionId, ownerId, leaseEpoch, now);
    work.state = "validating";
  }

  async complete(analysisVersionId: string, ownerId: string, leaseEpoch: number, analysisId: string, now: Date): Promise<void> {
    const work = this.assertLease(analysisVersionId, ownerId, leaseEpoch, now, ["generating", "validating"]);
    work.state = "ready"; work.analysisId = analysisId; delete work.leaseExpiresAt; delete work.leaseOwner;
    for (const entry of this.reservations.values()) if (entry.analysisVersionId === analysisVersionId && entry.state === "reserved") {
      entry.state = "committed"; entry.committedAt = now.getTime();
      const ledgerId = deterministicLedgerId(entry.uid, entry.analysisVersionId, entry.periodUTC);
      if (!this.usageLedger.has(ledgerId)) this.usageLedger.set(ledgerId, { ledgerId, uid: entry.uid, analysisVersionId: entry.analysisVersionId, periodUTC: entry.periodUTC, requestId: entry.requestId, kind: "analysis_view_committed", createdAt: now.getTime() });
    }
  }

  async failPermanent(analysisVersionId: string, ownerId: string, leaseEpoch: number, now: Date): Promise<void> {
    const work = this.assertLease(analysisVersionId, ownerId, leaseEpoch, now, ["generating", "validating"]);
    work.state = "failed_permanent"; delete work.leaseExpiresAt; delete work.leaseOwner;
    this.releaseReservations(analysisVersionId, now);
  }

  async recoverExpiredLeases(now: Date, maximumAttempts: number): Promise<number> {
    let recovered = 0;
    for (const work of this.work.values()) {
      if ((work.state === "generating" || work.state === "validating") && (work.leaseExpiresAt ?? 0) <= now.getTime()) {
        delete work.leaseOwner; delete work.leaseExpiresAt; recovered += 1;
        if (work.attempt >= Math.max(1, maximumAttempts)) {
          work.state = "failed_permanent"; this.releaseReservations(work.analysisVersionId, now);
        } else {
          work.state = "failed_retryable";
        }
      }
    }
    return recovered;
  }

  usage(uid: string, periodUTC: string): ReadonlyArray<{ analysisVersionId: string; state: LedgerState }> {
    return [...this.reservations.values()].filter((entry) => entry.uid === uid && entry.periodUTC === periodUTC).map(({ analysisVersionId, state }) => ({ analysisVersionId, state }));
  }

  committedLedger(uid: string, periodUTC: string): ReadonlyArray<{ analysisVersionId: string; kind: "analysis_view_committed" }> {
    return [...this.usageLedger.values()].filter((entry) => entry.uid === uid && entry.periodUTC === periodUTC).map(({ analysisVersionId, kind }) => ({ analysisVersionId, kind }));
  }

  workSnapshot(analysisVersionId: string): Readonly<{ state: AnalysisState; attempt: number; leaseEpoch: number; analysisId?: string }> {
    const work = this.requiredWork(analysisVersionId);
    return { state: work.state, attempt: work.attempt, leaseEpoch: work.leaseEpoch, ...(work.analysisId ? { analysisId: work.analysisId } : {}) };
  }

  private requiredWork(versionId: string): WorkRecord {
    const work = this.work.get(versionId);
    if (!work) throw new PublicError("REQUEST_NOT_FOUND", hash(versionId));
    return work;
  }

  private assertLease(versionId: string, ownerId: string, epoch: number, now: Date, allowedStates: AnalysisState[] = ["generating"]): WorkRecord {
    const work = this.requiredWork(versionId);
    if (work.leaseOwner !== ownerId || work.leaseEpoch !== epoch || (work.leaseExpiresAt ?? 0) <= now.getTime() || !allowedStates.includes(work.state)) {
      throw new PublicError("LEASE_LOST", work.requestId);
    }
    return work;
  }

  private releaseReservations(versionId: string, now: Date): void {
    for (const entry of this.reservations.values()) if (entry.analysisVersionId === versionId && entry.state === "reserved") {
      entry.state = "released"; entry.releasedAt = now.getTime();
    }
  }
}

const hash = (value: string) => createHash("sha256").update(value).digest("hex");
const deterministicRequestId = (versionId: string) => `req_${hash(versionId)}`;
const deterministicReservationId = (uid: string, versionId: string, period: string) => `res_${hash(`${uid}\u001f${versionId}\u001f${period}`)}`;
const deterministicLedgerId = (uid: string, versionId: string, period: string) => `use_${hash(`${uid}\u001f${versionId}\u001f${period}`)}`;
const boundedLimit = (value: number) => Math.min(20, Math.max(0, Math.trunc(value)));
const boundedLeaseSeconds = (value: number) => Math.min(180, Math.max(30, Math.trunc(value)));
