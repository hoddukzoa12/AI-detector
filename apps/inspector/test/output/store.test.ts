import { afterEach, describe, expect, it } from 'vitest';
import { mkdtemp, readFile, readdir, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { emptyRunCounts, type EvidenceSnapshot, type OfficialFinding, type RunSnapshot } from '../../src/core/index.js';
import { OutputStore, OutputStorageError, type SaveArtifactsInput } from '../../src/output/index.js';

const roots: string[] = [];
afterEach(async () => { await Promise.all(roots.map(root => rm(root, { recursive: true, force: true }))); roots.length = 0; });
async function root() { const value = await mkdtemp(join(tmpdir(), 'inspector-output-')); roots.push(value); return value; }
function input(runId = 'run-1'): SaveArtifactsInput {
  const run: RunSnapshot = { runId, entryUrl: 'https://example.org/', startedAt: '2026-10-01T00:00:00Z',
    finishedAt: '2026-10-01T00:00:01Z', elapsedSec: 1, state: 'completed', aiEnabled: false, model: null,
    counts: emptyRunCounts(), activeUrls: [], errors: [] };
  return { run, scope: { hostname: 'example.org', framePolicy: 'embedded', skipped: [], unvisitedUrls: [] },
    findings: [], review: { schemaVersion: 1, runId, candidates: [] }, details: { schemaVersion: 1, runId, details: [] }, snapshots: [] };
}
function evidenceInput(runId = 'run-1') {
  const value = input(runId);
  const snapshot: EvidenceSnapshot = { snapshotId: 'snapshot-1', topPageUrl: value.run.entryUrl, frameUrl: value.run.entryUrl,
    framePath: [], capturedAt: value.run.startedAt, html: '<html>원문 대출 😀</html>', elements: [{ location: '#ad', rawText: '원문 대출 😀', styles: [] }] };
  const findings: OfficialFinding[] = [
    { id: 'f1', url: value.run.entryUrl, is_violation: true, location: '#ad', evidence_text: '원문 대출 😀', technique: 'JAMO' },
    { id: 'f2', url: value.run.entryUrl, is_violation: true, location: '#ad', evidence_text: '원문 대출 😀', technique: 'OFFSCREEN' },
    { id: 'f3', url: 'https://example.org/second', is_violation: true, location: '#ad', evidence_text: '두번째', technique: 'TRANSPARENT' }
  ];
  value.findings = findings; value.snapshots = [snapshot];
  value.run.counts.confirmedFindings = findings.length;
  value.details.details = findings.map(f => ({ findingId: f.id, candidateId: `c-${f.id}`, decisionSource: 'local', ruleIds: ['rule'], ai: null,
    evidence: { snapshotId: snapshot.snapshotId, path: null, sha256: null } }));
  value.review.candidates = [{ candidateId: 'review-1', url: value.run.entryUrl, location: '#maybe', evidenceText: '미정', techniques: ['HOMOGLYPH'],
    reason: 'LOCAL_UNCERTAIN', ai: null, evidence: { snapshotId: snapshot.snapshotId, path: null, sha256: null } }];
  value.run.counts.reviewCandidates = 1;
  return value;
}
async function start(store: OutputStore, value: SaveArtifactsInput) {
  return store.beginRun({ ...value.run, state: 'running', finishedAt: null }, value.scope);
}
describe('transactional output store', () => {
  it('finalizes timing once after delayed evidence and review/detail writes, without mutating input', async () => {
    const dir = await root(), value = evidenceInput(); let releasedAt = 0, calls = 0, reviewPath = '', detailsPath = '';
    const startedMs = Date.now() - 1000, previewMs = Date.now();
    value.run.startedAt = new Date(startedMs).toISOString(); value.run.finishedAt = new Date(previewMs).toISOString();
    value.run.elapsedSec = (previewMs - startedMs) / 1000;
    const original = structuredClone(value);
    const store = new OutputStore(dir, { beforeOperation: async ({ operation, path }) => {
      if (operation !== 'write' || !path.startsWith('runs/.staging-')) return;
      if (path.includes('/evidence/')) { await new Promise(resolve => setTimeout(resolve, 40)); releasedAt = Date.now(); }
      if (path.endsWith('/review.json')) reviewPath = path;
      if (path.endsWith('/finding-details.json')) detailsPath = path;
    } });
    await start(store, value);
    let finalTime = { finishedAt: '', elapsedSec: 0 };
    const saved = await store.saveArtifacts(value, { finalizeTiming: () => {
      calls++; const finishedMs = Date.now();
      expect(finishedMs).toBeGreaterThanOrEqual(releasedAt); expect(releasedAt).toBeGreaterThan(0);
      expect(JSON.parse(readFileSync(join(dir, reviewPath), 'utf8')).runId).toBe(value.run.runId);
      expect(JSON.parse(readFileSync(join(dir, detailsPath), 'utf8')).runId).toBe(value.run.runId);
      finalTime = { finishedAt: new Date(finishedMs).toISOString(), elapsedSec: (finishedMs - startedMs) / 1000 };
      // Only the two timing fields may affect the fixed terminal preview.
      return { ...finalTime, state: 'failed', counts: emptyRunCounts() };
    } });
    expect(calls).toBe(1); expect(value).toEqual(original);
    expect(saved.status.run).toEqual({ ...original.run, ...finalTime });
    expect(saved.result.meta.finished_at).toBe(finalTime.finishedAt); expect(saved.result.meta.elapsed_sec).toBe(finalTime.elapsedSec);
    expect(finalTime.elapsedSec).toBeGreaterThanOrEqual(original.run.elapsedSec + .03);
    expect(await store.readLatest()).toEqual(saved);
    const resultBytes = await store.readFile(value.run.runId, 'result.json');
    expect(JSON.parse(resultBytes.toString('utf8')).meta.finished_at).toBe(finalTime.finishedAt);
    expect(saved.status.files.resultSha256).toBe(createHash('sha256').update(resultBytes).digest('hex'));
  });
  it.each([
    { finishedAt: 'invalid', elapsedSec: 2 },
    { finishedAt: '2026-09-30T23:59:59Z', elapsedSec: 2 },
    { finishedAt: '2026-10-01T00:00:02Z', elapsedSec: -1 },
    { finishedAt: '2026-10-01T00:00:02Z', elapsedSec: NaN },
    { finishedAt: '2026-10-01T00:00:02Z', elapsedSec: Infinity }
  ])('safely rejects invalid final timing %# and retains the input preview fallback', async timing => {
    const dir = await root(), store = new OutputStore(dir), value = evidenceInput(), original = structuredClone(value); let calls = 0;
    await start(store, value);
    const error = await store.saveArtifacts(value, { finalizeTiming: () => { calls++; return timing; } }).catch(error => error);
    expect(error).toBeInstanceOf(OutputStorageError); expect(calls).toBe(1);
    expect(error.failureStatus.run.finishedAt).toBe(value.run.finishedAt); expect(error.failureStatus.run.elapsedSec).toBe(value.run.elapsedSec);
    expect(error.failureStatus.resultSaved).toBe(false); expect(value).toEqual(original); expect(await store.readLatest()).toBeNull();
    expect(await readdir(join(dir, 'runs'))).toEqual([]);
    await expect(store.readFile(value.run.runId, 'result.json')).rejects.toThrow();
  });
  it.each(['before-finalizer', 'finalizer-throws', 'after-finalizer'] as const)('retains the correct failure timing at %s', async fault => {
    const dir = await root(), value = evidenceInput(), finalTime = { finishedAt: '2026-10-01T00:00:09Z', elapsedSec: 9 }; let calls = 0;
    const store = new OutputStore(dir, { beforeOperation: ({ operation, path }) => {
      if (fault === 'before-finalizer' && operation === 'write' && path.includes('/evidence/')) throw new Error('secret');
      if (fault === 'after-finalizer' && operation === 'rename' && path === 'result.json') throw new Error('secret');
    } });
    await start(store, value);
    const error = await store.saveArtifacts(value, { finalizeTiming: () => {
      calls++; if (fault === 'finalizer-throws') throw new Error('private credentials'); return finalTime;
    } }).catch(error => error);
    expect(error).toBeInstanceOf(OutputStorageError); expect(error.message).not.toContain('private');
    expect(calls).toBe(fault === 'before-finalizer' ? 0 : 1);
    const expectedTime = fault === 'after-finalizer' ? finalTime : value.run;
    expect(error.failureStatus.run.finishedAt).toBe(expectedTime.finishedAt); expect(error.failureStatus.run.elapsedSec).toBe(expectedTime.elapsedSec);
    expect(await store.readLatest()).toBeNull();
    if (fault === 'after-finalizer') {
      const bytes = await store.readFile(value.run.runId, 'result.json');
      expect(JSON.parse(bytes.toString('utf8')).meta.finished_at).toBe(finalTime.finishedAt);
      expect(error.failureStatus.files.resultSha256).toBe(createHash('sha256').update(bytes).digest('hex'));
      expect(JSON.parse(await readFile(join(dir, 'runs/run-1/scan-status.json'), 'utf8')).run.finishedAt).toBe(finalTime.finishedAt);
    }
  });
  it('saves exact empty official JSON and separate status, with verified canonical copies', async () => {
    const dir = await root(), store = new OutputStore(dir), value = input();
    const initial = await start(store, value);
    expect(initial.resultSaved).toBe(false); expect(Object.values(initial.files)).toEqual([null, null, null, null, null]);
    const saved = await store.saveArtifacts(value);
    expect(saved.result).toEqual({ meta: { topic: 'TOPIC', entry_url: value.run.entryUrl, started_at: value.run.startedAt,
      finished_at: value.run.finishedAt, elapsed_sec: 1 }, findings: [] });
    expect(Object.keys(saved.status)).toEqual(['schemaVersion', 'run', 'scope', 'files', 'resultSaved']);
    expect(saved.status.files.resultPath).toBe('runs/run-1/result.json');
    expect(await store.readLatest()).toEqual(saved);
    expect(await readFile(join(dir, 'result.json'))).toEqual(await store.readFile('run-1', 'result.json'));
    expect(saved.status.files.resultSha256).toBe(createHash('sha256').update(await store.readFile('run-1', 'result.json')).digest('hex'));
  });
  it('preserves UTF-8 raw HTML/text, flat multipage/multitechnique findings, exact details and actual byte hashes', async () => {
    const dir = await root(), store = new OutputStore(dir), value = evidenceInput(); await start(store, value);
    const saved = await store.saveArtifacts(value);
    expect(saved.result.findings).toEqual(value.findings);
    expect(saved.result.findings[0]).not.toHaveProperty('confidence');
    expect(saved.review.candidates[0].evidence).toEqual(saved.details.details[0].evidence);
    expect(value.details.details[0].evidence.path).toBeNull();
    const bytes = await store.readEvidence('run-1', 'snapshot-1');
    expect(bytes.subarray(0, 3)).not.toEqual(Buffer.from([0xef, 0xbb, 0xbf]));
    expect(JSON.parse(bytes.toString('utf8'))).toEqual(value.snapshots[0]);
    expect(saved.details.details[0].evidence).toEqual({ snapshotId: 'snapshot-1', path: 'runs/run-1/evidence/snapshot-1.json', sha256: createHash('sha256').update(bytes).digest('hex') });
    for (const name of ['result.json', 'review.json', 'finding-details.json', 'scan-status.json'] as const) {
      expect((await store.readFile('run-1', name)).subarray(0, 3)).not.toEqual(Buffer.from([0xef, 0xbb, 0xbf]));
    }
  });
  it.each(['cancelled', 'failed', 'partial'] as const)('preserves confirmed findings for %s runs', async state => {
    const store = new OutputStore(await root()), value = evidenceInput(); value.run.state = state; await start(store, value);
    expect((await store.saveArtifacts(value)).result.findings).toHaveLength(3);
  });
  it('requires terminal snapshot, matching run IDs, exactly one detail per finding and registered snapshots', async () => {
    const store = new OutputStore(await root()), value = evidenceInput(); await start(store, value);
    await expect(store.saveArtifacts({ ...value, run: { ...value.run, state: 'running', finishedAt: null } })).rejects.toThrow();
    await expect(store.saveArtifacts({ ...value, review: { ...value.review, runId: 'other' } })).rejects.toThrow();
    await expect(store.saveArtifacts({ ...value, details: { ...value.details, details: [] } })).rejects.toThrow();
    await expect(store.saveArtifacts({ ...value, snapshots: [] })).rejects.toThrow();
    await expect(store.saveArtifacts({ ...value, findings: [...value.findings, value.findings[0]] })).rejects.toThrow();
    const priorRefs = structuredClone(value);
    priorRefs.details.details[0].evidence = { snapshotId: 'snapshot-1', path: '.env', sha256: 'a'.repeat(64) };
    await expect(store.saveArtifacts(priorRefs)).rejects.toThrow();
  });
  it('invalidates stale latest at new run start while preserving old archive', async () => {
    const dir = await root(), store = new OutputStore(dir), first = input(); await start(store, first); await store.saveArtifacts(first);
    const oldBytes = await store.readFile('run-1', 'result.json'); await start(store, input('run-2'));
    expect(await store.readLatest()).toBeNull();
    await expect(readFile(join(dir, 'result.json'))).rejects.toThrow();
    expect(await store.readFile('run-1', 'result.json')).toEqual(oldBytes);
  });
  it.each([1, 2, 3, 4, 5])('does not report success on canonical rename failure step %i, and preserves committed archive', async failedStep => {
    const dir = await root(); let armed = false, renames = 0, committedBytes: Buffer | null = null;
    const store = new OutputStore(dir, { beforeOperation: async ({ operation, path }) => {
      if (armed && operation === 'rename' && !path.startsWith('runs/') && ++renames === failedStep) {
        committedBytes = await readFile(join(dir, 'runs/run-2/result.json'));
        throw new Error('private credential value');
      }
    } });
    const first = input(); await start(store, first); await store.saveArtifacts(first);
    const oldBytes = await store.readFile('run-1', 'result.json'), next = input('run-2'); await start(store, next); armed = true;
    const error = await store.saveArtifacts(next).catch(error => error);
    expect(error).toBeInstanceOf(OutputStorageError); expect(error.message).not.toContain('private');
    expect(error.runError.code).toBe('STORAGE_ERROR'); expect(error.failureStatus.run.state).toBe('failed');
    expect(error.failureStatus.resultSaved).toBe(true);
    expect(error.failureStatus.files.resultPath).toBe('runs/run-2/result.json');
    expect(error.failureStatus.files.resultSha256).toBe(createHash('sha256').update(await store.readFile('run-2', 'result.json')).digest('hex'));
    expect(JSON.parse((await store.readFile('run-2', 'scan-status.json')).toString('utf8'))).toEqual(error.failureStatus);
    // Direct disk reads remain authoritative after the writer instance and its memory are gone.
    const archivedStatusBytes = await readFile(join(dir, 'runs/run-2/scan-status.json'));
    expect(JSON.parse(archivedStatusBytes.toString('utf8'))).toEqual(error.failureStatus);
    const persistedManifest = JSON.parse(await readFile(join(dir, 'runs/run-2/manifest.json'), 'utf8'));
    expect(persistedManifest.files['scan-status.json']).toBe(createHash('sha256').update(archivedStatusBytes).digest('hex'));
    expect(await store.readLatest()).toBeNull();
    expect(await store.readFile('run-1', 'result.json')).toEqual(oldBytes);
    expect(await store.readFile('run-2', 'result.json')).toEqual(committedBytes);
    expect((await readdir(dir)).filter(name => ['result.json', 'review.json', 'finding-details.json', 'scan-status.json'].includes(name))).toEqual([]);
    armed = false;
    const nextAfterFailure = input('run-3'); await start(store, nextAfterFailure);
    expect((await store.saveArtifacts(nextAfterFailure)).status.run.runId).toBe('run-3');
    expect(JSON.parse((await store.readFile('run-2', 'scan-status.json')).toString('utf8')).run.state).toBe('failed');
  });
  it.each(['scan-status.json', 'manifest.json'])('persists an archive failure record when repairing %s is unavailable', async blockedName => {
    const dir = await root(); let armed = false;
    const store = new OutputStore(dir, { beforeOperation: ({ operation, path }) => {
      if (armed && operation === 'rename' && path === 'result.json') throw new Error('publish failure');
      if (armed && operation === 'write' && path.startsWith(`runs/run-1/${blockedName}.tmp-`)) throw new Error('archive metadata unavailable');
    } });
    const value = evidenceInput(); await start(store, value); armed = true;
    const error = await store.saveArtifacts(value).catch(error => error);
    expect(error).toBeInstanceOf(OutputStorageError);
    const durableFailure = JSON.parse(await readFile(join(dir, 'runs/run-1/failure-status.json'), 'utf8'));
    expect(durableFailure).toEqual(error.failureStatus); expect(durableFailure.run.state).toBe('failed');
    const resultBytes = await readFile(join(dir, 'runs/run-1/result.json'));
    expect(createHash('sha256').update(resultBytes).digest('hex')).toBe(durableFailure.files.resultSha256);
    expect(JSON.parse((await store.readFile('run-1', 'scan-status.json')).toString('utf8'))).toEqual(durableFailure);
    expect((await store.readEvidence('run-1', 'snapshot-1')).toString('utf8')).toContain(value.snapshots[0].html);
  });
  it('persists a run-specific root fallback when the committed run directory cannot accept metadata writes', async () => {
    const dir = await root(); let armed = false;
    const store = new OutputStore(dir, { beforeOperation: ({ operation, path }) => {
      if (armed && operation === 'rename' && path === 'result.json') throw new Error('publish unavailable');
      if (armed && operation === 'write' && path.startsWith('runs/run-1/')) throw new Error('run directory read-only');
    } });
    const value = input(); await start(store, value); armed = true;
    const error = await store.saveArtifacts(value).catch(error => error);
    expect(error).toBeInstanceOf(OutputStorageError);
    const fallbackPath = join(dir, 'run-failures/run-1.json');
    const fallback = JSON.parse(await readFile(fallbackPath, 'utf8'));
    expect(fallback).toEqual(error.failureStatus); expect(fallback.resultSaved).toBe(true);
    expect(JSON.parse((await store.readFile('run-1', 'scan-status.json')).toString('utf8'))).toEqual(fallback);
    armed = false; await start(store, input('run-2'));
    expect(JSON.parse(await readFile(fallbackPath, 'utf8')).run.state).toBe('failed');
    expect(JSON.parse((await store.readFile('run-1', 'scan-status.json')).toString('utf8'))).toEqual(fallback);
    await writeFile(fallbackPath, JSON.stringify({ ...fallback, run: { ...fallback.run, state: 'completed' } }));
    await expect(store.readFile('run-1', 'scan-status.json')).rejects.toBeInstanceOf(OutputStorageError);
  });
  it('surfaces specific storage write error with failure status and no fallback', async () => {
    const dir = await root(); let armed = false;
    const store = new OutputStore(dir, { beforeOperation: ({ operation, path }) => {
      if (armed && operation === 'write' && path.endsWith('result.json')) throw Object.assign(new Error('secret'), { code: 'EACCES' });
    } });
    const value = input(); await start(store, value); armed = true;
    await expect(store.saveArtifacts(value)).rejects.toMatchObject({ name: 'OutputStorageError', runError: { code: 'STORAGE_ERROR' }, failureStatus: { resultSaved: false } });
    expect(JSON.parse(await readFile(join(dir, 'failure-status.json'), 'utf8')).run.state).toBe('failed');
    expect(await store.readLatest()).toBeNull();
  });
  it('preserves the previous archive when the new archive commit itself fails', async () => {
    const dir = await root(); let armed = false;
    const store = new OutputStore(dir, { beforeOperation: ({ operation, path }) => {
      if (armed && operation === 'rename' && path === 'runs/run-2') throw new Error('storage unavailable');
    } });
    const first = input(); await start(store, first); await store.saveArtifacts(first);
    const bytes = await store.readFile('run-1', 'result.json'), second = input('run-2'); await start(store, second); armed = true;
    await expect(store.saveArtifacts(second)).rejects.toBeInstanceOf(OutputStorageError);
    expect(await store.readFile('run-1', 'result.json')).toEqual(bytes);
    expect(await store.readLatest()).toBeNull();
    expect((await readdir(join(dir, 'runs')))).toEqual(['run-1']);
  });
  it('rejects stale save callbacks and cannot overwrite a committed run', async () => {
    const store = new OutputStore(await root()), first = input(), second = input('run-2');
    await start(store, first); await start(store, second);
    await expect(store.saveArtifacts(first)).rejects.toThrow();
    await store.saveArtifacts(second);
    await expect(store.saveArtifacts(second)).rejects.toThrow();
    await expect(start(store, second)).rejects.toThrow();
  });
  it('detects corrupted/stale/mixed artifacts by hashes', async () => {
    const dir = await root(), store = new OutputStore(dir), value = input(); await start(store, value); await store.saveArtifacts(value);
    await writeFile(join(dir, 'review.json'), JSON.stringify(input('stale').review));
    await expect(store.readLatest()).rejects.toBeInstanceOf(OutputStorageError);
    await writeFile(join(dir, 'runs/run-1/result.json'), '{}');
    await expect(store.readFile('run-1', 'review.json')).rejects.toBeInstanceOf(OutputStorageError);
  });
  it('rejects arbitrary names, traversal IDs, unregistered IDs and symlink reads outside the root', async () => {
    const dir = await root(), outside = await root(), store = new OutputStore(dir), value = evidenceInput(); await start(store, value); await store.saveArtifacts(value);
    await expect(start(store, input('../outside'))).rejects.toThrow();
    await expect(store.readFile('run-1', '.env' as 'result.json')).rejects.toThrow();
    await expect(store.readFile('../run-1', 'result.json')).rejects.toThrow();
    await expect(store.readFile('unknown', 'result.json')).rejects.toThrow();
    await expect(store.readEvidence('run-1', '../snapshot-1')).rejects.toThrow();
    await expect(store.readEvidence('run-1', 'unknown')).rejects.toThrow();
    await writeFile(join(outside, 'payload'), 'private');
    await rm(join(dir, 'runs/run-1/evidence/snapshot-1.json'));
    await symlink(join(outside, 'payload'), join(dir, 'runs/run-1/evidence/snapshot-1.json'));
    await expect(store.readEvidence('run-1', 'snapshot-1')).rejects.toThrow();
  });
  it('rejects symlink roots and symlink archive directories before writing', async () => {
    const dir = await root(), outside = await root(); await symlink(outside, join(dir, 'alias'));
    await expect(start(new OutputStore(join(dir, 'alias')), input())).rejects.toThrow();
    await symlink(outside, join(dir, 'runs'));
    await expect(start(new OutputStore(dir), input())).rejects.toThrow();
    expect(await readdir(outside)).toEqual([]);
  });
  it('rejects a replaced archive directory symlink during reads', async () => {
    const dir = await root(), outside = await root(), store = new OutputStore(dir), value = input();
    await start(store, value); await store.saveArtifacts(value);
    await rm(join(dir, 'runs/run-1'), { recursive: true });
    await symlink(outside, join(dir, 'runs/run-1'));
    await expect(store.readFile('run-1', 'result.json')).rejects.toBeInstanceOf(OutputStorageError);
  });
});
