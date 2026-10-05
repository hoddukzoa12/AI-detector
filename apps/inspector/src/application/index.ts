import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { analyzeCandidate, type AnalyzeOptions } from '../classification/index.js';
import { crawl, CRAWL_DEFAULTS, type CrawlOptions } from '../crawler/index.js';
import { detectPage, detectImageCandidates, normalizeText } from '../detection/index.js';
import { OutputStoreV2, OutputStorageErrorV2, type OutputFileNameV2 } from '../output/index.js';
import { RunRegistryV2, ContractError, classifyAiAnalysis, createAiAnalysis, isTerminalState,
  validateStartRunRequestV2, type AiAnalysis, type DetectionCandidateV2, type EvidenceSnapshot,
  type FindingDetailsFileV2, type FindingsResponse, type OfficialFinding, type OfficialResult, type PublicConfigV2, type ReviewCandidateV2,
  type ReviewFileV2, type RunErrorV2, type RunSnapshotV2, type ScanStatusFileV2, type StartRunRequestV2 } from '../core/index.js';
import { OcrRunSession, OCR_PROMPT_VERSION, emptyOcrUsage, type OcrSessionOptions } from '../ocr/index.js';
import { DEFAULT_ANALYSIS_LIMITS, countImages, hasIncompleteOcrWork, imageOwnerKey, imageReviewReasons, selectReviewReason, sanitizeAnalysisErrorMessage, type AnalysisLimits, type CollectedImageOccurrence, type OcrFile, type ExtraFinding, type ExtraResult, type ExtraFindingsResponse } from '../core/index.js';
import type { CollectedPageWithImages, ImageAcquisitionResult, ImageCollectionOptions } from '../crawler/index.js';
import { publicConfig } from './config.js';
export * from './config.js';
export interface ApplicationOptions {
  outputRoot?: string; apiKey?: string; executablePath?: string; crawlOptions?: Omit<CrawlOptions, 'signal' | 'onPage' | 'onProgress' | 'images'>;
  maxDurationMs?: number; aiConcurrency?: number; maxAiCandidates?: number; maxAiPending?: number; maxAiRequests?: number; aiOptions?: Omit<AnalyzeOptions, 'normalize' | 'onProgress' | 'reserveRequest' | 'onRequestStart'>;
  limits?: Partial<AnalysisLimits>; ocrOptions?: Omit<OcrSessionOptions, 'runId' | 'enabled' | 'apiKey' | 'deadline' | 'onProgress' | 'onRequestStart'>;
  imageOptions?: Omit<ImageCollectionOptions, 'enabled' | 'onImage'>;
  /** Local dependency injection only; the production classifier has a fixed CLEF endpoint. */
  crawl?: typeof crawl; analyzeCandidate?: typeof analyzeCandidate; outputStore?: OutputStoreV2;
}
interface Execution {
  run: RunSnapshotV2; scope: ScanStatusFileV2['scope']; extraFindings: ExtraFinding[]; ocr: OcrFile; owners: Map<string, CollectedImageOccurrence>; processedImages: Set<string>; links: Map<string, string[]>; ocrSession: OcrRunSession; deadline: number; controller: AbortController; findings: OfficialFinding[];
  review: Map<string, ReviewCandidateV2>; details: FindingDetailsFileV2; snapshots: Map<string, EvidenceSnapshot>;
  candidates: Set<string>; errors: RunErrorV2[]; crawlerErrors: RunErrorV2[]; work: Set<Promise<void>>;
  finalizing: boolean; fatalError: boolean; done: Promise<RunSnapshotV2>; savedStatus?: ScanStatusFileV2; aiScheduled: number; aiRequests: number; aiProgress: Map<string, AiAnalysis>; aiActive: number; aiWaiters: (() => void)[];
}
function positive(value: number, name: string): number {
  if (!Number.isSafeInteger(value) || value < 1) throw new ContractError('INVALID_CONFIG', `Invalid ${name}`); return value;
}
function pendingAnalysis(candidate: DetectionCandidateV2, reason: 'USER_CANCELLED' | 'RESOURCE_LIMIT' | 'TIME_LIMIT' | null = null): AiAnalysis {
  return createAiAnalysis([{ chunkId: 'chunk-0', rawStart: 0, rawEnd: candidate.rawText.length,
    status: 'not_started', choice: null, probabilities: null, confidence: null, reasonCode: reason }]);
}
/** Coordinates a single active execution and reserves finalization before any terminal state is exposed. */
export class InspectorApplication {
  readonly store: OutputStoreV2;
  private readonly registry = new RunRegistryV2();
  private readonly executions = new Map<string, Execution>();
  private readonly apiKey: string;
  private readonly duration: number;
  private readonly maxCandidates: number;
  private readonly maxRequests: number;
  private readonly concurrency: number;
  private readonly limits: AnalysisLimits;
  private readonly maxPending: number;
  constructor(private readonly options: ApplicationOptions = {}) {
    this.apiKey = options.apiKey ?? '';
    this.store = options.outputStore ?? new OutputStoreV2(options.outputRoot ?? resolve(process.cwd(), 'output'), { maxImageBytes: options.limits?.maxImageBytes ?? options.ocrOptions?.maxImageBytes ?? options.imageOptions?.maxImageBytes, maxImagePixels: options.limits?.maxImagePixels ?? options.ocrOptions?.maxImagePixels ?? options.imageOptions?.maxImagePixels });
    this.duration = positive(options.maxDurationMs ?? options.crawlOptions?.maxDurationMs ?? CRAWL_DEFAULTS.maxDurationMs, 'work duration');
    this.concurrency = positive(options.aiConcurrency ?? 2, 'AI concurrency');
    if (this.concurrency > 32) throw new ContractError('INVALID_CONFIG', 'AI concurrency exceeds 32');
    this.maxPending = positive(options.maxAiPending ?? 100, 'CLEF pending queue');
    this.maxCandidates = positive(options.maxAiCandidates ?? 10000, 'AI candidate limit');
    this.maxRequests = positive(options.limits?.maxClefRequests ?? options.maxAiRequests ?? 1000, 'AI request limit');
    this.limits = { ...DEFAULT_ANALYSIS_LIMITS, ...options.limits, maxClefRequests: this.maxRequests, maxOcrRequests: options.limits?.maxOcrRequests ?? options.ocrOptions?.maxRequests ?? DEFAULT_ANALYSIS_LIMITS.maxOcrRequests, maxImageBytes: options.limits?.maxImageBytes ?? options.ocrOptions?.maxImageBytes ?? options.imageOptions?.maxImageBytes ?? DEFAULT_ANALYSIS_LIMITS.maxImageBytes, maxImagePixels: options.limits?.maxImagePixels ?? options.ocrOptions?.maxImagePixels ?? options.imageOptions?.maxImagePixels ?? DEFAULT_ANALYSIS_LIMITS.maxImagePixels };
    for (const [key, value] of Object.entries(this.limits)) positive(value, key);
    // Validate all OCR settings before start allocates the active run slot. No requests are made here.
    new OcrRunSession({ ...options.ocrOptions, runId: 'configuration-validation', enabled: false, apiKey: '', maxRequests: this.limits.maxOcrRequests, maxImageBytes: this.limits.maxImageBytes, maxImagePixels: this.limits.maxImagePixels });
    if (this.duration > 2_147_483_647 || this.maxCandidates > 100000 || this.maxRequests > 100000) throw new ContractError('INVALID_CONFIG', 'Runtime work limit exceeds supported bounds');
  }
  get config(): PublicConfigV2 { return publicConfig({ apiKey: this.apiKey, outputRoot: this.store.outputRoot, limits: this.limits }); }
  get activeRunId(): string | null { return this.registry.activeRunId; }
  start(input: StartRunRequestV2): RunSnapshotV2 {
    validateStartRunRequestV2(input);
    const handle = this.registry.start({ ...input, apiKey: this.apiKey });
    const run = handle.snapshot;
    const state: Execution = { run, scope: { hostname: new URL(run.entryUrl).hostname, framePolicy: 'embedded', skipped: [], unvisitedUrls: [] },
      controller: new AbortController(), findings: [], review: new Map(), details: { schemaVersion: 2, runId: run.runId, details: [] },
      snapshots: new Map(), candidates: new Set(), errors: [], crawlerErrors: [], work: new Set(), finalizing: false, fatalError: false,
      extraFindings: [], ocr: { schemaVersion: 2, runId: run.runId, enabled: run.ocrEnabled, model: run.ocrModel, images: [] }, owners: new Map(), processedImages: new Set(), links: new Map(), deadline: Date.now() + this.duration, ocrSession: null! ,
      done: Promise.resolve(run), aiScheduled: 0, aiRequests: 0, aiProgress: new Map(), aiActive: 0, aiWaiters: [] };
    state.ocrSession = new OcrRunSession({ ...this.options.ocrOptions, runId: run.runId, enabled: run.ocrEnabled, apiKey: this.apiKey, deadline: state.deadline, maxRequests: this.limits.maxOcrRequests, maxImageBytes: this.limits.maxImageBytes, maxImagePixels: this.limits.maxImagePixels,
      fetch: (...args) => { state.run.requestCounts.ocr++; this.refresh(state); return (this.options.ocrOptions?.fetch ?? fetch)(...args); },
      onProgress: ({ imageId, analysis }) => { if (state.finalizing || isTerminalState(state.run.state)) return; const record = state.ocr.images.find(image => image.imageId === imageId); if (record && (!state.controller.signal.aborted || !['completed', 'error'].includes(analysis.status))) { Object.assign(record, structuredClone(analysis)); this.refresh(state); } } });
    handle.signal.addEventListener('abort', () => state.controller.abort('USER_CANCELLED'), { once: true });
    this.executions.set(run.runId, state);
    state.done = Promise.resolve().then(() => this.execute(state));
    return structuredClone(run);
  }
  get(runId: string): RunSnapshotV2 {
    const state = this.require(runId); const run = structuredClone(state.run);
    if (!isTerminalState(run.state)) run.elapsedSec = Math.max(0, (Date.now() - Date.parse(run.startedAt)) / 1000);
    return run;
  }
  findings(runId: string): FindingsResponse { return { runId, findings: structuredClone(this.require(runId).findings) }; }
  details(runId: string): FindingDetailsFileV2 { return structuredClone(this.require(runId).details); }
  review(runId: string): ReviewFileV2 { return { schemaVersion: 2, runId, candidates: structuredClone([...this.require(runId).review.values()]) }; }
  wait(runId: string): Promise<RunSnapshotV2> { return this.require(runId).done.then(run => structuredClone(run)); }
  async cancel(runId: string): Promise<RunSnapshotV2> {
    const state = this.require(runId);
    if (state.finalizing) return this.wait(runId);
    if (!isTerminalState(state.run.state)) {
      this.registry.requestCancel(runId); state.run.state = 'stopping';
    }
    return this.get(runId);
  }
  async close(): Promise<void> { const id = this.activeRunId; if (id) { await this.cancel(id); await this.wait(id); } }
  async readFile(runId: string, name: OutputFileNameV2): Promise<Buffer> {
    const state = this.require(runId);
    if (name === 'scan-status.json' && state.savedStatus && !state.savedStatus.resultSaved) return Buffer.from(JSON.stringify(state.savedStatus));
    return this.store.readFile(runId, name);
  }
  async readEvidence(runId: string, snapshotId: string): Promise<Buffer> {
    this.require(runId); return this.store.readEvidence(runId, snapshotId);
  }
  extraFindings(runId: string): ExtraFindingsResponse { return { runId, findings: structuredClone(this.require(runId).extraFindings) }; }
  ocr(runId: string): OcrFile { return structuredClone(this.require(runId).ocr); }
  relatedLinks(runId: string): { runId: string; candidates: { candidateId: string; links: string[] }[] } {
    return { runId, candidates: [...this.require(runId).links].map(([candidateId, links]) => ({ candidateId, links: [...links] })) };
  }
  async readImage(runId: string, assetId: string): Promise<Buffer> { this.require(runId); return this.store.readImage(runId, assetId); }
  private discoverImage(state: Execution, owner: CollectedImageOccurrence): void {
    if (state.owners.has(owner.imageId)) return;
    const { selectedUrl: _selected, links: _links, bounds: _bounds, documentBounds: _document, ...identity } = structuredClone(owner);
    state.owners.set(owner.imageId, structuredClone(owner));
    state.ocr.images.push({ ...identity, original: null, input: null, capturedAt: null, status: state.run.ocrEnabled ? 'discovered' : 'not_selected',
      extractionStatus: null, text: null, confidence: null, model: state.run.ocrModel, promptVersion: OCR_PROMPT_VERSION, cacheOf: null,
      attemptCount: 0, usage: emptyOcrUsage(), reasonCode: state.run.ocrEnabled ? null : 'OCR_NOT_SELECTED' });
  }
  private registerCandidate(state: Execution, candidate: DetectionCandidateV2): void {
    state.candidates.add(candidate.candidateId); state.links.set(candidate.candidateId, [...candidate.links]);
    this.setReview(state, candidate, candidate.rawText ? pendingAnalysis(candidate) : null);
  }
  private setReview(state: Execution, candidate: DetectionCandidateV2, ai: AiAnalysis | null): void {
    const reasons = candidate.sourceType === 'image_ocr' ? imageReviewReasons(state.ocr.images.filter(image => candidate.sourceIds.includes(image.imageId))) : [];
    if (ai) { const reason = classifyAiAnalysis(ai).reason; if (reason === 'AI_ERROR' || reason === 'NOT_ANALYZED' || reason === 'UNCERTAIN') reasons.push(reason); }
    else if (candidate.sourceType === 'dom_text') reasons.push('NOT_ANALYZED');
    const reason = selectReviewReason(reasons);
    if (reason) state.review.set(candidate.candidateId, this.reviewItem(candidate, reason, ai));
    else state.review.delete(candidate.candidateId);
  }
  private async image(state: Execution, owner: CollectedImageOccurrence, result: ImageAcquisitionResult): Promise<void> {
    if (state.finalizing || isTerminalState(state.run.state) || !state.owners.has(owner.imageId)) return;
    const record = state.ocr.images.find(image => image.imageId === owner.imageId)!;
    if (state.processedImages.has(owner.imageId) || !['discovered', 'captured'].includes(record.status)) return;
    state.processedImages.add(owner.imageId);
    if (result.status === 'captured' || result.original) record.imageUrl = owner.imageUrl;
    try {
      if (result.status === 'captured') {
        const registered = await this.store.registerImageAssets(state.run.runId, result.assets);
        Object.assign(record, registered, { capturedAt: result.assets.capturedAt, status: 'captured' }); this.refresh(state);
        Object.assign(record, await state.ocrSession.analyzeImage(owner.imageId, result.assets.input, state.controller.signal));
        // Only the run request cap/deadline halts all work. An individual image cap remains local.
        if (record.reasonCode === 'TIME_LIMIT') state.controller.abort('TIME_LIMIT');
        if (record.reasonCode === 'RESOURCE_LIMIT' && state.ocrSession.requestCount >= this.limits.maxOcrRequests) state.controller.abort('RESOURCE_LIMIT');
      } else {
        if (result.original && result.capturedAt) {
          record.original = await this.store.registerOriginalAsset(state.run.runId, result.original); record.capturedAt = result.capturedAt;
        }
        record.status = ['RESOURCE_LIMIT', 'TIME_LIMIT', 'USER_CANCELLED'].includes(result.reasonCode) ? 'not_started' : result.status;
        record.reasonCode = result.reasonCode;
      }
    } catch (error) {
      if (error instanceof OutputStorageErrorV2) this.addError(state, error.runError);
      else this.addError(state, { scope: 'storage', code: 'STORAGE_ERROR', url: owner.url, candidateId: null, message: 'Unable to register image evidence' });
      record.status = 'not_started'; record.reasonCode = 'RESOURCE_LIMIT';
      state.controller.abort('RESOURCE_LIMIT');
    }
    if (record.reasonCode && !['USER_CANCELLED', 'OCR_NOT_SELECTED'].includes(record.reasonCode)) this.addError(state, {
      scope: record.reasonCode.startsWith('OCR_') ? 'ocr' : record.reasonCode === 'RESOURCE_LIMIT' || record.reasonCode === 'TIME_LIMIT' ? 'limit' : 'image',
      code: record.reasonCode as RunErrorV2['code'], url: owner.url, candidateId: null, message: `Image analysis: ${record.reasonCode}` });
    this.refresh(state);
    await this.imageGroups(state, imageOwnerKey(owner));
  }
  private async imageGroups(state: Execution, key?: string): Promise<void> {
    const images = key ? state.ocr.images.filter(image => imageOwnerKey(image) === key) : state.ocr.images;
    for (const candidate of detectImageCandidates(images, [...state.owners.values()])) {
      if (state.candidates.has(candidate.candidateId)) continue;
      if (candidate.sourceIds.some(id => ['discovered', 'captured', 'running'].includes(state.ocr.images.find(image => image.imageId === id)!.status))) continue;
      this.registerCandidate(state, candidate);
      if (candidate.rawText) await this.analyze(state, candidate);
    }
  }
  private async finishImages(state: Execution): Promise<void> {
    for (const image of state.ocr.images) if (['discovered', 'captured', 'running'].includes(image.status)) {
      image.status = image.attemptCount ? 'cancelled' : 'not_started';
      image.reasonCode = state.controller.signal.reason === 'TIME_LIMIT' ? 'TIME_LIMIT' : state.controller.signal.reason === 'RESOURCE_LIMIT' ? 'RESOURCE_LIMIT' : state.controller.signal.aborted ? 'USER_CANCELLED' : 'RESOURCE_LIMIT';
    }
    await this.imageGroups(state); this.refresh(state);
  }
  private require(runId: string): Execution {
    const state = this.executions.get(runId); if (!state) throw new ContractError('NOT_FOUND', 'Run not found'); return state;
  }
  private addError(state: Execution, error: RunErrorV2): void {
    error = { ...error, message: sanitizeAnalysisErrorMessage(error.message, [this.apiKey]) };
    if (!state.errors.some(item => JSON.stringify(item) === JSON.stringify(error))) state.errors.push(error);
    this.refresh(state);
  }
  private refresh(state: Execution): void {
    state.run.imageCounts = countImages(state.ocr.images); state.run.counts.extraConfirmedFindings = state.extraFindings.length;
    state.run.counts.confirmedFindings = state.findings.length; state.run.counts.reviewCandidates = state.review.size;
    state.run.errors = structuredClone([...state.crawlerErrors, ...state.errors]).map(error => ({ ...error, message: sanitizeAnalysisErrorMessage(error.message, [this.apiKey]) }));
    if (state.run.state === 'running') this.registry.update(state.run.runId, { counts: state.run.counts, imageCounts: state.run.imageCounts, requestCounts: state.run.requestCounts, activeUrls: state.run.activeUrls, errors: state.run.errors });
  }
  private confirm(state: Execution, candidate: DetectionCandidateV2, ai: AiAnalysis): void {
    const base = { candidateId: candidate.candidateId, decisionSource: 'clef' as const, ruleIds: [], ai: structuredClone(ai), evidence: structuredClone(candidate.evidence), sourceType: candidate.sourceType, sourceIds: [...candidate.sourceIds], sourceTextRanges: structuredClone(candidate.sourceTextRanges), observationIds: [...candidate.observationIds] };
    if (candidate.sourceType === 'image_ocr') {
      const id = `extra_${createHash('sha256').update(JSON.stringify([candidate.url, candidate.location, 'ETC', 'IMAGE_AD_OCR'])).digest('hex')}`;
      if (!state.extraFindings.some(item => item.id === id)) {
        state.extraFindings.push({ id, url: candidate.url, location: candidate.location, evidence_text: candidate.rawText, is_violation: true, technique: 'ETC', extra_finding: 'IMAGE_AD_OCR' });
        state.details.details.push({ ...base, findingId: id, resultFile: 'result_extra.json' });
      } return;
    }
    for (const technique of candidate.techniques) {
      const id = `finding_${createHash('sha256').update(JSON.stringify([candidate.url, candidate.location, technique])).digest('hex')}`;
      if (state.findings.some(item => item.id === id)) continue;
      state.findings.push({ id, url: candidate.url, is_violation: true, location: candidate.location, evidence_text: candidate.rawText, technique });
      state.details.details.push({ ...base, findingId: id, resultFile: 'result.json' });
    }
  }
  /** Accepted completed chunks are immutable, including their ranges and probabilities. */
  private mergeAccepted(previous: AiAnalysis | undefined, incoming: AiAnalysis): AiAnalysis {
    if (!previous) return createAiAnalysis(incoming.chunks);
    const chunks = previous.chunks.map(chunk => chunk.status === 'completed' ? chunk :
      incoming.chunks.find(next => next.chunkId === chunk.chunkId && next.rawStart === chunk.rawStart && next.rawEnd === chunk.rawEnd) ?? chunk);
    chunks.push(...incoming.chunks.filter(chunk => !previous.chunks.some(known => known.chunkId === chunk.chunkId)));
    return createAiAnalysis(chunks);
  }
  private terminalAnalysis(state: Execution, candidate: DetectionCandidateV2, incoming?: AiAnalysis, failed = false): AiAnalysis {
    const previous = state.aiProgress.get(candidate.candidateId);
    const signal = state.controller.signal;
    const reason = signal.aborted ? signal.reason === 'TIME_LIMIT' ? 'TIME_LIMIT' : signal.reason === 'RESOURCE_LIMIT' ? 'RESOURCE_LIMIT' : 'USER_CANCELLED' : 'AI_HTTP_ERROR';
    // Responses received after abort cannot complete ranges that were still pending at cancellation.
    const known = signal.aborted || failed ? previous : incoming ? this.mergeAccepted(previous, incoming) : previous;
    if (!known) return signal.aborted ? pendingAnalysis(candidate, reason as 'USER_CANCELLED' | 'TIME_LIMIT' | 'RESOURCE_LIMIT') : createAiAnalysis([
      { chunkId: 'chunk-0', rawStart: 0, rawEnd: candidate.rawText.length, status: 'error', choice: null, probabilities: null, confidence: null, reasonCode: 'AI_HTTP_ERROR' },
    ]);
    return createAiAnalysis(known.chunks.map(chunk => {
      if (!['pending', 'running'].includes(chunk.status)) return chunk;
      // A synchronous running observer can stop the producer before it invokes transport.
      const unrequested = incoming?.chunks.some(final => final.chunkId === chunk.chunkId && final.rawStart === chunk.rawStart && final.rawEnd === chunk.rawEnd && final.status === 'not_started');
      const status = !signal.aborted ? 'error' : chunk.status === 'running' && !unrequested ? 'cancelled' : 'not_started';
      return { ...chunk, status, choice: null, probabilities: null, confidence: null, reasonCode: reason };
    }));
  }
  private aiProgress(state: Execution, candidate: DetectionCandidateV2, incoming: AiAnalysis): void {
    if (state.run.state !== 'running' || state.controller.signal.aborted || state.finalizing) return;
    const ai = this.mergeAccepted(state.aiProgress.get(candidate.candidateId), incoming);
    state.aiProgress.set(candidate.candidateId, ai);
    const decision = classifyAiAnalysis(ai);
    if (decision.confirmed) this.confirm(state, candidate, ai);
    this.updateDetails(state, candidate, ai);
    this.setReview(state, candidate, ai);
    this.refresh(state);
  }
  private updateDetails(state: Execution, candidate: DetectionCandidateV2, ai: AiAnalysis): void {
    if (!classifyAiAnalysis(ai).confirmed) return;
    for (const detail of state.details.details) if (detail.candidateId === candidate.candidateId) detail.ai = structuredClone(ai);
  }
  private reviewItem(candidate: DetectionCandidateV2, reason: ReviewCandidateV2['reason'], ai: AiAnalysis | null): ReviewCandidateV2 {
    return { candidateId: candidate.candidateId, url: candidate.url, location: candidate.location, evidenceText: candidate.rawText,
      sourceType: candidate.sourceType, sourceIds: [...candidate.sourceIds], sourceTextRanges: structuredClone(candidate.sourceTextRanges), techniques: [...candidate.techniques], reason, ai: structuredClone(ai), evidence: structuredClone(candidate.evidence) };
  }
  private async acquireAi(state: Execution): Promise<(() => void) | null> {
    while (state.aiActive >= this.concurrency && !state.controller.signal.aborted) {
      if (state.aiWaiters.length >= this.maxPending) { state.controller.abort('RESOURCE_LIMIT'); return null; }
      await new Promise<void>(resolve => {
        const wake = () => { state.controller.signal.removeEventListener('abort', wake); const index = state.aiWaiters.indexOf(wake); if (index >= 0) state.aiWaiters.splice(index, 1); resolve(); };
        state.aiWaiters.push(wake); state.controller.signal.addEventListener('abort', wake, { once: true });
      });
    }
    if (state.controller.signal.aborted) return null;
    state.aiActive++; return () => { state.aiActive--; state.aiWaiters.shift()?.(); };
  }
  /** Give the classifier time to return real abort chunks, then detach an uncooperative transport. */
  private async boundedAnalysis(state: Execution, candidate: DetectionCandidateV2, operation: Promise<AiAnalysis>): Promise<AiAnalysis> {
    const signal = state.controller.signal; let timer: ReturnType<typeof setTimeout> | undefined;
    let aborted = () => {};
    const stopped = new Promise<AiAnalysis>(resolve => {
      aborted = () => { timer = setTimeout(() => {
        resolve(this.terminalAnalysis(state, candidate));
      }, 100); };
      signal.addEventListener('abort', aborted, { once: true }); if (signal.aborted) aborted();
    });
    try { return await Promise.race([operation, stopped]); }
    finally { signal.removeEventListener('abort', aborted); if (timer !== undefined) clearTimeout(timer); }
  }
  private async page(state: Execution, page: CollectedPageWithImages): Promise<void> {
    if (state.controller.signal.aborted || state.finalizing) return;
    for (const frame of page.frames) {
      const prefix = frame.framePath.length ? frame.framePath.join(' >>> ') + ' >>> ' : null;
      state.snapshots.set(frame.snapshotId, { snapshotId: frame.snapshotId, topPageUrl: page.url,
        frameUrl: frame.frameUrl, framePath: [...frame.framePath], capturedAt: frame.capturedAt, html: frame.html,
        elements: frame.elements.map(element => ({ location: element.location, rawText: element.rawText,
          styles: element.styles.map(style => ({ ...structuredClone(style),
            elementLocation: prefix && style.elementLocation.startsWith(prefix) ? style.elementLocation.slice(prefix.length) : style.elementLocation })) })) });
    }
    for (const image of page.images ?? []) this.discoverImage(state, image);
    for (const group of detectImageCandidates(state.ocr.images, [...state.owners.values()])) state.links.set(group.candidateId, [...group.links]);
    const candidates = detectPage(page).filter(candidate => !state.candidates.has(candidate.candidateId));
    for (const candidate of candidates) this.registerCandidate(state, candidate);
    this.refresh(state);
    let next = 0;
    // A bounded worker set also bounds promises retained for each collected page.
    await Promise.all(Array.from({ length: Math.min(this.concurrency, candidates.length) }, async () => {
      while (next < candidates.length) { const candidate = candidates[next++]; await this.analyze(state, candidate); }
    }));
  }
  private async analyze(state: Execution, candidate: DetectionCandidateV2): Promise<void> {
    {
      if (state.controller.signal.aborted) {
        const reason = state.controller.signal.reason === 'TIME_LIMIT' ? 'TIME_LIMIT' : state.controller.signal.reason === 'RESOURCE_LIMIT' ? 'RESOURCE_LIMIT' : 'USER_CANCELLED';
        this.setReview(state, candidate, candidate.rawText ? pendingAnalysis(candidate, reason) : null); return;
      }
      if (state.aiScheduled >= this.maxCandidates) { state.controller.abort('RESOURCE_LIMIT'); this.setReview(state, candidate, candidate.rawText ? pendingAnalysis(candidate, 'RESOURCE_LIMIT') : null); return; }
      state.aiScheduled++;
      const release = await this.acquireAi(state);
      if (!release) { this.setReview(state, candidate, candidate.rawText ? pendingAnalysis(candidate, state.controller.signal.reason === 'TIME_LIMIT' ? 'TIME_LIMIT' : state.controller.signal.reason === 'RESOURCE_LIMIT' ? 'RESOURCE_LIMIT' : 'USER_CANCELLED') : null); return; }
      let ai: AiAnalysis;
      try {
        const fetchFn = this.options.aiOptions?.fetch ?? fetch;
        ai = await this.boundedAnalysis(state, candidate, (this.options.analyzeCandidate ?? analyzeCandidate)(candidate, this.apiKey, state.controller.signal, {
          ...this.options.aiOptions, normalize: normalizeText, totalTimeMs: Math.max(1, Math.min(600000, this.options.aiOptions?.totalTimeMs ?? 600000, state.deadline - Date.now())),
          reserveRequest: () => { if (state.controller.signal.aborted) return false; if (state.aiRequests >= this.maxRequests) { state.controller.abort('RESOURCE_LIMIT'); return false; } return true; },

          onProgress: (ai: AiAnalysis) => this.aiProgress(state, candidate, ai),
          fetch: (...args) => { state.aiRequests++; state.run.requestCounts.clef = state.aiRequests; this.refresh(state); return fetchFn(...args); },
        }));
      } catch (error) {
        ai = this.terminalAnalysis(state, candidate, undefined, true);
        this.addError(state, { scope: 'ai', code: 'AI_HTTP_ERROR', url: candidate.url, candidateId: candidate.candidateId,
          message: error instanceof Error ? error.message : 'AI analysis failed' });
      } finally { release(); }
      if (state.finalizing) return;
      ai = this.terminalAnalysis(state, candidate, ai);
      const decision = classifyAiAnalysis(ai);
      // User cancellation freezes confirmation immediately, while real completed/failed ranges remain in review.
      if (decision.confirmed && state.run.state === 'running' && !state.controller.signal.aborted) this.confirm(state, candidate, ai);
      this.updateDetails(state, candidate, ai);
      this.setReview(state, candidate, ai);
      for (const chunk of ai.chunks) {
        if (chunk.reasonCode && chunk.reasonCode !== 'USER_CANCELLED') this.addError(state, {
          scope: ['RESOURCE_LIMIT', 'TIME_LIMIT'].includes(chunk.reasonCode) ? 'limit' : 'ai', code: chunk.reasonCode,
          url: candidate.url, candidateId: candidate.candidateId, message: `AI chunk ${chunk.chunkId}: ${chunk.reasonCode}` });
      }
      this.refresh(state);
    }
    this.refresh(state);
  }
  private async execute(state: Execution): Promise<RunSnapshotV2> {
    const timer = setTimeout(() => state.controller.abort('TIME_LIMIT'), this.duration);
    let begun = false;
    try {
      await this.store.beginRun(state.run, state.scope); begun = true;
      const result = await (this.options.crawl ?? crawl)(state.run.entryUrl, { ...this.options.crawlOptions,
        ...(this.options.executablePath ? { executablePath: this.options.executablePath } : {}), maxDurationMs: this.duration,
        signal: state.controller.signal,
        images: { ...this.options.imageOptions, enabled: state.run.ocrEnabled, maxImageBytes: this.limits.maxImageBytes, maxImagePixels: this.limits.maxImagePixels, onImage: (image, result) => { const work = this.image(state, image, result).catch(error => { state.fatalError = true; this.addError(state, { scope: 'runtime', code: 'RUNTIME_ERROR', url: image.url, candidateId: null, message: error instanceof OutputStorageErrorV2 ? error.message : 'Image processing failed' }); }); state.work.add(work); void work.finally(() => state.work.delete(work)).catch(() => {}); return work; } },
        onPage: page => {
          const work = this.page(state, page).catch(error => { state.fatalError = true; this.addError(state, { scope: 'runtime', code: 'RUNTIME_ERROR', url: page.url, candidateId: null, message: error instanceof Error ? error.message : 'Page processing failed' }); }); state.work.add(work); void work.finally(() => state.work.delete(work)).catch(() => {}); return work;
        },
        onProgress: progress => {
          if (state.run.state !== 'running' || state.controller.signal.aborted || state.finalizing) return;
          const { confirmedFindings: _confirmed, reviewCandidates: _reviews, ...counts } = progress.counts;
          Object.assign(state.run.counts, counts); state.run.activeUrls = [...progress.activeUrls]; state.crawlerErrors = structuredClone(progress.errors); this.refresh(state);
        },
      });
      // Fatality is an internal producer fact, independent of diagnostic codes/messages.
      state.fatalError ||= result.fatalError === true;
      await Promise.allSettled([...state.work]);
      state.scope = structuredClone(result.scope);
      const { confirmedFindings: _confirmed, reviewCandidates: _reviews, ...counts } = result.counts;
      Object.assign(state.run.counts, counts); state.crawlerErrors = structuredClone(result.errors);
    } catch (error) {
      if (error instanceof OutputStorageErrorV2) this.addError(state, error.runError);
      else { state.fatalError = true; this.addError(state, { scope: 'runtime', code: 'RUNTIME_ERROR', url: null, candidateId: null,
        message: error instanceof Error ? error.message : 'Unexpected runtime failure' }); }
    }
    await Promise.allSettled([...state.work]);
    // Reservation is synchronous: cancel before this line wins; cancel after it awaits saved terminal state.
    await this.finishImages(state);
    state.finalizing = true; clearTimeout(timer);
    if (state.controller.signal.reason === 'TIME_LIMIT' || state.controller.signal.reason === 'RESOURCE_LIMIT') this.addError(state, {
      scope: 'limit', code: state.controller.signal.reason, url: null, candidateId: null, message: 'Run work limit reached' });
    this.refresh(state);
    const incomplete = state.scope.unvisitedUrls.length > 0 || state.run.counts.failedPages > 0 || state.run.counts.pendingPages > 0 || state.run.errors.some(error => !['OUT_OF_SCOPE', 'LOGIN_REQUIRED', 'IMAGE_UNSUPPORTED'].includes(error.code)) ||
      hasIncompleteOcrWork(state.ocr.images) || [...state.review.values()].some(item => item.reason === 'AI_ERROR' || item.reason === 'NOT_ANALYZED');
    const finishedAt = new Date().toISOString();
    const preview: RunSnapshotV2 = { ...structuredClone(state.run), state: !begun || state.run.counts.scannedPages === 0 || state.fatalError || state.run.errors.some(error => error.code === 'STORAGE_ERROR') ? 'failed' : state.run.state === 'stopping' ? 'cancelled' : incomplete ? 'partial' : 'completed', finishedAt,
      elapsedSec: Math.max(0, (Date.parse(finishedAt) - Date.parse(state.run.startedAt)) / 1000), activeUrls: [] };
    if (begun) {
      try {
        const saved = await this.store.saveArtifacts({ run: preview, scope: state.scope, findings: state.findings,
          extraFindings: state.extraFindings, ocr: state.ocr, review: this.review(preview.runId), details: state.details, snapshots: [...state.snapshots.values()] }, { finalizeTiming: () => {
            const finishedAt = new Date().toISOString(); return { finishedAt, elapsedSec: Math.max(0, (Date.parse(finishedAt) - Date.parse(state.run.startedAt)) / 1000) };
          } });
        Object.assign(preview, saved.status.run);
        state.findings = saved.result.findings; state.extraFindings = saved.extraResult.findings; state.ocr = saved.ocr; state.review = new Map(saved.review.candidates.map(item => [item.candidateId, item]));
        state.details = saved.details; state.savedStatus = saved.status;
      } catch (error) {
        preview.state = 'failed';
        const storageError = error instanceof OutputStorageErrorV2 ? error : new OutputStorageErrorV2();
        if (storageError.failureStatus) Object.assign(preview, storageError.failureStatus.run);
        else { preview.finishedAt = new Date().toISOString(); preview.elapsedSec = Math.max(0, (Date.parse(preview.finishedAt) - Date.parse(state.run.startedAt)) / 1000); preview.errors.push(storageError.runError); }
        state.savedStatus = storageError.failureStatus ?? { schemaVersion: 2, run: preview, scope: state.scope,
          files: { resultPath: null, reviewPath: null, findingDetailsPath: null, evidenceDir: null, resultSha256: null, extraResultPath: null, extraResultSha256: null, ocrPath: null }, resultSaved: false, extraResultSaved: false, imageScope: { enabled: preview.ocrEnabled, framePolicy: 'first', unsupportedKinds: ['canvas', 'video', 'animation_remaining_frames'], pendingImageIds: state.ocr.images.filter(image => ['not_started', 'cancelled'].includes(image.status)).map(image => image.imageId) } };
        state.savedStatus.run = structuredClone(preview);
        if (state.savedStatus.resultSaved && state.savedStatus.extraResultSaved) {
          try {
            // Every read verifies the archive. Restore all public DTOs together only after every read succeeds.
            const [resultBytes, extraBytes, reviewBytes, detailsBytes, ocrBytes, statusBytes] = await Promise.all(
              (['result.json', 'result_extra.json', 'review.json', 'finding-details.json', 'ocr.json', 'scan-status.json'] as const)
                .map(name => this.store.readFile(preview.runId, name)));
            const result = JSON.parse(resultBytes.toString('utf8')) as OfficialResult;
            const extra = JSON.parse(extraBytes.toString('utf8')) as ExtraResult;
            const review = JSON.parse(reviewBytes.toString('utf8')) as ReviewFileV2;
            const details = JSON.parse(detailsBytes.toString('utf8')) as FindingDetailsFileV2;
            const ocr = JSON.parse(ocrBytes.toString('utf8')) as OcrFile;
            const status = JSON.parse(statusBytes.toString('utf8')) as ScanStatusFileV2;
            state.findings = result.findings; state.extraFindings = extra.findings;
            state.review = new Map(review.candidates.map(item => [item.candidateId, item])); state.details = details;
            state.ocr = ocr; state.savedStatus = status; Object.assign(preview, status.run);
          } catch {
            // A formerly verified archive may now be unavailable. Preserve accepted evidence and failure metadata,
            // while withdrawing file registrations and save claims that cannot be reverified.
            state.savedStatus = { ...state.savedStatus, resultSaved: false, extraResultSaved: false,
              files: { resultPath: null, reviewPath: null, findingDetailsPath: null, evidenceDir: null, resultSha256: null,
                extraResultPath: null, extraResultSha256: null, ocrPath: null } };
          }
        }
      }
    } else state.savedStatus = { schemaVersion: 2, run: preview, scope: state.scope,
      files: { resultPath: null, reviewPath: null, findingDetailsPath: null, evidenceDir: null, resultSha256: null, extraResultPath: null, extraResultSha256: null, ocrPath: null }, resultSaved: false, extraResultSaved: false, imageScope: { enabled: preview.ocrEnabled, framePolicy: 'first', unsupportedKinds: ['canvas', 'video', 'animation_remaining_frames'], pendingImageIds: state.ocr.images.filter(image => ['not_started', 'cancelled'].includes(image.status)).map(image => image.imageId) } };
    clearTimeout(timer); state.run = preview; state.snapshots.clear(); state.candidates.clear(); state.aiProgress.clear(); state.owners.clear(); state.processedImages.clear();
    // The registry releases the active slot only after all storage work. Public terminal metadata is the saved preview.
    this.registry.finish(preview.runId, { saved: Boolean(state.savedStatus?.resultSaved), extraSaved: Boolean(state.savedStatus?.extraResultSaved), ocr: state.ocr, imageCounts: preview.imageCounts, requestCounts: preview.requestCounts, fatalError: state.fatalError, storageFailed: preview.errors.some(error => error.code === 'STORAGE_ERROR'), incomplete, counts: preview.counts, errors: preview.errors, finishedAt: preview.finishedAt!, elapsedSec: preview.elapsedSec });
    return structuredClone(preview);
  }
}
