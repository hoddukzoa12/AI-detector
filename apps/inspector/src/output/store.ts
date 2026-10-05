import { createHash, randomUUID } from 'node:crypto';
import * as fs from 'node:fs/promises';
import { dirname, isAbsolute, join, parse, relative, resolve, sep } from 'node:path';
import { ContractError, isTerminalState, validateEvidenceSnapshot, validateFindingDetailsFile,
  validateOfficialResult, validateReviewFile, validateRunSnapshot, validateScanStatusFile,
  type EvidenceSnapshot, type FindingDetailsFile, type OfficialFinding, type OfficialResult,
  type ReviewFile, type RunError, type RunSnapshot, type ScanScope, type ScanStatusFile } from '../core/index.js';

// Status is replaced after its three referenced JSON files; the group marker follows all four.
export const OUTPUT_FILE_NAMES = ['result.json', 'review.json', 'finding-details.json', 'scan-status.json'] as const;
export type OutputFileName = typeof OUTPUT_FILE_NAMES[number];
export interface SaveArtifactsInput {
  run: RunSnapshot; scope: ScanScope; findings: OfficialFinding[]; review: ReviewFile;
  details: FindingDetailsFile; snapshots: EvidenceSnapshot[]; toolVersion?: string;
}
export interface SavedArtifacts { result: OfficialResult; status: ScanStatusFile; review: ReviewFile; details: FindingDetailsFile }
export interface SaveArtifactsOptions { finalizeTiming?: () => { finishedAt: string; elapsedSec: number } }
export interface OutputOperation { operation: 'mkdir' | 'write' | 'rename' | 'remove'; path: string }
/** Test/fault instrumentation runs immediately before the specific filesystem mutation. */
export interface OutputStoreOptions { beforeOperation?: (operation: OutputOperation) => void | Promise<void> }
interface Manifest { schemaVersion: 1; runId: string; files: Record<OutputFileName, string>; evidence: Record<string, string> }
const STORAGE_MESSAGE = 'Unable to save or verify local output artifacts.';
function storageRunError(): RunError { return { scope: 'storage', code: 'STORAGE_ERROR', url: null, candidateId: null, message: STORAGE_MESSAGE }; }
export class OutputStorageError extends Error {
  readonly runError = storageRunError();
  constructor(public readonly failureStatus: ScanStatusFile | null = null) {
    super(STORAGE_MESSAGE); this.name = 'OutputStorageError';
  }
}
function safeId(id: string): void {
  if (typeof id !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$/.test(id))
    throw new ContractError('INVALID_REQUEST', 'A safe registered identifier is required');
}
function missing(error: unknown): boolean { return typeof error === 'object' && error !== null && 'code' in error && error.code === 'ENOENT'; }
function hash(bytes: Buffer): string { return createHash('sha256').update(bytes).digest('hex'); }
/** Stable JSON encodes the captured strings without Unicode normalization, in UTF-8 without BOM. */
function encode(value: unknown): Buffer {
  const stable = (item: unknown): unknown => {
    if (Array.isArray(item)) return item.map(stable);
    if (item !== null && typeof item === 'object') return Object.fromEntries(Object.entries(item).sort(([a], [b]) => a.localeCompare(b)).map(([key, val]) => [key, stable(val)]));
    return item;
  };
  return Buffer.from(`${JSON.stringify(stable(value), null, 2)}\n`, 'utf8');
}
function initialStatus(run: RunSnapshot, scope: ScanScope): ScanStatusFile {
  return { schemaVersion: 1, run: structuredClone(run), scope: structuredClone(scope), files: {
    resultPath: null, reviewPath: null, findingDetailsPath: null, evidenceDir: null, resultSha256: null }, resultSaved: false };
}

/** One writer owns a root. Archived result/evidence bytes are preserved; latest.json is the group's commit marker.
 * No HTML is executed or transmitted. Hashes identify stored bytes, not legal certification.
 */
export class OutputStore {
  readonly outputRoot: string;
  private readonly registered = new Map<string, Manifest | null>();
  // Last-resort UI state when the filesystem cannot accept any failure record. Ordinarily the
  // failed state is persisted in the run's status/manifest and supplementary failure record.
  private readonly failureStatuses = new Map<string, ScanStatusFile>();
  private activeRunId: string | null = null;
  private rootReady = false;
  private queue: Promise<unknown> = Promise.resolve();
  constructor(outputRoot: string, private readonly options: OutputStoreOptions = {}) {
    this.outputRoot = resolve(outputRoot);
  }
  private serialized<T>(operation: () => Promise<T>): Promise<T> {
    const pending = this.queue.then(operation); this.queue = pending.catch(() => undefined); return pending;
  }
  async beginRun(run: RunSnapshot, scope: ScanScope): Promise<ScanStatusFile> {
    return this.serialized(async () => {
      validateRunSnapshot(run); safeId(run.runId);
      if (isTerminalState(run.state)) throw new ContractError('INVALID_REQUEST', 'Begin requires an active run');
      if (this.registered.has(run.runId)) throw new ContractError('INVALID_REQUEST', 'Run ID already registered');
      const status = initialStatus(run, scope); validateScanStatusFile(status);
      try {
        await this.initializeRoot(); await this.mkdir('runs');
        // Remove the commit marker before any canonical file so stale files cannot claim a new run.
        await this.invalidateLatest();
        await this.remove('failure-status.json');
        await this.writeAtomic('active-run.json', encode({ runId: run.runId }));
        this.activeRunId = run.runId; this.registered.set(run.runId, null);
        return status;
      } catch { throw new OutputStorageError(status); }
    });
  }
  async saveArtifacts(input: SaveArtifactsInput, options: SaveArtifactsOptions = {}): Promise<SavedArtifacts> {
    // Capture caller data before an asynchronous boundary; callers retain their null evidence references.
    const captured = structuredClone(input);
    const finalizeTiming = options.finalizeTiming;
    return this.serialized(async () => {
      const { run, scope, snapshots } = captured;
      validateRunSnapshot(run); safeId(run.runId);
      if (!isTerminalState(run.state) || run.finishedAt === null) throw new ContractError('INVALID_REQUEST', 'A terminal run with finishedAt is required');
      if (!this.registered.has(run.runId) || this.activeRunId !== run.runId || this.registered.get(run.runId) !== null)
        throw new ContractError('INVALID_REQUEST', 'Run is not the active registered output generation');
      const result: OfficialResult = { meta: { topic: 'TOPIC', entry_url: run.entryUrl, started_at: run.startedAt,
        finished_at: run.finishedAt, elapsed_sec: run.elapsedSec,
        ...(captured.toolVersion === undefined ? {} : { tool_version: captured.toolVersion }) }, findings: captured.findings };
      const review = captured.review, details = captured.details;
      validateOfficialResult(result); validateReviewFile(review, true); validateFindingDetailsFile(details, result, true);
      if (review.runId !== run.runId || details.runId !== run.runId) throw new ContractError('INVALID_REQUEST', 'Artifact run IDs must match');
      if (run.counts.confirmedFindings !== result.findings.length || run.counts.reviewCandidates !== review.candidates.length)
        throw new ContractError('INVALID_REQUEST', 'Run counts must match the shared result data');
      const evidenceBytes = new Map<string, Buffer>();
      for (const snapshot of snapshots) {
        validateEvidenceSnapshot(snapshot); safeId(snapshot.snapshotId);
        if (evidenceBytes.has(snapshot.snapshotId)) throw new ContractError('INVALID_REQUEST', 'Duplicate snapshot ID');
        evidenceBytes.set(snapshot.snapshotId, encode(snapshot));
      }
      for (const item of [...review.candidates, ...details.details]) {
        safeId(item.evidence.snapshotId);
        if (item.evidence.path !== null || item.evidence.sha256 !== null)
          throw new ContractError('INVALID_REQUEST', 'Unstored evidence references must have null paths and hashes');
        const bytes = evidenceBytes.get(item.evidence.snapshotId);
        if (!bytes) throw new ContractError('INVALID_REQUEST', 'Evidence must refer to a supplied snapshot');
        // Do not trust paths or hashes supplied by callers; use only registered snapshot IDs and real bytes.
        item.evidence = { snapshotId: item.evidence.snapshotId,
          path: `runs/${run.runId}/evidence/${item.evidence.snapshotId}.json`, sha256: hash(bytes) };
      }
      const runPath = `runs/${run.runId}`, reviewBytes = encode(review), detailsBytes = encode(details);
      let archivedManifest: Manifest | null = null, savedStatus: ScanStatusFile | null = null, stagedStatusBytes: Buffer | null = null;
      const staging = `runs/.staging-${run.runId}-${randomUUID()}`;
      try {
        await this.mkdir(`${staging}/evidence`);
        for (const [id, bytes] of evidenceBytes) await this.write(`${staging}/evidence/${id}.json`, bytes);
        await this.write(`${staging}/review.json`, reviewBytes);
        await this.write(`${staging}/finding-details.json`, detailsBytes);
        // Bulk evidence and auxiliary output is on disk before this single timing sample.
        // Validate a candidate first, so a thrown/invalid finalizer retains the preview fallback.
        if (finalizeTiming) {
          const timing = finalizeTiming();
          const finalizedRun: RunSnapshot = { ...run, finishedAt: timing.finishedAt, elapsedSec: timing.elapsedSec };
          validateRunSnapshot(finalizedRun);
          run.finishedAt = finalizedRun.finishedAt; run.elapsedSec = finalizedRun.elapsedSec;
          result.meta.finished_at = timing.finishedAt; result.meta.elapsed_sec = timing.elapsedSec;
        }
        validateOfficialResult(result);
        const resultBytes = encode(result);
        const status: ScanStatusFile = { schemaVersion: 1, run, scope, files: {
          resultPath: `${runPath}/result.json`, reviewPath: `${runPath}/review.json`, findingDetailsPath: `${runPath}/finding-details.json`,
          evidenceDir: `${runPath}/evidence`, resultSha256: hash(resultBytes) }, resultSaved: true };
        validateScanStatusFile(status);
        const artifacts: SavedArtifacts = { result, status, review, details };
        const files: Record<OutputFileName, Buffer> = { 'result.json': resultBytes, 'scan-status.json': encode(status),
          'review.json': reviewBytes, 'finding-details.json': detailsBytes };
        const manifest: Manifest = { schemaVersion: 1, runId: run.runId,
          files: Object.fromEntries(OUTPUT_FILE_NAMES.map(name => [name, hash(files[name])])) as Manifest['files'],
          evidence: Object.fromEntries([...evidenceBytes].map(([id, bytes]) => [id, hash(bytes)])) };
        archivedManifest = manifest; savedStatus = status; stagedStatusBytes = files['scan-status.json'];
        await this.write(`${staging}/result.json`, resultBytes);
        await this.write(`${staging}/scan-status.json`, files['scan-status.json']);
        await this.write(`${staging}/manifest.json`, encode(manifest));
        // A run ID cannot overwrite an archive, including one left by an earlier process.
        try { await fs.lstat(await this.checkedPath(runPath)); throw new OutputStorageError(); }
        catch (error) { if (!missing(error)) throw error; }
        await this.rename(staging, runPath);
        this.registered.set(run.runId, manifest);
        await this.verifyArchive(manifest);
        await this.invalidateLatest();
        for (const name of OUTPUT_FILE_NAMES) await this.writeAtomic(name, files[name]);
        await this.verifyCanonical(manifest);
        // The marker is published last. No reader treats a partially replaced group as complete.
        await this.writeAtomic('latest.json', encode(manifest));
        await this.remove('active-run.json'); this.activeRunId = null;
        return structuredClone(artifacts);
      } catch {
        // Never remove the archive: confirmed results remain retrievable even if publishing fails.
        const failureStatus = initialStatus({ ...run, state: 'failed', activeUrls: [], errors: [...run.errors, storageRunError()] }, scope);
        if (archivedManifest && savedStatus && stagedStatusBytes && this.registered.get(run.runId) === archivedManifest) {
          try {
            await this.verifyArchive(archivedManifest);
            failureStatus.resultSaved = true;
            failureStatus.files = structuredClone(savedStatus.files);
            this.failureStatuses.set(run.runId, structuredClone(failureStatus));
            await this.persistArchiveFailure(archivedManifest, failureStatus, stagedStatusBytes);
          } catch { /* No saved claim unless the complete archive's real bytes verify. */ }
        }
        this.activeRunId = null;
        try { await this.invalidateLatest(); } catch { /* An absent marker still invalidates any remaining canonical files. */ }
        try {
          await this.mkdir('run-failures');
          await this.writeAtomic(`run-failures/${run.runId}.json`, encode(failureStatus));
        } catch { /* Keep attempting the single-file fallback if directory creation is unavailable. */ }
        try { await this.writeAtomic('failure-status.json', encode(failureStatus)); } catch { /* Surface failure even when storage is unavailable. */ }
        try { await this.remove(staging, true); } catch { /* Uncommitted staging is never served. */ }
        throw new OutputStorageError(failureStatus);
      }
    });
  }
  async readFile(runId: string, name: OutputFileName): Promise<Buffer> {
    safeId(runId);
    if (!OUTPUT_FILE_NAMES.includes(name)) throw new ContractError('FORBIDDEN', 'Artifact name is not allowed');
    return this.serialized(async () => {
      const manifest = this.requireArchive(runId);
      try {
        const files = await this.verifyArchive(manifest);
        const failureStatus = await this.readFailureStatus(manifest);
        return name === 'scan-status.json' && failureStatus ? encode(failureStatus) : files[name];
      }
      catch { throw new OutputStorageError(); }
    });
  }
  async readEvidence(runId: string, snapshotId: string): Promise<Buffer> {
    safeId(runId); safeId(snapshotId);
    return this.serialized(async () => {
      const manifest = this.requireArchive(runId);
      if (!Object.hasOwn(manifest.evidence, snapshotId)) throw new ContractError('NOT_FOUND', 'Snapshot is not registered');
      try {
        await this.verifyArchive(manifest);
        return await this.read(`runs/${runId}/evidence/${snapshotId}.json`);
      } catch { throw new OutputStorageError(); }
    });
  }
  async readLatest(): Promise<SavedArtifacts | null> {
    return this.serialized(async () => {
      if (!this.rootReady) return null;
      try {
        let marker: Buffer;
        try { marker = await this.read('latest.json'); } catch (error) { if (missing(error)) return null; throw error; }
        const decoded = JSON.parse(marker.toString('utf8')) as Manifest;
        const registered = this.requireArchive(decoded.runId);
        if (!encode(registered).equals(marker)) throw new OutputStorageError();
        const files = await this.verifyCanonical(registered); await this.verifyArchive(registered);
        return this.decode(files, registered.runId);
      } catch { throw new OutputStorageError(); }
    });
  }
  private requireArchive(runId: string): Manifest {
    const manifest = this.registered.get(runId);
    if (!manifest) throw new ContractError('NOT_FOUND', 'Run artifacts are not registered');
    return manifest;
  }
  private async persistArchiveFailure(manifest: Manifest, failureStatus: ScanStatusFile, previousStatus: Buffer): Promise<void> {
    const prefix = `runs/${manifest.runId}/`, bytes = encode(failureStatus);
    // Write the independent failure record first, so interrupted metadata replacement still
    // leaves a durable terminal failure beside the preserved result and its original manifest.
    try { await this.writeAtomic(`${prefix}failure-status.json`, bytes); }
    catch { /* Status replacement and the root fallback may still be writable. */ }
    const updated: Manifest = { ...manifest, files: { ...manifest.files, 'scan-status.json': hash(bytes) } };
    try {
      await this.writeAtomic(`${prefix}scan-status.json`, bytes);
      await this.writeAtomic(`${prefix}manifest.json`, encode(updated));
      await this.verifyArchive(updated);
      this.registered.set(manifest.runId, updated);
    } catch {
      // Only this failing run's metadata is revised. Previously saved results/evidence and
      // other runs are never rewritten. Readers detect any rollback that cannot finish.
      try { await this.writeAtomic(`${prefix}scan-status.json`, previousStatus); } catch { /* Durable failure record remains authoritative. */ }
      try { await this.writeAtomic(`${prefix}manifest.json`, encode(manifest)); } catch { /* Hash verification rejects a partial pair. */ }
    }
  }
  private async readFailureStatus(manifest: Manifest): Promise<ScanStatusFile | undefined> {
    for (const path of [`runs/${manifest.runId}/failure-status.json`, `run-failures/${manifest.runId}.json`, 'failure-status.json']) {
      let bytes: Buffer;
      try { bytes = await this.read(path); } catch (error) { if (missing(error)) continue; throw error; }
      const status: unknown = JSON.parse(bytes.toString('utf8')); validateScanStatusFile(status);
      if (status.run.runId !== manifest.runId) {
        if (path === 'failure-status.json') continue;
        throw new OutputStorageError();
      }
      if (status.run.state !== 'failed' || !status.resultSaved ||
        status.files.resultPath !== `runs/${manifest.runId}/result.json` || status.files.resultSha256 !== manifest.files['result.json'])
        throw new OutputStorageError();
      const expected = this.failureStatuses.get(manifest.runId);
      if (expected && !encode(expected).equals(bytes)) throw new OutputStorageError();
      return status;
    }
    return this.failureStatuses.get(manifest.runId);
  }
  private decode(files: Record<OutputFileName, Buffer>, runId: string): SavedArtifacts {
    const result: unknown = JSON.parse(files['result.json'].toString('utf8'));
    const status: unknown = JSON.parse(files['scan-status.json'].toString('utf8'));
    const review: unknown = JSON.parse(files['review.json'].toString('utf8'));
    const details: unknown = JSON.parse(files['finding-details.json'].toString('utf8'));
    validateOfficialResult(result); validateScanStatusFile(status); validateReviewFile(review, true); validateFindingDetailsFile(details, result, true);
    if (status.run.runId !== runId || review.runId !== runId || details.runId !== runId || !status.resultSaved ||
      status.files.resultSha256 !== hash(files['result.json']) || result.meta.entry_url !== status.run.entryUrl ||
      result.meta.started_at !== status.run.startedAt || result.meta.finished_at !== status.run.finishedAt || result.meta.elapsed_sec !== status.run.elapsedSec)
      throw new OutputStorageError();
    return { result, status, review, details };
  }
  private async verifyCanonical(manifest: Manifest): Promise<Record<OutputFileName, Buffer>> { return this.verifyFiles(manifest, ''); }
  private async verifyArchive(manifest: Manifest): Promise<Record<OutputFileName, Buffer>> {
    const prefix = `runs/${manifest.runId}/`;
    if (!encode(manifest).equals(await this.read(`${prefix}manifest.json`))) throw new OutputStorageError();
    const files = await this.verifyFiles(manifest, prefix);
    for (const [id, sha] of Object.entries(manifest.evidence)) {
      if (hash(await this.read(`${prefix}evidence/${id}.json`)) !== sha) throw new OutputStorageError();
    }
    const decoded = this.decode(files, manifest.runId);
    for (const item of [...decoded.review.candidates, ...decoded.details.details]) {
      const ref = item.evidence;
      if (ref.path !== `${prefix}evidence/${ref.snapshotId}.json` || ref.sha256 !== manifest.evidence[ref.snapshotId]) throw new OutputStorageError();
    }
    return files;
  }
  private async verifyFiles(manifest: Manifest, prefix: string): Promise<Record<OutputFileName, Buffer>> {
    const files = {} as Record<OutputFileName, Buffer>;
    for (const name of OUTPUT_FILE_NAMES) {
      const bytes = await this.read(`${prefix}${name}`);
      if (hash(bytes) !== manifest.files[name]) throw new OutputStorageError(); files[name] = bytes;
    }
    return files;
  }
  private async initializeRoot(): Promise<void> {
    if (this.rootReady) { await this.checkedPath(''); return; }
    // Reject symlink ancestors before recursive mkdir can follow them outside the configured root.
    const ancestors: string[] = []; let cursor = this.outputRoot;
    while (cursor !== parse(cursor).root) { ancestors.unshift(cursor); cursor = dirname(cursor); }
    for (const ancestor of ancestors) {
      try { if ((await fs.lstat(ancestor)).isSymbolicLink()) throw new OutputStorageError(); }
      catch (error) { if (!missing(error)) throw error; }
    }
    await this.before('mkdir', ''); await fs.mkdir(this.outputRoot, { recursive: true });
    if (await fs.realpath(this.outputRoot) !== this.outputRoot) throw new OutputStorageError();
    this.rootReady = true;
  }
  private async checkedPath(path: string): Promise<string> {
    const target = resolve(this.outputRoot, path), rel = relative(this.outputRoot, target);
    if (rel.startsWith(`..${sep}`) || rel === '..' || isAbsolute(rel)) throw new OutputStorageError();
    const components = [this.outputRoot, ...rel.split(sep).filter(Boolean).map((_part, i, all) => join(this.outputRoot, ...all.slice(0, i + 1)))];
    for (const part of components) {
      try {
        if ((await fs.lstat(part)).isSymbolicLink()) throw new OutputStorageError();
        const actual = relative(this.outputRoot, await fs.realpath(part));
        if (actual === '..' || actual.startsWith(`..${sep}`) || isAbsolute(actual)) throw new OutputStorageError();
      } catch (error) { if (!missing(error)) throw error; }
    }
    return target;
  }
  private async before(operation: OutputOperation['operation'], path: string): Promise<void> { await this.options.beforeOperation?.({ operation, path }); }
  private async mkdir(path: string): Promise<void> { const target = await this.checkedPath(path); await this.before('mkdir', path); await fs.mkdir(target, { recursive: true }); }
  private async write(path: string, bytes: Buffer): Promise<void> { const target = await this.checkedPath(path); await this.before('write', path); await fs.writeFile(target, bytes, { flag: 'wx', mode: 0o600 }); }
  private async rename(from: string, to: string): Promise<void> {
    const source = await this.checkedPath(from), target = await this.checkedPath(to); await this.before('rename', to); await fs.rename(source, target);
  }
  private async remove(path: string, recursive = false): Promise<void> { const target = await this.checkedPath(path); await this.before('remove', path); await fs.rm(target, { force: true, recursive }); }
  private async read(path: string): Promise<Buffer> { return fs.readFile(await this.checkedPath(path)); }
  private async writeAtomic(path: string, bytes: Buffer): Promise<void> {
    const temporary = `${path}.tmp-${randomUUID()}`;
    try { await this.write(temporary, bytes); await this.rename(temporary, path); }
    finally { await this.remove(temporary); }
  }
  private async invalidateLatest(): Promise<void> {
    await this.remove('latest.json');
    for (const name of OUTPUT_FILE_NAMES) await this.remove(name);
  }
}
