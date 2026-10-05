import { describe, expect, it } from 'vitest';
import { RunRegistry, emptyRunCounts, type FinishOptions, type RunError } from '../../src/core/index.js';

describe('isolated run state', () => {
  it('rejects simultaneous start, missing AI config and invalid URLs before creating a run', () => {
    const registry = new RunRegistry();
    expect(() => registry.start({ entryUrl: 'relative', aiEnabled: false })).toThrow();
    expect(() => registry.start({ entryUrl: 'https://example.org/', aiEnabled: true, apiKey: ' ' })).toThrow();
    const run = registry.start({ entryUrl: 'https://example.org/', aiEnabled: false });
    expect(run.snapshot.state).toBe('running');
    expect(() => registry.start({ entryUrl: 'https://example.org/', aiEnabled: false })).toThrow(/ACTIVE_RUN/);
  });
  it('freezes counts at cancel and ignores late callbacks, idempotently', () => {
    const registry = new RunRegistry();
    const { snapshot, signal } = registry.start({ entryUrl: 'https://example.org/', aiEnabled: false });
    registry.update(snapshot.runId, { counts: { scannedPages: 1, confirmedFindings: 1 } });
    expect(registry.requestCancel(snapshot.runId).state).toBe('stopping');
    expect(signal.aborted).toBe(true);
    expect(registry.requestCancel(snapshot.runId).state).toBe('stopping');
    expect(registry.update(snapshot.runId, { counts: { confirmedFindings: 2 } })).toBe(false);
    const terminal = registry.finish(snapshot.runId, { saved: true });
    expect(terminal.state).toBe('cancelled');
    expect(terminal.counts.confirmedFindings).toBe(1);
    expect(registry.requestCancel(snapshot.runId)).toEqual(terminal);
    expect(registry.finish(snapshot.runId, { saved: false, storageFailed: true })).toEqual(terminal);
  });
  it('isolates old runs and returned snapshots from a new run', () => {
    const registry = new RunRegistry();
    const first = registry.start({ entryUrl: 'https://example.org/', aiEnabled: false });
    registry.update(first.snapshot.runId, { counts: { scannedPages: 1 } });
    registry.finish(first.snapshot.runId, { saved: true });
    const second = registry.start({ entryUrl: 'https://example.org/', aiEnabled: false });
    expect(registry.acceptsCallbacks(first.snapshot.runId)).toBe(false);
    expect(registry.update(first.snapshot.runId, { counts: { scannedPages: 99 } })).toBe(false);
    second.snapshot.counts.scannedPages = 99;
    expect(registry.get(second.snapshot.runId)?.counts.scannedPages).toBe(0);
  });
  it('distinguishes completion, partial, failure, and storage failure', () => {
    for (const [scanned, options, expected] of [
      [1, { saved: true }, 'completed'], [1, { saved: true, incomplete: true }, 'partial'],
      [0, { saved: true }, 'failed'], [1, { saved: true, storageFailed: true }, 'failed'],
    ] as const) {
      const registry = new RunRegistry();
      const { snapshot } = registry.start({ entryUrl: 'https://example.org/', aiEnabled: false });
      registry.update(snapshot.runId, { counts: { scannedPages: scanned } });
      expect(registry.finish(snapshot.runId, options).state).toBe(expected);
    }
  });
  it('rejects invalid mutation atomically and sanitizes configured secrets', () => {
    const registry = new RunRegistry();
    const { snapshot } = registry.start({ entryUrl: 'https://example.org/', aiEnabled: true, apiKey: 'test-secret' });
    expect(() => registry.update(snapshot.runId, { counts: { scannedPages: -1 } })).toThrow();
    expect(registry.get(snapshot.runId)?.counts.scannedPages).toBe(0);
    registry.update(snapshot.runId, { errors: [{ scope: 'ai', code: 'AI_HTTP_ERROR', url: null, candidateId: null,
      message: 'Authorization Bearer test-secret failed' }] });
    expect(JSON.stringify(registry.get(snapshot.runId))).not.toContain('test-secret');
  });
  it('rejects a callback synchronously fired by abort and never reopens terminal state', () => {
    const registry = new RunRegistry();
    const { snapshot, signal } = registry.start({ entryUrl: 'https://example.org/', aiEnabled: false });
    let accepted = true;
    signal.addEventListener('abort', () => { accepted = registry.update(snapshot.runId, { counts: { confirmedFindings: 5 } }); });
    registry.requestCancel(snapshot.runId);
    expect(accepted).toBe(false);
    const terminal = registry.finish(snapshot.runId, { saved: true });
    expect(terminal.state).toBe('cancelled');
    expect(registry.update(snapshot.runId, { counts: { confirmedFindings: 100 } })).toBe(false);
    expect(registry.get(snapshot.runId)).toEqual(terminal);
  });
});

describe('atomic final snapshot', () => {
  const startMs = Date.parse('2026-10-04T00:00:00.000Z');
  const start = (aiEnabled = false) => {
    const registry = new RunRegistry({ now: () => startMs + 10_000 });
    const { snapshot } = registry.start({ entryUrl: 'https://example.org/', aiEnabled, apiKey: aiEnabled ? 'test-secret' : undefined });
    return { registry, runId: snapshot.runId };
  };
  it('uses the saved preview timestamp pair exactly, without recomputing it', () => {
    const { registry, runId } = start();
    const preview = { finishedAt: '2026-10-04T00:00:11.500Z', elapsedSec: 1.5 };
    const terminal = registry.finish(runId, { saved: true, counts: { ...emptyRunCounts(), scannedPages: 1 }, ...preview });
    expect(terminal).toMatchObject({ state: 'completed', ...preview });
  });
  it('applies cancelled review and collection cleanup, sanitized errors and detached inputs', () => {
    const { registry, runId } = start(true);
    registry.update(runId, { counts: { confirmedFindings: 2, pendingPages: 3, scannedPages: 1 } });
    registry.requestCancel(runId);
    const counts = { ...emptyRunCounts(), scannedPages: 2, confirmedFindings: 2, reviewCandidates: 3 };
    const errors: RunError[] = [{ scope: 'ai', code: 'AI_HTTP_ERROR', url: null, candidateId: 'c1', message: 'test-secret Bearer token-value' }];
    const terminal = registry.finish(runId, { saved: true, counts, errors });
    expect(terminal.state).toBe('cancelled');
    expect(terminal.counts).toEqual(counts);
    expect(terminal.errors).toHaveLength(1);
    expect(JSON.stringify(terminal)).not.toContain('test-secret');
    expect(JSON.stringify(terminal)).not.toContain('token-value');
    counts.reviewCandidates = 99; errors[0].message = 'changed';
    terminal.counts.scannedPages = 99;
    expect(registry.get(runId)?.counts.reviewCandidates).toBe(3);
    expect(registry.get(runId)?.counts.scannedPages).toBe(2);
    expect(registry.get(runId)?.errors[0].message).not.toBe('changed');
  });
  it.each([1, 3])('rejects changed positive count %i after cancellation atomically', (confirmedFindings) => {
    const { registry, runId } = start();
    registry.update(runId, { counts: { confirmedFindings: 2 } });
    registry.requestCancel(runId);
    const before = registry.get(runId);
    expect(() => registry.finish(runId, { saved: true, counts: { ...emptyRunCounts(), confirmedFindings } })).toThrow();
    expect(registry.get(runId)).toEqual(before);
    expect(registry.activeRunId).toBe(runId);
    expect(registry.update(runId, { counts: { confirmedFindings: 3 } })).toBe(false);
  });
  it.each<Partial<FinishOptions>>([
    { finishedAt: '2026-10-04T00:00:11.000Z' }, { elapsedSec: 1 },
    { finishedAt: 'invalid', elapsedSec: 1 }, { finishedAt: '2026-10-04T00:00:09.000Z', elapsedSec: 1 },
    { finishedAt: '2026-10-04T00:00:11.000Z', elapsedSec: NaN },
    { finishedAt: '2026-10-04T00:00:11.000Z', elapsedSec: -1 },
    { counts: { ...emptyRunCounts(), scannedPages: -1 } },
    { finishedAt: null, elapsedSec: 1 } as unknown as Partial<FinishOptions>,
    { finishedAt: '2026-10-04T00:00:11.000Z', elapsedSec: null } as unknown as Partial<FinishOptions>,
    { errors: [{ scope: 'ai', code: 'AI_HTTP_ERROR', url: null, candidateId: null, message: '' }] },
  ])('rejects invalid pair or counters without storing any patch: %o', (patch) => {
    const { registry, runId } = start();
    const before = registry.get(runId);
    expect(() => registry.finish(runId, { saved: true, ...patch })).toThrow();
    expect(registry.get(runId)).toEqual(before);
    expect(registry.activeRunId).toBe(runId);
  });
  it('accepts a valid supplied time pair without requiring elapsed to equal the wall clock difference', () => {
    const { registry, runId } = start();
    const terminal = registry.finish(runId, { saved: true, counts: { ...emptyRunCounts(), scannedPages: 1 },
      finishedAt: '2026-10-04T00:00:11.000Z', elapsedSec: 2.75 });
    expect(terminal.elapsedSec).toBe(2.75);
    expect(terminal.finishedAt).toBe('2026-10-04T00:00:11.000Z');
  });
  it('calculates partial from final counters and errors, while terminal options are ignored', () => {
    const { registry, runId } = start();
    const terminal = registry.finish(runId, { saved: true, counts: { ...emptyRunCounts(), scannedPages: 1, failedPages: 1 } });
    expect(terminal.state).toBe('partial');
    expect(registry.finish(runId, { saved: false, finishedAt: 'invalid', elapsedSec: NaN,
      counts: { ...emptyRunCounts(), confirmedFindings: -1 } })).toEqual(terminal);
  });
});
