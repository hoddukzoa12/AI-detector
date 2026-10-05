import { randomUUID } from 'node:crypto';
import { CLEF_MODEL } from './types.js';
import { emptyRunCounts, sanitizeErrorMessage, type RegistryOptions } from './state.js';
import { ContractError } from './validation.js';
import { OCR_MODEL, type OcrFile, type ImageCounts, type RequestCounts, type RunCountsV2, type RunErrorV2, type RunSnapshotV2, type StartRunRequestV2 } from './v2.js';
import { hasIncompleteOcrWork, validateOcrFile, validateRunOcrState, validateRunSnapshotV2, validateStartRunRequestV2 } from './validation-v2.js';

export interface StartOptionsV2 extends StartRunRequestV2 { apiKey?: string }
export interface RunHandleV2 { snapshot: RunSnapshotV2; signal: AbortSignal }
export interface RunUpdateV2 { counts?: Partial<RunCountsV2>; imageCounts?: Partial<ImageCounts>; requestCounts?: Partial<RequestCounts>; activeUrls?: string[]; errors?: RunErrorV2[] }
export interface FinishOptionsV2 {
  saved: boolean; extraSaved: boolean; incomplete?: boolean; storageFailed?: boolean; fatalError?: boolean;
  counts?: RunCountsV2; imageCounts?: ImageCounts; requestCounts?: RequestCounts; errors?: RunErrorV2[];
  finishedAt?: string; elapsedSec?: number;
  /** Required when OCR was selected, including a run with no discovered images. */
  ocr?: OcrFile;
}
interface Entry { snapshot: RunSnapshotV2; abort: AbortController; startedMs: number; secrets: string[] }
export function emptyRunCountsV2(): RunCountsV2 { return { ...emptyRunCounts(), extraConfirmedFindings: 0 }; }
export function emptyImageCounts(): ImageCounts { return { discovered: 0, captured: 0, ocrCompleted: 0, failed: 0, pending: 0, skipped: 0 }; }
export function emptyRequestCounts(): RequestCounts { return { ocr: 0, clef: 0 }; }
/** Defense in depth; callers still supply safe diagnostic summaries, never provider response bodies. */
export function sanitizeAnalysisErrorMessage(message: string, secrets: readonly string[] = []): string {
  return sanitizeErrorMessage(message, secrets)
    .replace(/data:image\/[^\s;,]+;base64,[a-z0-9+/=]+/gi, '[image payload redacted]')
    .replace(/\b(authorization|proxy-authorization|cookie|set-cookie)\s*:\s*[^\r\n]*/gi, '$1: [redacted]');
}
/** Mandatory consent/CLEF boundary; legacy RunRegistry remains for historical migration consumers. */
export class RunRegistryV2 {
  private readonly entries = new Map<string, Entry>();
  private activeId: string | null = null;
  private readonly now: () => number;
  private readonly createRunId: () => string;
  constructor(options: RegistryOptions = {}) { this.now = options.now ?? Date.now; this.createRunId = options.createRunId ?? randomUUID; }
  start(options: StartOptionsV2): RunHandleV2 {
    validateStartRunRequestV2({ entryUrl: options.entryUrl, ocrEnabled: options.ocrEnabled, externalAnalysisConsent: options.externalAnalysisConsent });
    for (const key of Object.keys(options)) if (!['entryUrl', 'ocrEnabled', 'externalAnalysisConsent', 'apiKey'].includes(key)) throw new ContractError('INVALID_REQUEST', 'Unexpected start option');
    if (typeof options.apiKey !== 'string' || !options.apiKey.trim()) throw new ContractError('INVALID_CONFIG', 'CLEF key must be configured before start');
    if (this.activeId !== null) throw new ContractError('ACTIVE_RUN', 'A run is already active');
    const startedMs = this.now(), runId = this.createRunId();
    if (this.entries.has(runId)) throw new ContractError('INVALID_CONFIG', 'Duplicate run ID');
    const snapshot: RunSnapshotV2 = { runId, entryUrl: options.entryUrl, startedAt: new Date(startedMs).toISOString(), state: 'running',
      finishedAt: null, elapsedSec: 0, aiEnabled: true, model: CLEF_MODEL, externalAnalysisConsent: true,
      ocrEnabled: options.ocrEnabled, ocrModel: options.ocrEnabled ? OCR_MODEL : null,
      counts: emptyRunCountsV2(), imageCounts: emptyImageCounts(), requestCounts: emptyRequestCounts(), activeUrls: [], errors: [] };
    validateRunSnapshotV2(snapshot);
    const entry = { snapshot, abort: new AbortController(), startedMs, secrets: [options.apiKey] };
    this.entries.set(runId, entry); this.activeId = runId;
    return { snapshot: structuredClone(snapshot), signal: entry.abort.signal };
  }
  get activeRunId(): string | null { return this.activeId; }
  get(runId: string): RunSnapshotV2 | null {
    const entry = this.entries.get(runId); if (!entry) return null;
    const snapshot = structuredClone(entry.snapshot);
    if (!this.terminal(snapshot)) snapshot.elapsedSec = this.elapsed(entry);
    return snapshot;
  }
  getSignal(runId: string): AbortSignal { return this.require(runId).abort.signal; }
  acceptsCallbacks(runId: string): boolean { return this.activeId === runId && this.entries.get(runId)?.snapshot.state === 'running'; }
  update(runId: string, patch: RunUpdateV2): boolean {
    if (!this.acceptsCallbacks(runId)) return false;
    const entry = this.require(runId), current = entry.snapshot;
    const next: RunSnapshotV2 = { ...current, elapsedSec: this.elapsed(entry), counts: { ...current.counts, ...patch.counts },
      imageCounts: { ...current.imageCounts, ...patch.imageCounts }, requestCounts: { ...current.requestCounts, ...patch.requestCounts },
      activeUrls: structuredClone(patch.activeUrls ?? current.activeUrls), errors: this.errors(patch.errors ?? current.errors, entry) };
    for (const key of ['confirmedFindings', 'extraConfirmedFindings'] as const) if (next.counts[key] < current.counts[key]) throw new ContractError('INVALID_REQUEST', 'Confirmed findings cannot decrease');
    for (const key of ['ocr', 'clef'] as const) if (next.requestCounts[key] < current.requestCounts[key]) throw new ContractError('INVALID_REQUEST', 'Actual request counts cannot decrease');
    validateRunSnapshotV2(next); entry.snapshot = next; return true;
  }
  requestCancel(runId: string): RunSnapshotV2 {
    const entry = this.require(runId);
    if (entry.snapshot.state === 'running') {
      entry.snapshot = { ...entry.snapshot, state: 'stopping', elapsedSec: this.elapsed(entry) };
      entry.abort.abort(new Error('USER_CANCELLED'));
    }
    return this.get(runId)!;
  }
  finish(runId: string, options: FinishOptionsV2): RunSnapshotV2 {
    const entry = this.require(runId), current = entry.snapshot;
    if (this.terminal(current)) return structuredClone(current);
    if ((options.finishedAt !== undefined) !== (options.elapsedSec !== undefined)) throw new ContractError('INVALID_REQUEST', 'finishedAt and elapsedSec must be provided together');
    if (typeof options.saved !== 'boolean' || typeof options.extraSaved !== 'boolean') throw new ContractError('INVALID_REQUEST', 'Both save outcomes are required');
    if (current.ocrEnabled && !options.ocr) throw new ContractError('INVALID_REQUEST', 'Selected OCR finalization requires actual OCR records');
    if (options.ocr) validateOcrFile(options.ocr, true);
    const counts = structuredClone(options.counts ?? current.counts), imageCounts = structuredClone(options.imageCounts ?? current.imageCounts), requestCounts = structuredClone(options.requestCounts ?? current.requestCounts);
    for (const key of ['confirmedFindings', 'extraConfirmedFindings'] as const) if (counts[key] < current.counts[key]) throw new ContractError('INVALID_REQUEST', 'Confirmed findings cannot decrease');
    if (current.state === 'stopping' && (counts.confirmedFindings !== current.counts.confirmedFindings || counts.extraConfirmedFindings !== current.counts.extraConfirmedFindings)) throw new ContractError('INVALID_REQUEST', 'Confirmed findings cannot change after cancellation');
    for (const key of ['ocr', 'clef'] as const) if (requestCounts[key] !== current.requestCounts[key]) throw new ContractError('INVALID_REQUEST', 'Finalization cannot invent actual requests');
    const errors = this.errors(options.errors ?? current.errors, entry);
    const incomplete = options.incomplete || (options.ocr && hasIncompleteOcrWork(options.ocr.images)) || counts.failedPages > 0 || counts.pendingPages > 0 || imageCounts.failed > 0 || imageCounts.pending > 0 ||
      errors.some(e => !['OUT_OF_SCOPE', 'LOGIN_REQUIRED', 'IMAGE_UNSUPPORTED'].includes(e.code));
    const state = options.storageFailed || options.fatalError || !options.saved || !options.extraSaved || counts.scannedPages === 0 ? 'failed' :
      current.state === 'stopping' ? 'cancelled' : incomplete ? 'partial' : 'completed';
    const next: RunSnapshotV2 = { ...current, state, counts, imageCounts, requestCounts, errors, activeUrls: [],
      finishedAt: options.finishedAt === undefined ? new Date(this.now()).toISOString() : options.finishedAt,
      elapsedSec: options.elapsedSec === undefined ? this.elapsed(entry) : options.elapsedSec };
    validateRunSnapshotV2(next); if (options.ocr) validateRunOcrState(next, options.ocr, true); entry.snapshot = next;
    if (this.activeId === runId) this.activeId = null;
    return structuredClone(next);
  }
  private errors(errors: RunErrorV2[], entry: Entry): RunErrorV2[] { return structuredClone(errors).map(e => ({ ...e, message: sanitizeAnalysisErrorMessage(e.message, entry.secrets) })); }
  private terminal(snapshot: RunSnapshotV2): boolean { return !['running', 'stopping'].includes(snapshot.state); }
  private elapsed(entry: Entry): number { return Math.max(0, (this.now() - entry.startedMs) / 1000); }
  private require(runId: string): Entry { const entry = this.entries.get(runId); if (!entry) throw new ContractError('NOT_FOUND', 'Run not found'); return entry; }
}
