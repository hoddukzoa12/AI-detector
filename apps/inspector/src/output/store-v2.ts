import { createHash, randomUUID } from 'node:crypto';
import * as fs from 'node:fs/promises';
import { constants } from 'node:fs';
import { dirname, isAbsolute, parse, relative, resolve, sep } from 'node:path';
import { ContractError, validateEvidenceSnapshot, validateFindingDetailsFile, validateOfficialResult,
  validateReviewFile, validateScanStatusFile, type EvidenceSnapshot, type OfficialFinding, type OfficialResult } from '../core/index.js';
import { validateFindingDetailsFileV2, validateOcrFile, validateResultPair, validateReviewFileV2,
  validateRunSnapshotV2, validateScanStatusFileV2 } from '../core/validation-v2.js';
import { DEFAULT_ANALYSIS_LIMITS, type CapturedImageAssets, type ExtraFinding, type ExtraResult,
  type FindingDetailsFileV2, type ImageAssetReference, type ImageInputReference, type ImageScratchAsset,
  type OcrFile, type ReviewFileV2, type RunSnapshotV2, type ScanStatusFileV2 } from '../core/v2.js';
import type { OutputOperation, OutputStoreOptions, SaveArtifactsOptions, SavedArtifacts } from './store.js';
export const OUTPUT_FILE_NAMES_V2 = ['result.json', 'result_extra.json', 'review.json', 'finding-details.json', 'ocr.json', 'scan-status.json'] as const;
export type OutputFileNameV2 = typeof OUTPUT_FILE_NAMES_V2[number];
export interface OutputStoreV2Options extends OutputStoreOptions { maxImageBytes?: number; maxImagePixels?: number }
export interface SaveArtifactsInputV2 {
  run: RunSnapshotV2; scope: ScanStatusFileV2['scope']; findings: OfficialFinding[]; extraFindings: ExtraFinding[];
  review: ReviewFileV2; details: FindingDetailsFileV2; ocr: OcrFile; snapshots: EvidenceSnapshot[]; toolVersion?: string;
}
export interface SavedArtifactsV2 { result: OfficialResult; extraResult: ExtraResult; status: ScanStatusFileV2; review: ReviewFileV2; details: FindingDetailsFileV2; ocr: OcrFile }
interface Asset { reference: ImageAssetReference | ImageInputReference; kind: 'original' | 'input' }
interface Manifest { schemaVersion: 1 | 2; runId: string; files: Record<string, string>; evidence: Record<string, string>; images?: Record<string, Asset> }
interface Active { run: RunSnapshotV2; scope: ScanStatusFileV2['scope']; staging: string; images: Record<string, Asset>; storageFailed: boolean }
const MESSAGE = 'Unable to save or verify local output artifacts.';
const storageError = () => ({ scope: 'storage' as const, code: 'STORAGE_ERROR' as const, url: null, candidateId: null, message: MESSAGE });
export class OutputStorageErrorV2 extends Error {
  readonly runError = storageError();
  constructor(public readonly failureStatus: ScanStatusFileV2 | null = null) { super(MESSAGE); this.name = 'OutputStorageErrorV2'; }
}
function safeId(id: string): void { if (typeof id !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$/.test(id)) throw new ContractError('INVALID_REQUEST', 'A safe registered identifier is required'); }
function missing(e: unknown): boolean { return !!e && typeof e === 'object' && 'code' in e && e.code === 'ENOENT'; }
function hash(bytes: Buffer): string { return createHash('sha256').update(bytes).digest('hex'); }
function encode(value: unknown): Buffer {
  const stable = (v: unknown): unknown => Array.isArray(v) ? v.map(stable) : v !== null && typeof v === 'object' ? Object.fromEntries(Object.entries(v).sort(([a], [b]) => a.localeCompare(b)).map(([k, item]) => [k, stable(item)])) : v;
  return Buffer.from(`${JSON.stringify(stable(value), null, 2)}\n`, 'utf8');
}
function initialStatus(run: RunSnapshotV2, scope: ScanStatusFileV2['scope'], ocr?: OcrFile): ScanStatusFileV2 {
  return { schemaVersion: 2, run: structuredClone(run), scope: structuredClone(scope), files: { resultPath: null, resultSha256: null,
    extraResultPath: null, extraResultSha256: null, reviewPath: null, findingDetailsPath: null, evidenceDir: null, ocrPath: null },
    resultSaved: false, extraResultSaved: false, imageScope: { enabled: run.ocrEnabled, framePolicy: 'first',
      unsupportedKinds: ['canvas', 'video', 'animation_remaining_frames'], pendingImageIds: ocr?.images.filter(i => ['discovered', 'captured', 'running', 'not_started', 'cancelled'].includes(i.status)).map(i => i.imageId) ?? [] } };
}
/** New writes are V2 only. V1 archives are independently validated and never rewritten. HTTP authentication belongs to the server. */
export class OutputStoreV2 {
  readonly outputRoot: string;
  private active: Active | null = null;
  private queue: Promise<unknown> = Promise.resolve();
  private failures = new Map<string, ScanStatusFileV2>();
  private readonly maxImageBytes: number;
  private readonly maxImagePixels: number;
  constructor(outputRoot: string, private readonly options: OutputStoreV2Options = {}) {
    this.outputRoot = resolve(outputRoot); this.maxImageBytes = options.maxImageBytes ?? DEFAULT_ANALYSIS_LIMITS.maxImageBytes;
    this.maxImagePixels = options.maxImagePixels ?? DEFAULT_ANALYSIS_LIMITS.maxImagePixels;
    if (![this.maxImageBytes, this.maxImagePixels].every(n => Number.isSafeInteger(n) && n > 0)) throw new ContractError('INVALID_CONFIG', 'Positive safe image limits required');
  }
  private serialized<T>(fn: () => Promise<T>): Promise<T> { const pending = this.queue.then(fn); this.queue = pending.catch(() => undefined); return pending; }
  async beginRun(run: RunSnapshotV2, scope: ScanStatusFileV2['scope']): Promise<ScanStatusFileV2> {
    const captured = structuredClone({ run, scope });
    return this.serialized(async () => {
      validateRunSnapshotV2(captured.run); safeId(run.runId);
      if (this.active || !['running', 'stopping'].includes(run.state)) throw new ContractError('INVALID_REQUEST', 'One active output generation is required');
      const status = initialStatus(captured.run, captured.scope); validateScanStatusFileV2(status);
      try {
        await this.initializeRoot(); await this.mkdir('runs');
        try { await fs.lstat(await this.checkedPath(`runs/${run.runId}`)); throw new ContractError('INVALID_REQUEST', 'Run ID already archived'); } catch (e) { if (!missing(e)) throw e; }
        const staging = `runs/.staging-${run.runId}-${randomUUID()}`; await this.mkdir(`${staging}/images`);
        this.active = { ...captured, staging, images: {}, storageFailed: false }; return status;
      } catch (e) { if (e instanceof ContractError) throw e; throw new OutputStorageErrorV2(status); }
    });
  }
  async registerOriginalAsset(runId: string, original: ImageScratchAsset): Promise<ImageAssetReference> {
    const captured = structuredClone(original);
    return this.serialized(async () => this.register(this.requireActive(runId), captured, 'original'));
  }
  async registerImageAssets(runId: string, assets: CapturedImageAssets): Promise<{ original: ImageAssetReference; input: ImageInputReference }> {
    const captured = structuredClone(assets); safeId(captured.imageId);
    return this.serialized(async () => {
      const active = this.requireActive(runId);
      const { width, height, frameIndex } = captured.input;
      if (!Number.isSafeInteger(width) || !Number.isSafeInteger(height) || width < 1 || height < 1 || width > this.maxImagePixels / height || frameIndex !== 0 || captured.input.mime !== 'image/png') throw new ContractError('INVALID_REQUEST', 'Bounded first PNG frame required');
      const original = await this.register(active, captured.original, 'original');
      const input = { ...await this.register(active, captured.input, 'input', { width, height }), width, height, frameIndex: 0 as const };
      active.images[input.assetId].reference = input; return structuredClone({ original, input });
    });
  }
  private async register(active: Active, scratch: ImageScratchAsset, kind: Asset['kind'], dimensions?: { width: number; height: number }): Promise<ImageAssetReference> {
    try {
      if (!isAbsolute(scratch.scratchPath) || !/^[a-f0-9]{64}$/.test(scratch.sha256) || !Number.isSafeInteger(scratch.byteLength) || scratch.byteLength <= 0 || scratch.byteLength > this.maxImageBytes || !/^[a-z0-9][a-z0-9!#$&^_.+-]*\/[a-z0-9][a-z0-9!#$&^_.+-]*$/i.test(scratch.mime)) throw new ContractError('INVALID_REQUEST', 'Bounded image scratch reference required');
      await this.rejectSymlinkAncestors(scratch.scratchPath);
      const bytes = await this.readBounded(scratch.scratchPath, scratch.byteLength);
      if (bytes.length !== scratch.byteLength || hash(bytes) !== scratch.sha256) throw new OutputStorageErrorV2();
      if (kind === 'input') { const actual = this.pngDimensions(bytes); if (dimensions && (actual.width !== dimensions.width || actual.height !== dimensions.height)) throw new OutputStorageErrorV2(); }
      const assetId = `asset-${randomUUID()}`, file = `${assetId}.${kind === 'input' ? 'png' : 'bin'}`;
      await this.write(`${active.staging}/images/${file}`, bytes);
      const reference = { assetId, path: `runs/${active.run.runId}/images/${file}`, sha256: hash(bytes), mime: scratch.mime, byteLength: bytes.length };
      active.images[assetId] = { reference, kind }; return structuredClone(reference);
    } catch (e) { active.storageFailed = true; if (e instanceof ContractError) throw e; throw new OutputStorageErrorV2(initialStatus({ ...active.run, state: 'failed', finishedAt: new Date().toISOString(), activeUrls: [], errors: [...active.run.errors, storageError()] }, active.scope)); }
  }
  private requireActive(runId: string): Active { safeId(runId); if (this.active?.run.runId !== runId) throw new ContractError('INVALID_REQUEST', 'Run is not the active output generation'); return this.active; }
  async saveArtifacts(input: SaveArtifactsInputV2, options: SaveArtifactsOptions = {}): Promise<SavedArtifactsV2> {
    const captured = structuredClone(input);
    return this.serialized(async () => {
      const { run, scope, ocr, review, details, snapshots } = captured, active = this.requireActive(run.runId);
      for (const key of ['entryUrl', 'startedAt', 'ocrEnabled', 'ocrModel', 'aiEnabled', 'model', 'externalAnalysisConsent'] as const) if (run[key] !== active.run[key]) throw new ContractError('INVALID_REQUEST', 'Run identity must match the begun generation');
      validateRunSnapshotV2(run); if (['running', 'stopping'].includes(run.state) || !run.finishedAt) throw new ContractError('INVALID_REQUEST', 'Terminal run required');
      const result: OfficialResult = { meta: { topic: 'TOPIC', entry_url: run.entryUrl, started_at: run.startedAt, finished_at: run.finishedAt, elapsed_sec: run.elapsedSec,
        ...(captured.toolVersion === undefined ? {} : { tool_version: captured.toolVersion }) }, findings: captured.findings };
      const extraResult: ExtraResult = { meta: structuredClone(result.meta), findings: captured.extraFindings };
      validateResultPair(result, extraResult); validateOcrFile(ocr, true); validateReviewFileV2(review, ocr, true); validateFindingDetailsFileV2(details, result, extraResult, ocr, true);
      if ([ocr.runId, review.runId, details.runId].some(id => id !== run.runId) || run.counts.confirmedFindings !== result.findings.length || run.counts.extraConfirmedFindings !== extraResult.findings.length || run.counts.reviewCandidates !== review.candidates.length) throw new ContractError('INVALID_REQUEST', 'Artifact run IDs and counts must match');
      const evidence = new Map<string, Buffer>();
      for (const snapshot of snapshots) { validateEvidenceSnapshot(snapshot); safeId(snapshot.snapshotId); if (evidence.has(snapshot.snapshotId)) throw new ContractError('INVALID_REQUEST', 'Duplicate snapshot'); evidence.set(snapshot.snapshotId, encode(snapshot)); }
      for (const item of [...review.candidates, ...details.details]) {
        const bytes = evidence.get(item.evidence.snapshotId); if (!bytes || item.evidence.path !== null || item.evidence.sha256 !== null) throw new ContractError('INVALID_REQUEST', 'Supplied unstored DOM snapshot required');
        item.evidence = { snapshotId: item.evidence.snapshotId, path: `runs/${run.runId}/evidence/${item.evidence.snapshotId}.json`, sha256: hash(bytes) };
      }
      const images: Record<string, Asset> = {};
      for (const image of ocr.images) {
        if (!evidence.has(image.snapshotId)) throw new ContractError('INVALID_REQUEST', 'Image requires supplied DOM snapshot');
        for (const kind of ['original', 'input'] as const) {
          const reference = image[kind]; if (!reference) continue;
          const registered = active.images[reference.assetId];
          if (!registered || registered.kind !== kind || !encode(registered.reference).equals(encode(reference))) throw new ContractError('INVALID_REQUEST', 'Image assets must match actual registration');
          images[reference.assetId] = registered;
        }
        const prefix = image.framePath.length ? `${image.framePath.join(' >>> ')} >>> ` : '';
        image.styles = image.styles.map(style => ({ ...style, elementLocation: prefix && style.elementLocation.startsWith(prefix) ? style.elementLocation.slice(prefix.length) : style.elementLocation }));
      }
      if (!active.storageFailed && Object.keys(active.images).some(id => !Object.hasOwn(images, id))) throw new ContractError('INVALID_REQUEST', 'All registered image assets must remain referenced in OCR records');
      const preview = initialStatus(run, scope, ocr); validateScanStatusFileV2({ ...preview, run: { ...run, state: 'failed' } }, ocr);
      let archived = false, archivedManifest: Manifest | null = null, saved: SavedArtifactsV2 | null = null;
      const canonicalBefore = new Map<string, Buffer>(); let publishing = false;
      try {
        if (active.storageFailed) throw new OutputStorageErrorV2();
        await this.mkdir(`${active.staging}/evidence`);
        for (const [id, bytes] of evidence) await this.write(`${active.staging}/evidence/${id}.json`, bytes);
        await this.write(`${active.staging}/review.json`, encode(review)); await this.write(`${active.staging}/finding-details.json`, encode(details)); await this.write(`${active.staging}/ocr.json`, encode(ocr));
        if (options.finalizeTiming) { const timing = options.finalizeTiming(); const next = { ...run, finishedAt: timing.finishedAt, elapsedSec: timing.elapsedSec }; validateRunSnapshotV2(next); run.finishedAt = next.finishedAt; run.elapsedSec = next.elapsedSec; result.meta.finished_at = timing.finishedAt; result.meta.elapsed_sec = timing.elapsedSec; extraResult.meta = structuredClone(result.meta); }
        const prefix = `runs/${run.runId}`, rb = encode(result), eb = encode(extraResult);
        const status: ScanStatusFileV2 = { ...initialStatus(run, scope, ocr), resultSaved: true, extraResultSaved: true, files: { resultPath: `${prefix}/result.json`, resultSha256: hash(rb), extraResultPath: `${prefix}/result_extra.json`, extraResultSha256: hash(eb), reviewPath: `${prefix}/review.json`, findingDetailsPath: `${prefix}/finding-details.json`, ocrPath: `${prefix}/ocr.json`, evidenceDir: `${prefix}/evidence` } };
        validateScanStatusFileV2(status, ocr); saved = { result, extraResult, status, review, details, ocr };
        const files = { 'result.json': rb, 'result_extra.json': eb, 'review.json': encode(review), 'finding-details.json': encode(details), 'ocr.json': encode(ocr), 'scan-status.json': encode(status) };
        const manifest: Manifest = { schemaVersion: 2, runId: run.runId, files: Object.fromEntries(OUTPUT_FILE_NAMES_V2.map(n => [n, hash(files[n])])), evidence: Object.fromEntries([...evidence].map(([id, b]) => [id, hash(b)])), images };
        archivedManifest = manifest;
        await this.write(`${active.staging}/result.json`, rb); await this.write(`${active.staging}/result_extra.json`, eb); await this.write(`${active.staging}/scan-status.json`, files['scan-status.json']); await this.write(`${active.staging}/manifest.json`, encode(manifest));
        await this.verify(manifest, active.staging); await this.rename(active.staging, prefix); archived = true; await this.verify(manifest, prefix);
        for (const name of OUTPUT_FILE_NAMES_V2) { try { canonicalBefore.set(name, await this.read(name)); } catch (e) { if (!missing(e)) throw e; } }
        publishing = true;
        for (const name of OUTPUT_FILE_NAMES_V2) await this.writeAtomic(name, files[name]);
        await this.writeAtomic('latest.json', encode(manifest)); this.active = null; return structuredClone(saved);
      } catch {
        if (publishing) for (const name of OUTPUT_FILE_NAMES_V2) { try { const previous = canonicalBefore.get(name); if (previous) await this.writeAtomic(name, previous); else await this.remove(name); } catch { /* The unchanged latest marker still resolves only the previous archive. */ } }
        const failureStatus = initialStatus({ ...run, state: 'failed', activeUrls: [], errors: [...run.errors, storageError()] }, scope, ocr);
        if (archived && archivedManifest && saved) {
          try {
            const prefix = `runs/${run.runId}`;
            // Publication may fail after the earlier verification. Preserve claims only for the
            // original manifest and bytes that still verify now; never bless replaced hashes.
            if (!encode(archivedManifest).equals(await this.read(`${prefix}/manifest.json`))) throw new OutputStorageErrorV2();
            await this.verify(archivedManifest, prefix);
            failureStatus.files = saved.status.files; failureStatus.resultSaved = true; failureStatus.extraResultSaved = true;
          } catch { /* Keep the unverified archive for diagnostics, with no saved paths or hashes. */ }
        }
        this.failures.set(run.runId, failureStatus);
        try { await this.mkdir('run-failures'); await this.writeAtomic(`run-failures/${run.runId}.json`, encode(failureStatus)); } catch { /* Memory fallback reports unavailable storage. */ }
        if (!archived) { try { await this.remove(active.staging, true); } catch { /* Uncommitted staging is never served. */ } }
        this.active = null; throw new OutputStorageErrorV2(structuredClone(failureStatus));
      }
    });
  }
  async readFile(runId: string, name: OutputFileNameV2): Promise<Buffer> {
    safeId(runId); if (!OUTPUT_FILE_NAMES_V2.includes(name)) throw new ContractError('FORBIDDEN', 'Artifact name is not allowed');
    return this.serialized(async () => { const { manifest, files } = await this.load(runId); if (!Object.hasOwn(files, name)) throw new ContractError('NOT_FOUND', 'Artifact is not registered');
      if (name === 'scan-status.json' && manifest.schemaVersion === 2) { const failure = await this.failure(runId, files); if (failure) return encode(failure); } return files[name]; });
  }
  async readEvidence(runId: string, snapshotId: string): Promise<Buffer> {
    safeId(runId); safeId(snapshotId); return this.serialized(async () => { const { manifest } = await this.load(runId); if (!Object.hasOwn(manifest.evidence, snapshotId)) throw new ContractError('NOT_FOUND', 'Snapshot is not registered'); return this.read(`runs/${runId}/evidence/${snapshotId}.json`); });
  }
  async readImage(runId: string, assetId: string): Promise<Buffer> {
    safeId(runId); safeId(assetId);
    return this.serialized(async () => {
      if (this.active?.run.runId === runId) return this.readRegisteredInput(runId, assetId, this.active.images[assetId], this.active.staging);
      const { manifest } = await this.load(runId);
      return this.readRegisteredInput(runId, assetId, manifest.images?.[assetId], `runs/${runId}`);
    });
  }
  /** Preview resolves only output's private registry, never a caller-supplied path or the collector's scratch file. */
  private async readRegisteredInput(runId: string, assetId: string, asset: Asset | undefined, prefix: string): Promise<Buffer> {
    if (!asset || asset.kind !== 'input' || asset.reference.mime !== 'image/png') throw new ContractError('NOT_FOUND', 'PNG input is not registered');
    try {
      const reference = asset.reference as ImageInputReference;
      if (reference.assetId !== assetId || reference.path !== `runs/${runId}/images/${assetId}.png` || reference.frameIndex !== 0) throw new OutputStorageErrorV2();
      const bytes = await this.readBounded(await this.checkedPath(`${prefix}/images/${assetId}.png`), this.maxImageBytes);
      const dimensions = this.pngDimensions(bytes);
      if (bytes.length !== reference.byteLength || hash(bytes) !== reference.sha256 || dimensions.width !== reference.width || dimensions.height !== reference.height) throw new OutputStorageErrorV2();
      return bytes;
    } catch { throw new OutputStorageErrorV2(); }
  }
  async readLatest(): Promise<SavedArtifactsV2 | SavedArtifacts | null> {
    return this.serialized(async () => { let bytes: Buffer; try { bytes = await this.read('latest.json'); } catch (e) { if (missing(e)) return null; throw new OutputStorageErrorV2(); }
      const marker = JSON.parse(bytes.toString()) as Manifest; safeId(marker.runId); const { manifest, files } = await this.load(marker.runId); if (!encode(marker).equals(encode(manifest))) throw new OutputStorageErrorV2(); return this.decode(manifest, files); });
  }
  private async load(runId: string): Promise<{ manifest: Manifest; files: Record<string, Buffer> }> {
    try { const manifest = JSON.parse((await this.read(`runs/${runId}/manifest.json`)).toString()) as Manifest; if (manifest.runId !== runId) throw new OutputStorageErrorV2(); const files = await this.verify(manifest, `runs/${runId}`); return { manifest, files }; }
    catch (e) { if (missing(e)) throw new ContractError('NOT_FOUND', 'Run artifacts are not registered'); if (e instanceof ContractError) throw e; throw new OutputStorageErrorV2(); }
  }
  private async failure(runId: string, files: Record<string, Buffer>): Promise<ScanStatusFileV2 | null> {
    let status = this.failures.get(runId); if (!status) { try { status = JSON.parse((await this.read(`run-failures/${runId}.json`)).toString()); } catch (e) { if (!missing(e)) throw new OutputStorageErrorV2(); } }
    if (!status) return null; validateScanStatusFileV2(status, JSON.parse(files['ocr.json'].toString()));
    const original = JSON.parse(files['scan-status.json'].toString()) as ScanStatusFileV2;
    if (status.run.runId !== runId || status.run.state !== 'failed' || !encode(status.files).equals(encode(original.files))) throw new OutputStorageErrorV2(); return status;
  }
  private decode(manifest: Manifest, files: Record<string, Buffer>): SavedArtifactsV2 | SavedArtifacts {
    const result = JSON.parse(files['result.json'].toString()), status = JSON.parse(files['scan-status.json'].toString()), review = JSON.parse(files['review.json'].toString()), details = JSON.parse(files['finding-details.json'].toString());
    validateOfficialResult(result);
    if (manifest.schemaVersion === 1) { validateScanStatusFile(status); validateReviewFile(review, true); validateFindingDetailsFile(details, result, true); }
    else { const extraResult = JSON.parse(files['result_extra.json'].toString()), ocr = JSON.parse(files['ocr.json'].toString()); validateResultPair(result, extraResult); validateOcrFile(ocr, true); validateScanStatusFileV2(status, ocr); validateReviewFileV2(review, ocr, true); validateFindingDetailsFileV2(details, result, extraResult, ocr, true); if (ocr.runId !== manifest.runId || status.run.counts.extraConfirmedFindings !== extraResult.findings.length) throw new OutputStorageErrorV2();
      this.validateDecodedIdentity(manifest, result, status, review, details, files); return { result, extraResult, status, review, details, ocr }; }
    this.validateDecodedIdentity(manifest, result, status, review, details, files); return { result, status, review, details };
  }
  private validateDecodedIdentity(manifest: Manifest, result: OfficialResult, status: SavedArtifacts['status'] | ScanStatusFileV2, review: SavedArtifacts['review'] | ReviewFileV2, details: SavedArtifacts['details'] | FindingDetailsFileV2, files: Record<string, Buffer>): void {
    if ([status.run.runId, review.runId, details.runId].some(id => id !== manifest.runId) || !status.resultSaved || status.files.resultSha256 !== hash(files['result.json']) || result.meta.entry_url !== status.run.entryUrl || result.meta.started_at !== status.run.startedAt || result.meta.finished_at !== status.run.finishedAt || result.meta.elapsed_sec !== status.run.elapsedSec || status.run.counts.confirmedFindings !== result.findings.length || status.run.counts.reviewCandidates !== review.candidates.length) throw new OutputStorageErrorV2();
    for (const item of [...review.candidates, ...details.details]) if (item.evidence.path !== `runs/${manifest.runId}/evidence/${item.evidence.snapshotId}.json` || item.evidence.sha256 !== manifest.evidence[item.evidence.snapshotId]) throw new OutputStorageErrorV2();
  }
  private async verify(manifest: Manifest, prefix: string): Promise<Record<string, Buffer>> {
    safeId(manifest.runId); if (![1, 2].includes(manifest.schemaVersion)) throw new OutputStorageErrorV2();
    const names = manifest.schemaVersion === 2 ? OUTPUT_FILE_NAMES_V2 : ['result.json', 'review.json', 'finding-details.json', 'scan-status.json'];
    if (!manifest.files || Object.keys(manifest.files).length !== names.length || names.some(n => !/^[a-f0-9]{64}$/.test(manifest.files[n]))) throw new OutputStorageErrorV2();
    const files: Record<string, Buffer> = {};
    for (const n of names) { const bytes = await this.read(`${prefix}/${n}`); if (hash(bytes) !== manifest.files[n]) throw new OutputStorageErrorV2(); files[n] = bytes; }
    for (const [id, sha] of Object.entries(manifest.evidence)) { safeId(id); const bytes = await this.read(`${prefix}/evidence/${id}.json`); if (hash(bytes) !== sha) throw new OutputStorageErrorV2(); validateEvidenceSnapshot(JSON.parse(bytes.toString())); }
    if (manifest.schemaVersion === 2) {
      const ocr = JSON.parse(files['ocr.json'].toString()) as OcrFile;
      const refs = ocr.images.flatMap(i => [i.original, i.input]).filter(r => r !== null);
      if (!manifest.images || new Set(refs.map(r => r.assetId)).size !== Object.keys(manifest.images).length) throw new OutputStorageErrorV2();
      for (const [id, asset] of Object.entries(manifest.images)) { safeId(id); const r = asset.reference; const ext = asset.kind === 'input' ? 'png' : 'bin';
        if (!['original', 'input'].includes(asset.kind) || r.assetId !== id || r.path !== `runs/${manifest.runId}/images/${id}.${ext}` || !refs.some(ref => encode(ref).equals(encode(r)))) throw new OutputStorageErrorV2();
        const b = await this.readBounded(await this.checkedPath(`${prefix}/images/${id}.${ext}`), this.maxImageBytes); if (b.length !== r.byteLength || hash(b) !== r.sha256) throw new OutputStorageErrorV2();
        if (asset.kind === 'input') { const dims = this.pngDimensions(b); const input = r as ImageInputReference; if (r.mime !== 'image/png' || dims.width !== input.width || dims.height !== input.height) throw new OutputStorageErrorV2(); }
      }
    }
    this.decode(manifest, files); return files;
  }
  private pngDimensions(bytes: Buffer): { width: number; height: number } {
    if (bytes.length < 33 || !bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])) || bytes.readUInt32BE(8) !== 13 || bytes.toString('ascii', 12, 16) !== 'IHDR') throw new OutputStorageErrorV2();
    let offset = 8, idat = false, ended = false;
    while (offset + 12 <= bytes.length) { const length = bytes.readUInt32BE(offset), type = bytes.toString('ascii', offset + 4, offset + 8);
      if (length > bytes.length - offset - 12) throw new OutputStorageErrorV2();
      if (type === 'IDAT') idat = true;
      offset += length + 12; if (type === 'IEND') { if (length !== 0) throw new OutputStorageErrorV2(); ended = true; break; }
    }
    if (!idat || !ended || offset !== bytes.length) throw new OutputStorageErrorV2();
    const width = bytes.readUInt32BE(16), height = bytes.readUInt32BE(20); if (!width || !height || width > this.maxImagePixels / height) throw new OutputStorageErrorV2(); return { width, height };
  }
  private async rejectSymlinkAncestors(target: string): Promise<void> { let cursor = resolve(target); while (true) { try { if ((await fs.lstat(cursor)).isSymbolicLink()) throw new OutputStorageErrorV2(); } catch (e) { if (!missing(e)) throw e; } if (cursor === parse(cursor).root) break; cursor = dirname(cursor); } }
  private async initializeRoot(): Promise<void> { await this.rejectSymlinkAncestors(this.outputRoot); await this.before('mkdir', ''); await fs.mkdir(this.outputRoot, { recursive: true, mode: 0o700 }); if (await fs.realpath(this.outputRoot) !== this.outputRoot) throw new OutputStorageErrorV2(); }
  private async checkedPath(path: string): Promise<string> { const target = resolve(this.outputRoot, path), rel = relative(this.outputRoot, target); if (rel === '..' || rel.startsWith(`..${sep}`) || isAbsolute(rel)) throw new OutputStorageErrorV2(); await this.rejectSymlinkAncestors(target); return target; }
  private async readBounded(path: string, maximum: number): Promise<Buffer> { const file = await fs.open(path, constants.O_RDONLY | constants.O_NOFOLLOW); try { const s = await file.stat(); if (!s.isFile() || s.size <= 0 || s.size > maximum) throw new OutputStorageErrorV2(); const bytes = Buffer.alloc(s.size); let offset = 0; while (offset < bytes.length) { const r = await file.read(bytes, offset, bytes.length - offset, offset); if (!r.bytesRead) throw new OutputStorageErrorV2(); offset += r.bytesRead; } const end = await file.stat(); if (end.size !== s.size || end.mtimeMs !== s.mtimeMs) throw new OutputStorageErrorV2(); return bytes; } finally { await file.close(); } }
  private async read(path: string): Promise<Buffer> { return this.readBounded(await this.checkedPath(path), Number.MAX_SAFE_INTEGER); }
  private async before(operation: OutputOperation['operation'], path: string): Promise<void> { await this.options.beforeOperation?.({ operation, path }); }
  private async mkdir(path: string): Promise<void> { const target = await this.checkedPath(path); await this.before('mkdir', path); await fs.mkdir(target, { recursive: true, mode: 0o700 }); }
  private async write(path: string, bytes: Buffer): Promise<void> { const target = await this.checkedPath(path); await this.before('write', path); await fs.writeFile(target, bytes, { flag: 'wx', mode: 0o600 }); }
  private async rename(from: string, to: string): Promise<void> { const a = await this.checkedPath(from), b = await this.checkedPath(to); await this.before('rename', to); await fs.rename(a, b); }
  private async remove(path: string, recursive = false): Promise<void> { const target = await this.checkedPath(path); await this.before('remove', path); await fs.rm(target, { recursive, force: true }); }
  private async writeAtomic(path: string, bytes: Buffer): Promise<void> { const tmp = `${path}.tmp-${randomUUID()}`; try { await this.write(tmp, bytes); await this.rename(tmp, path); } finally { try { await this.remove(tmp); } catch { /* Unpublished temporary files are never served. */ } } }
}
