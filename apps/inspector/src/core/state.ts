import { randomUUID } from 'node:crypto';
import { CLEF_MODEL, type RunCounts, type RunSnapshot, type RunError } from './types.js';
import { ContractError, validateEntryUrl, validateRunSnapshot } from './validation.js';

export interface StartOptions { entryUrl: string; aiEnabled: boolean; apiKey?: string }
export interface RunHandle { snapshot: RunSnapshot; signal: AbortSignal }
export interface RunUpdate { counts?: Partial<RunCounts>; activeUrls?: string[]; errors?: RunError[] }
export interface FinishOptions {
  saved: boolean; incomplete?: boolean; storageFailed?: boolean; counts?: RunCounts; errors?: RunError[];
  finishedAt?: string; elapsedSec?: number;
}
export interface RegistryOptions { now?: () => number; createRunId?: () => string }
interface Entry { snapshot: RunSnapshot; abort: AbortController; startedMs: number; secrets: string[] }
export function isTerminalState(state: RunSnapshot['state']): boolean { return !['running', 'stopping'].includes(state); }
export function emptyRunCounts(): RunCounts {
  return { discoveredPages: 0, scannedPages: 0, failedPages: 0, skippedPages: 0, pendingPages: 0,
    confirmedFindings: 0, reviewCandidates: 0 };
}
export function sanitizeErrorMessage(message: string, secrets: readonly string[] = []): string {
  let safe = message;
  for (const secret of [...secrets].filter(Boolean).sort((a, b) => b.length - a.length)) safe = safe.split(secret).join('[redacted]');
  return safe.replace(/Bearer\s+\S+/gi, 'Bearer [redacted]').replace(/sk-or-[a-zA-Z0-9_-]+/g, '[redacted]');
}
/** Owns one active run. All public snapshots are copies; terminal state and cancelled data are immutable. */
export class RunRegistry {
  private readonly entries = new Map<string, Entry>();
  private activeId: string | null = null;
  private readonly now: () => number;
  private readonly createRunId: () => string;
  constructor(options: RegistryOptions = {}) { this.now = options.now ?? Date.now; this.createRunId = options.createRunId ?? randomUUID; }
  start(options: StartOptions): RunHandle {
    const entryUrl = validateEntryUrl(options.entryUrl);
    if (typeof options.aiEnabled !== 'boolean') throw new ContractError('INVALID_REQUEST', 'aiEnabled must be boolean');
    if (options.aiEnabled && !options.apiKey?.trim()) throw new ContractError('INVALID_CONFIG', 'AI key must be configured before start');
    if (this.activeId !== null) throw new ContractError('ACTIVE_RUN', 'A run is already active');
    const startedMs = this.now(), runId = this.createRunId();
    if (this.entries.has(runId)) throw new ContractError('INVALID_CONFIG', 'Duplicate run ID');
    const snapshot: RunSnapshot = { runId, entryUrl, startedAt: new Date(startedMs).toISOString(), state: 'running',
      finishedAt: null, elapsedSec: 0, aiEnabled: options.aiEnabled, model: options.aiEnabled ? CLEF_MODEL : null,
      counts: emptyRunCounts(), activeUrls: [], errors: [] };
    validateRunSnapshot(snapshot);
    const entry: Entry = { snapshot, abort: new AbortController(), startedMs, secrets: options.apiKey ? [options.apiKey] : [] };
    this.entries.set(runId, entry); this.activeId = runId;
    return { snapshot: structuredClone(snapshot), signal: entry.abort.signal };
  }
  get(runId: string): RunSnapshot | null {
    const entry = this.entries.get(runId); if (!entry) return null;
    const snapshot = structuredClone(entry.snapshot);
    if (!isTerminalState(snapshot.state)) snapshot.elapsedSec = this.elapsed(entry);
    return snapshot;
  }
  get activeRunId(): string | null { return this.activeId; }
  getSignal(runId: string): AbortSignal { return this.require(runId).abort.signal; }
  acceptsCallbacks(runId: string): boolean {
    return this.activeId === runId && this.entries.get(runId)?.snapshot.state === 'running';
  }
  /** Atomic patch: full replacement of errors/activeUrls, shallow counter merge. Returns false for late callbacks. */
  update(runId: string, patch: RunUpdate): boolean {
    if (!this.acceptsCallbacks(runId)) return false;
    const entry = this.require(runId);
    const next: RunSnapshot = { ...entry.snapshot, elapsedSec: this.elapsed(entry),
      counts: { ...entry.snapshot.counts, ...patch.counts }, activeUrls: structuredClone(patch.activeUrls ?? entry.snapshot.activeUrls),
      errors: structuredClone(patch.errors ?? entry.snapshot.errors).map(error => ({ ...error,
        message: sanitizeErrorMessage(error.message, entry.secrets) })) };
    validateRunSnapshot(next); entry.snapshot = next; return true;
  }
  requestCancel(runId: string): RunSnapshot {
    const entry = this.require(runId);
    if (entry.snapshot.state === 'running') {
      entry.snapshot = { ...entry.snapshot, state: 'stopping', elapsedSec: this.elapsed(entry) };
      // Set state before firing synchronous abort listeners, so they cannot accept late results.
      entry.abort.abort(new Error('USER_CANCELLED'));
    }
    return this.get(runId)!;
  }
  finish(runId: string, options: FinishOptions): RunSnapshot {
    const entry = this.require(runId);
    if (isTerminalState(entry.snapshot.state)) return structuredClone(entry.snapshot);
    const current = entry.snapshot;
    if ((options.finishedAt !== undefined) !== (options.elapsedSec !== undefined))
      throw new ContractError('INVALID_REQUEST', 'finishedAt and elapsedSec must be provided together');
    const counts = structuredClone(options.counts === undefined ? current.counts : options.counts);
    if (current.state === 'stopping' && counts.confirmedFindings !== current.counts.confirmedFindings)
      throw new ContractError('INVALID_REQUEST', 'Confirmed findings cannot change after cancellation');
    const errors = structuredClone(options.errors === undefined ? current.errors : options.errors).map(error => ({ ...error,
      message: sanitizeErrorMessage(error.message, entry.secrets) }));
    const incomplete = options.incomplete || counts.failedPages > 0 || counts.pendingPages > 0 ||
      errors.some(e => !['OUT_OF_SCOPE', 'LOGIN_REQUIRED'].includes(e.code));
    const state = options.storageFailed || !options.saved ? 'failed' : current.state === 'stopping' ? 'cancelled' :
      counts.scannedPages === 0 ? 'failed' : incomplete ? 'partial' : 'completed';
    const snapshot: RunSnapshot = { ...current, state, counts, errors,
      finishedAt: options.finishedAt === undefined ? new Date(this.now()).toISOString() : options.finishedAt,
      elapsedSec: options.elapsedSec === undefined ? this.elapsed(entry) : options.elapsedSec, activeUrls: [] };
    validateRunSnapshot(snapshot); entry.snapshot = snapshot;
    if (this.activeId === runId) this.activeId = null;
    return structuredClone(snapshot);
  }
  private require(runId: string): Entry {
    const entry = this.entries.get(runId); if (!entry) throw new ContractError('NOT_FOUND', 'Run not found'); return entry;
  }
  private elapsed(entry: Entry): number { return Math.max(0, (this.now() - entry.startedMs) / 1000); }
}
