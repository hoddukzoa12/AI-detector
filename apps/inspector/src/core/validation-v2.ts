import { CLEF_MODEL, TECHNIQUES, type OfficialResult, type AiAnalysis, type RunSnapshot } from './types.js';
import { classifyAiAnalysis } from './ai.js';
import { ContractError, validateEntryUrl, validateOfficialResult, validateRunSnapshot, validateAiAnalysis, validateEvidenceSnapshot } from './validation.js';
import { IMAGE_SOURCE_KINDS, OCR_IMAGE_STATUSES, OCR_MODEL, REVIEW_REASONS_V2, V2_ERROR_CODES,
  type CandidateSource, type ExtraResult, type FindingDetailsFileV2, type ImageCounts, type ImageOccurrenceIdentity,
  type OcrExtraction, type OcrFile, type OcrImageOccurrence, type PublicConfigV2, type ReviewFileV2,
  type ReviewReasonV2, type RunSnapshotV2, type ScanStatusFileV2, type StartRunRequestV2 } from './v2.js';

type Obj = Record<string, unknown>;
function fail(at: string, message: string): never { throw new ContractError('INVALID_REQUEST', `${at}: ${message}`); }
function object(value: unknown, at: string, keys: readonly string[]): Obj {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail(at, 'object required');
  const result = value as Obj;
  if (keys.some(k => !Object.hasOwn(result, k)) || Object.keys(result).some(k => !keys.includes(k))) fail(at, 'exact fields required');
  return result;
}
function string(value: unknown, at: string, empty = false): asserts value is string {
  if (typeof value !== 'string' || (!empty && value.length === 0)) fail(at, 'string required');
}
function number(value: unknown, at: string, positive = false, integer = true): asserts value is number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < (positive ? 1 : 0) || (integer && !Number.isSafeInteger(value))) fail(at, 'finite nonnegative number required');
}
function literal(value: unknown, at: string, values: readonly unknown[]): void { if (!values.includes(value)) fail(at, 'unsupported value'); }
function array(value: unknown, at: string): unknown[] { if (!Array.isArray(value)) fail(at, 'array required'); return value; }
function strings(value: unknown, at: string): string[] { const values = array(value, at); values.forEach(v => string(v, at)); unique(values, at); return values as string[]; }
function unique(values: unknown[], at: string): void { if (new Set(values).size !== values.length) fail(at, 'duplicates forbidden'); }
function pathHash(path: unknown, hash: unknown, at: string): void {
  if ((path === null) !== (hash === null)) fail(at, 'path/hash must be present together');
  if (path === null) return;
  string(path, at); string(hash, at);
  if (path.includes('\\') || path.startsWith('/') || /^[a-z]:/i.test(path) || path.split('/').some(p => !p || p === '.' || p === '..') || !/^[a-f0-9]{64}$/.test(hash)) fail(at, 'safe relative path and SHA-256 required');
}
function date(value: unknown, at: string): void {
  validateOfficialResult({ meta: { topic: 'TOPIC', entry_url: 'https://validation.invalid/', started_at: value, finished_at: value, elapsed_sec: 0 }, findings: [] });
  string(value, at);
}
function evidence(value: unknown): void {
  const e = object(value, 'evidence', ['snapshotId', 'path', 'sha256']); string(e.snapshotId, 'evidence.snapshotId'); pathHash(e.path, e.sha256, 'evidence');
}
function ownerFields(value: Obj): void {
  validateEntryUrl(value.url); string(value.frameUrl, 'frameUrl'); array(value.framePath, 'framePath').forEach(p => string(p, 'framePath[]'));
  string(value.location, 'location'); string(value.snapshotId, 'snapshotId');
  literal(value.sourceKind, 'sourceKind', IMAGE_SOURCE_KINDS); number(value.sourceIndex, 'sourceIndex');
  if (value.sourceKind === 'img' && value.sourceIndex !== 0) fail('sourceIndex', 'img index is zero');
}
export function validateStartRunRequestV2(value: unknown): asserts value is StartRunRequestV2 {
  const request = object(value, 'startRequest', ['entryUrl', 'ocrEnabled', 'externalAnalysisConsent']);
  validateEntryUrl(request.entryUrl); literal(request.ocrEnabled, 'ocrEnabled', [true, false]);
  literal(request.externalAnalysisConsent, 'externalAnalysisConsent', [true]);
}
export function validatePublicConfigV2(value: unknown): asserts value is PublicConfigV2 {
  const config = object(value, 'config', ['aiConfigured', 'aiRequired', 'model', 'ocrModel', 'outputRoot', 'limits']);
  literal(config.aiConfigured, 'aiConfigured', [true, false]); literal(config.aiRequired, 'aiRequired', [true]);
  literal(config.model, 'model', [CLEF_MODEL]); literal(config.ocrModel, 'ocrModel', [OCR_MODEL]); string(config.outputRoot, 'outputRoot');
  const limits = object(config.limits, 'limits', ['maxOcrRequests', 'maxClefRequests', 'maxImageBytes', 'maxImagePixels']);
  Object.entries(limits).forEach(([k, v]) => number(v, `limits.${k}`, true));
}
export function validateRunSnapshotV2(value: unknown): asserts value is RunSnapshotV2 {
  const run = object(value, 'run', ['runId', 'entryUrl', 'startedAt', 'state', 'finishedAt', 'elapsedSec', 'aiEnabled', 'model', 'counts', 'activeUrls', 'errors',
    'externalAnalysisConsent', 'ocrEnabled', 'ocrModel', 'imageCounts', 'requestCounts']);
  literal(run.aiEnabled, 'aiEnabled', [true]); literal(run.model, 'model', [CLEF_MODEL]); literal(run.externalAnalysisConsent, 'externalAnalysisConsent', [true]);
  literal(run.ocrEnabled, 'ocrEnabled', [true, false]); literal(run.ocrModel, 'ocrModel', [run.ocrEnabled ? OCR_MODEL : null]);
  const counts = object(run.counts, 'counts', ['discoveredPages', 'scannedPages', 'failedPages', 'skippedPages', 'pendingPages', 'confirmedFindings', 'reviewCandidates', 'extraConfirmedFindings']);
  Object.entries(counts).forEach(([k, v]) => number(v, `counts.${k}`));
  const images = object(run.imageCounts, 'imageCounts', ['discovered', 'captured', 'ocrCompleted', 'failed', 'pending', 'skipped']);
  Object.entries(images).forEach(([k, v]) => number(v, `imageCounts.${k}`));
  for (const key of ['captured', 'ocrCompleted', 'failed', 'pending', 'skipped']) if ((images[key] as number) > (images.discovered as number)) fail('imageCounts', 'count exceeds discovered');
  if ((images.failed as number) + (images.pending as number) + (images.skipped as number) + (images.ocrCompleted as number) !== images.discovered) fail('imageCounts', 'status partition must match discovered');
  if ((images.ocrCompleted as number) > (images.captured as number)) fail('imageCounts', 'OCR completion requires capture');
  const requests = object(run.requestCounts, 'requestCounts', ['ocr', 'clef']); Object.entries(requests).forEach(([k, v]) => number(v, `requestCounts.${k}`));
  if (!run.ocrEnabled && ((images.captured as number) || (images.ocrCompleted as number) || (images.failed as number) || (images.pending as number) || requests.ocr)) fail('ocrEnabled', 'unselected OCR cannot perform work');
  const errors = array(run.errors, 'errors');
  for (const item of errors) {
    const e = object(item, 'error', ['scope', 'code', 'url', 'candidateId', 'message']);
    literal(e.scope, 'error.scope', ['page', 'frame', 'ai', 'storage', 'runtime', 'limit', 'image', 'ocr']); literal(e.code, 'error.code', V2_ERROR_CODES);
    if (e.url !== null) validateEntryUrl(e.url); if (e.candidateId !== null) string(e.candidateId, 'error.candidateId'); string(e.message, 'error.message');
  }
  // Reuse the independent V1 calendar, URL, elapsed and page-counter validation without relaxing V1.
  const { externalAnalysisConsent: _consent, ocrEnabled: _enabled, ocrModel: _model, imageCounts: _images, requestCounts: _requests, ...legacy } = run;
  const { extraConfirmedFindings: _extra, ...legacyCounts } = counts;
  validateRunSnapshot({ ...legacy, counts: legacyCounts, errors: errors.map(item => ({ ...(item as Obj), scope: 'runtime', code: 'RUNTIME_ERROR' })) });
  const terminal = !['running', 'stopping'].includes(run.state as string);
  if (terminal && array(run.activeUrls, 'activeUrls').length) fail('activeUrls', 'terminal run has no active URLs');
  if (run.state === 'completed' && ((counts.scannedPages as number) === 0 || counts.failedPages || counts.pendingPages || images.failed || images.pending || errors.some(e => !['OUT_OF_SCOPE', 'LOGIN_REQUIRED', 'IMAGE_UNSUPPORTED'].includes((e as Obj).code as string)))) fail('state', 'completed run cannot contain incomplete selected work');
}
export function validateExtraResult(value: unknown): asserts value is ExtraResult {
  const result = object(value, 'extraResult', ['meta', 'findings']);
  const findings = array(result.findings, 'findings');
  const projected = findings.map(item => {
    const f = object(item, 'extraFinding', ['id', 'url', 'is_violation', 'location', 'evidence_text', 'technique', 'extra_finding']);
    literal(f.technique, 'technique', ['ETC']); literal(f.extra_finding, 'extra_finding', ['IMAGE_AD_OCR']);
    const { extra_finding: _extra, ...fields } = f;
    return { ...fields, technique: 'HOMOGLYPH' };
  });
  validateOfficialResult({ meta: result.meta, findings: projected });
}
export function validateResultPair(official: unknown, extra: unknown): void {
  validateOfficialResult(official); validateExtraResult(extra);
  unique([...official.findings, ...extra.findings].map(f => f.id), 'result pair IDs');
  if (JSON.stringify(official.meta) !== JSON.stringify(extra.meta)) {
    for (const key of new Set([...Object.keys(official.meta), ...Object.keys(extra.meta)])) {
      if ((official.meta as unknown as Obj)[key] !== (extra.meta as unknown as Obj)[key]) fail('meta', 'result pair metadata must match');
    }
  }
}
/** Identity keeps query values, full frame path, owner, kind and layer separate. */
export function imageOccurrenceKey(image: ImageOccurrenceIdentity): string { return JSON.stringify([image.url, image.framePath, image.location, image.sourceKind, image.sourceIndex]); }
export function imageOwnerKey(image: Pick<ImageOccurrenceIdentity, 'url' | 'framePath' | 'location'>): string { return JSON.stringify([image.url, image.framePath, image.location]); }
export function candidateIdentityKey(candidate: Pick<ImageOccurrenceIdentity, 'url' | 'framePath' | 'location'> & Pick<CandidateSource, 'sourceType'>): string { return JSON.stringify([candidate.url, candidate.framePath, candidate.location, candidate.sourceType]); }
export function combineReadableImageText(images: readonly OcrImageOccurrence[]): { rawText: string; sourceTextRanges: CandidateSource['sourceTextRanges'] } {
  if (new Set(images.map(imageOwnerKey)).size > 1) fail('images', 'one candidate can only combine one owner');
  const readable = images.filter(i => i.status === 'completed' && i.extractionStatus === 'readable').sort((a, b) => IMAGE_SOURCE_KINDS.indexOf(a.sourceKind) - IMAGE_SOURCE_KINDS.indexOf(b.sourceKind) || a.sourceIndex - b.sourceIndex);
  let rawText = ''; const sourceTextRanges: CandidateSource['sourceTextRanges'] = [];
  for (const image of readable) {
    string(image.text, 'readable.text'); if (rawText.length) rawText += '\n';
    const rawStart = rawText.length; rawText += image.text; sourceTextRanges.push({ imageId: image.imageId, rawStart, rawEnd: rawText.length });
  }
  return { rawText, sourceTextRanges };
}
export function countImages(images: readonly OcrImageOccurrence[]): ImageCounts {
  return { discovered: images.length, captured: images.filter(i => i.original !== null).length,
    ocrCompleted: images.filter(i => i.status === 'completed').length, failed: images.filter(i => i.status === 'error').length,
    pending: images.filter(i => ['discovered', 'captured', 'running', 'not_started', 'cancelled'].includes(i.status)).length,
    skipped: images.filter(i => ['not_selected', 'unsupported'].includes(i.status)).length };
}
/** A valid OCR response can still leave the selected reading task incomplete. no_text is a completed review. */
export function hasIncompleteOcrWork(images: readonly OcrImageOccurrence[]): boolean {
  return images.some(i => ['discovered', 'captured', 'running', 'not_started', 'cancelled', 'error'].includes(i.status) ||
    i.extractionStatus === 'partial' || i.extractionStatus === 'unreadable');
}
/** Final callers must supply actual OCR records, never infer reading completion from cumulative counters. */
export function validateRunOcrState(run: RunSnapshotV2, ocr: OcrFile, terminal = !['running', 'stopping'].includes(run.state)): void {
  validateRunSnapshotV2(run); validateOcrFile(ocr, terminal);
  if (ocr.runId !== run.runId || ocr.enabled !== run.ocrEnabled) fail('ocr', 'run selection/identity must match');
  const counts = countImages(ocr.images);
  for (const [key, value] of Object.entries(counts)) if (run.imageCounts[key as keyof ImageCounts] !== value) fail('imageCounts', 'must equal occurrence counts');
  if (run.requestCounts.ocr !== ocr.images.reduce((n, i) => n + i.attemptCount, 0)) fail('requestCounts.ocr', 'must equal actual requests including retries');
  if (run.state === 'completed' && hasIncompleteOcrWork(ocr.images)) fail('state', 'selected OCR reading failures require partial completion');
}
export function validateOcrExtraction(value: unknown): asserts value is OcrExtraction {
  const result = object(value, 'extraction', ['status', 'text']); literal(result.status, 'extraction.status', ['readable', 'partial', 'no_text', 'unreadable']);
  string(result.text, 'extraction.text', result.status !== 'readable');
  if (['no_text', 'unreadable'].includes(result.status as string) && result.text !== '') fail('extraction.text', 'status requires empty text');
}
function asset(value: unknown, input: boolean): void {
  const a = object(value, 'asset', ['assetId', 'path', 'sha256', 'mime', 'byteLength', ...(input ? ['width', 'height', 'frameIndex'] : [])]);
  string(a.assetId, 'assetId'); pathHash(a.path, a.sha256, 'asset'); string(a.mime, 'mime'); number(a.byteLength, 'byteLength', true);
  // Originals retain the actual fetched MIME even when decoding fails. Only derived PNG inputs are analyzed/previewed.
  if (!/^[a-z0-9][a-z0-9!#$&^_.+-]*\/[a-z0-9][a-z0-9!#$&^_.+-]*$/i.test(a.mime as string)) fail('mime', 'parameter-free MIME type/subtype required');
  if (input) { literal(a.mime, 'mime', ['image/png']); number(a.width, 'width', true); number(a.height, 'height', true); literal(a.frameIndex, 'frameIndex', [0]); }
}
export function validateOcrFile(value: unknown, terminal = false): asserts value is OcrFile {
  const file = object(value, 'ocr', ['schemaVersion', 'runId', 'enabled', 'model', 'images']); literal(file.schemaVersion, 'schemaVersion', [2]); string(file.runId, 'runId');
  literal(file.enabled, 'enabled', [true, false]); literal(file.model, 'model', [file.enabled ? OCR_MODEL : null]);
  const images = array(file.images, 'images'); const ids: unknown[] = []; const keys: string[] = []; const registeredAssets = new Map<string, Obj>();
  for (const item of images) {
    const i = object(item, 'image', ['imageId', 'url', 'frameUrl', 'framePath', 'location', 'snapshotId', 'sourceKind', 'sourceIndex', 'imageUrl', 'capturedAt',
      'original', 'input', 'styles', 'concealment', 'status', 'extractionStatus', 'text', 'confidence', 'model', 'promptVersion', 'cacheOf', 'attemptCount', 'usage', 'reasonCode']);
    ownerFields(i); string(i.imageId, 'imageId'); ids.push(i.imageId); keys.push(imageOccurrenceKey(i as unknown as ImageOccurrenceIdentity));
    if (i.imageUrl !== null) validateEntryUrl(i.imageUrl); if (i.capturedAt !== null) date(i.capturedAt, 'capturedAt');
    if (i.original !== null) asset(i.original, false); if (i.input !== null) asset(i.input, true);
    for (const reference of [i.original, i.input]) {
      if (reference === null) continue;
      const current = reference as Obj, previous = registeredAssets.get(current.assetId as string);
      if (previous && [...new Set([...Object.keys(previous), ...Object.keys(current)])].some(key => previous[key] !== current[key])) fail('assetId', 'one registered asset ID cannot describe conflicting bytes or metadata');
      registeredAssets.set(current.assetId as string, current);
    }
    if ((i.original === null) !== (i.capturedAt === null) || (i.input !== null && i.original === null)) fail('assets', 'capture time/original and input relationships required');
    validateEvidenceSnapshot({ snapshotId: i.snapshotId, topPageUrl: i.url, frameUrl: i.frameUrl, framePath: i.framePath, capturedAt: '2026-01-01T00:00:00Z', html: '', elements: [{ location: i.location, rawText: '', styles: i.styles }] });
    const concealment = strings(i.concealment, 'concealment'); concealment.forEach(c => literal(c, 'concealment', ['TRANSPARENT', 'OFFSCREEN']));
    literal(i.status, 'status', OCR_IMAGE_STATUSES); literal(i.confidence, 'confidence', [null]); literal(i.model, 'model', [file.model]); string(i.promptVersion, 'promptVersion');
    if (i.cacheOf !== null) string(i.cacheOf, 'cacheOf'); number(i.attemptCount, 'attemptCount');
    const usage = object(i.usage, 'usage', ['promptTokens', 'completionTokens', 'totalTokens', 'costUsd']);
    Object.entries(usage).forEach(([key, v]) => { if (v !== null) number(v, `usage.${key}`, false, key !== 'costUsd'); });
    literal(i.reasonCode, 'reasonCode', [null, 'IMAGE_FETCH_ERROR', 'IMAGE_DECODE_ERROR', 'IMAGE_UNSUPPORTED', 'OCR_HTTP_ERROR', 'OCR_RESPONSE_INVALID', 'OCR_TIMEOUT', 'OCR_UNREADABLE', 'USER_CANCELLED', 'TIME_LIMIT', 'RESOURCE_LIMIT', 'OCR_NOT_SELECTED']);
    if (terminal && ['discovered', 'captured', 'running'].includes(i.status as string)) fail('status', 'active image forbidden in terminal run');
    if (i.status === 'completed') {
      validateOcrExtraction({ status: i.extractionStatus, text: i.text });
      if (!i.original || !i.input || ((i.attemptCount as number) === 0 && i.cacheOf === null)) fail('completed', 'completion requires assets and actual request or cache');
      literal(i.reasonCode, 'completed.reasonCode', ['partial', 'unreadable'].includes(i.extractionStatus as string) ? ['OCR_UNREADABLE'] : [null]);
    } else {
      literal(i.extractionStatus, 'extractionStatus', [null]); literal(i.text, 'text', [null]); literal(i.cacheOf, 'cacheOf', [null]);
      if (i.status === 'error') {
        literal(i.reasonCode, 'error.reasonCode', ['IMAGE_FETCH_ERROR', 'IMAGE_DECODE_ERROR', 'OCR_HTTP_ERROR', 'OCR_RESPONSE_INVALID', 'OCR_TIMEOUT']);
        if ((i.reasonCode as string).startsWith('OCR_') && (!(i.attemptCount as number) || !i.input)) fail('error', 'OCR failure requires actual request and PNG');
      }
      if (i.status === 'unsupported') literal(i.reasonCode, 'unsupported.reasonCode', ['IMAGE_UNSUPPORTED']);
      if (i.status === 'cancelled') {
        literal(i.reasonCode, 'cancelled.reasonCode', ['USER_CANCELLED', 'TIME_LIMIT', 'RESOURCE_LIMIT']);
        if (!(i.attemptCount as number) || !i.input) fail('cancelled', 'only an actual in-flight OCR request is cancelled');
      }
      if (i.status === 'not_started') { literal(i.reasonCode, 'not_started.reasonCode', ['USER_CANCELLED', 'TIME_LIMIT', 'RESOURCE_LIMIT']); literal(i.attemptCount, 'not_started.attemptCount', [0]); }
      if (i.status === 'discovered' && (i.original || i.input || i.attemptCount)) fail('discovered', 'not yet captured/requested');
      if (i.status === 'captured' && (!i.original || i.attemptCount)) fail('captured', 'original captured but no OCR request');
      if (i.status === 'running' && (!i.input || !(i.attemptCount as number))) fail('running', 'actual request and input required');
    }
    if (!file.enabled) {
      literal(i.status, 'status', ['not_selected']); literal(i.reasonCode, 'reasonCode', ['OCR_NOT_SELECTED']);
      if (i.original !== null || i.input !== null || i.capturedAt !== null || i.attemptCount !== 0 || Object.values(usage).some(v => v !== null)) fail('not_selected', 'unselected images cannot have assets, requests or usage');
    } else if (i.status === 'not_selected') fail('status', 'selected OCR cannot be not_selected');
  }
  unique(ids, 'imageIds'); unique(keys, 'image occurrences');
  for (const item of images) {
    const i = item as unknown as OcrImageOccurrence; if (i.cacheOf === null) continue;
    const source = images.find(other => (other as Obj).imageId === i.cacheOf) as unknown as OcrImageOccurrence | undefined;
    if (!source || source.imageId === i.imageId || source.cacheOf !== null || source.status !== 'completed' || i.status !== 'completed' || i.attemptCount !== 0 || !['readable', 'no_text'].includes(i.extractionStatus as string) ||
      !i.input?.sha256 || i.input.sha256 !== source.input?.sha256 || i.model !== source.model || i.promptVersion !== source.promptVersion || i.extractionStatus !== source.extractionStatus || i.text !== source.text || Object.values(i.usage).some(v => v !== null)) fail('cacheOf', 'cache must copy a complete successful matching input/model/version without requests/usage');
  }
}

function linkedSource(value: Obj, rawText: string | undefined, ocr?: OcrFile): OcrImageOccurrence[] {
  literal(value.sourceType, 'sourceType', ['dom_text', 'image_ocr']);
  const ids = strings(value.sourceIds, 'sourceIds'); const ranges = array(value.sourceTextRanges, 'sourceTextRanges');
  if (value.sourceType === 'dom_text') { if (ids.length || ranges.length) fail('source', 'DOM text has no OCR sources'); return []; }
  if (!ids.length) fail('sourceIds', 'image candidate requires occurrence IDs');
  for (const range of ranges) {
    const r = object(range, 'sourceTextRange', ['imageId', 'rawStart', 'rawEnd']); string(r.imageId, 'imageId');
    if (!ids.includes(r.imageId)) fail('imageId', 'range must reference candidate source'); number(r.rawStart, 'rawStart'); number(r.rawEnd, 'rawEnd');
    if ((r.rawStart as number) >= (r.rawEnd as number) || (rawText !== undefined && ((r.rawEnd as number) > rawText.length || !boundary(rawText, r.rawStart as number) || !boundary(rawText, r.rawEnd as number)))) fail('sourceTextRange', 'nonempty valid UTF-16 range required');
  }
  unique(ranges.map(r => (r as Obj).imageId), 'sourceTextRanges.imageId');
  if (!ocr) return [];
  const images = ids.map(id => { const image = ocr.images.find(i => i.imageId === id); if (!image) fail('sourceIds', 'unknown image occurrence'); return image; });
  if (new Set(images.map(imageOwnerKey)).size !== 1 || images.some(i => i.url !== value.url || i.location !== value.location || i.snapshotId !== (value.evidence as Obj).snapshotId)) fail('sourceIds', 'image sources must belong to the same owner and DOM evidence');
  const allOwnerImages = ocr.images.filter(i => imageOwnerKey(i) === imageOwnerKey(images[0]));
  if (allOwnerImages.length !== images.length || allOwnerImages.some(i => !ids.includes(i.imageId))) fail('sourceIds', 'all owner assets must remain linked');
  const combined = combineReadableImageText(images);
  const rangesMatch = ranges.length === combined.sourceTextRanges.length && ranges.every((range, index) => {
    const actual = range as Obj, expected = combined.sourceTextRanges[index];
    return actual.imageId === expected.imageId && actual.rawStart === expected.rawStart && actual.rawEnd === expected.rawEnd;
  });
  if ((rawText !== undefined && rawText !== combined.rawText) || !rangesMatch) fail('sourceTextRanges', 'must match complete ordered readable OCR strings');
  return images;
}
function boundary(text: string, n: number): boolean { return n === 0 || n === text.length || !(text.charCodeAt(n - 1) >= 0xd800 && text.charCodeAt(n - 1) <= 0xdbff && text.charCodeAt(n) >= 0xdc00 && text.charCodeAt(n) <= 0xdfff); }
export function selectReviewReason(reasons: readonly ReviewReasonV2[]): ReviewReasonV2 | null { return REVIEW_REASONS_V2.find(r => reasons.includes(r)) ?? null; }
export function imageReviewReasons(images: readonly OcrImageOccurrence[]): ReviewReasonV2[] {
  const reasons: ReviewReasonV2[] = [];
  if (images.some(i => i.status === 'error')) reasons.push('OCR_ERROR');
  if (images.some(i => ['discovered', 'captured', 'running', 'not_started', 'cancelled'].includes(i.status))) reasons.push('NOT_ANALYZED');
  if (images.some(i => i.extractionStatus === 'partial' || i.extractionStatus === 'unreadable')) reasons.push('OCR_UNREADABLE');
  if (images.some(i => i.extractionStatus === 'no_text')) reasons.push('OCR_NO_TEXT');
  return reasons;
}
export function validateReviewFileV2(value: unknown, ocr?: OcrFile, terminal = false): asserts value is ReviewFileV2 {
  const file = object(value, 'review', ['schemaVersion', 'runId', 'candidates']); literal(file.schemaVersion, 'schemaVersion', [2]); string(file.runId, 'runId');
  if (ocr) { validateOcrFile(ocr, terminal); if (ocr.runId !== file.runId) fail('runId', 'OCR run must match'); }
  const ids: unknown[] = []; const identities: string[] = [];
  for (const item of array(file.candidates, 'candidates')) {
    const c = object(item, 'candidate', ['candidateId', 'url', 'location', 'evidenceText', 'techniques', 'reason', 'ai', 'evidence', 'sourceType', 'sourceIds', 'sourceTextRanges']);
    string(c.candidateId, 'candidateId'); ids.push(c.candidateId); validateEntryUrl(c.url); string(c.location, 'location'); string(c.evidenceText, 'evidenceText', true); evidence(c.evidence);
    literal(c.reason, 'reason', REVIEW_REASONS_V2); const images = linkedSource(c, c.evidenceText as string, ocr);
    if (terminal && c.sourceType === 'image_ocr' && !ocr) fail('ocr', 'terminal image review requires actual OCR records');
    identities.push(candidateIdentityKey({ url: c.url as string, framePath: images[0]?.framePath ?? [], location: c.location as string, sourceType: c.sourceType as CandidateSource['sourceType'] }));
    const techniques = strings(c.techniques, 'techniques'); techniques.forEach(t => literal(t, 'techniques', TECHNIQUES));
    if ((c.sourceType === 'dom_text' && !techniques.length) || (c.sourceType === 'image_ocr' && techniques.length)) fail('techniques', 'only DOM candidates require observed text techniques');
    const reasons = imageReviewReasons(images);
    if (c.ai !== null) {
      if (c.sourceType === 'image_ocr' && !(c.evidenceText as string).length) fail('ai', 'no readable OCR text means no CLEF');
      validateAiAnalysis(c.ai, c.evidenceText as string, terminal); const decision = classifyAiAnalysis(c.ai as AiAnalysis);
      if (decision.reason) reasons.push(decision.reason as ReviewReasonV2);
    } else if (c.sourceType === 'dom_text' || (c.evidenceText as string).length) reasons.push('NOT_ANALYZED');
    if (!ocr && c.sourceType === 'image_ocr' && ['OCR_ERROR', 'OCR_UNREADABLE', 'OCR_NO_TEXT'].includes(c.reason as string)) reasons.push(c.reason as ReviewReasonV2);
    if (selectReviewReason(reasons) !== c.reason) fail('reason', 'must match actual AI/OCR/unfinished reason precedence');
  }
  unique(ids, 'candidateIds'); unique(identities, 'candidate owner/sourceType identities');
}
export function validateFindingDetailsFileV2(value: unknown, official?: OfficialResult, extra?: ExtraResult, ocr?: OcrFile, terminal = false): asserts value is FindingDetailsFileV2 {
  const file = object(value, 'findingDetails', ['schemaVersion', 'runId', 'details']); literal(file.schemaVersion, 'schemaVersion', [2]); string(file.runId, 'runId');
  if (official && extra) validateResultPair(official, extra); else { if (official) validateOfficialResult(official); if (extra) validateExtraResult(extra); }
  if (ocr) { validateOcrFile(ocr, terminal); if (ocr.runId !== file.runId) fail('runId', 'OCR run must match'); }
  const ids: unknown[] = [];
  for (const item of array(file.details, 'details')) {
    const d = object(item, 'detail', ['findingId', 'candidateId', 'decisionSource', 'ruleIds', 'ai', 'evidence', 'resultFile', 'sourceType', 'sourceIds', 'sourceTextRanges', 'observationIds']);
    string(d.findingId, 'findingId'); ids.push(d.findingId); string(d.candidateId, 'candidateId'); literal(d.decisionSource, 'decisionSource', ['clef']);
    if (array(d.ruleIds, 'ruleIds').length) fail('ruleIds', 'CLEF-only details require empty rules'); strings(d.observationIds, 'observationIds'); evidence(d.evidence);
    literal(d.resultFile, 'resultFile', ['result.json', 'result_extra.json']);
    const result = d.resultFile === 'result.json' ? official : extra;
    const finding = result?.findings.find(f => f.id === d.findingId);
    if (result && !finding) fail('findingId', 'finding belongs to the declared result file');
    if ((d.resultFile === 'result.json' ? 'dom_text' : 'image_ocr') !== d.sourceType) fail('sourceType', 'result file and source must agree');
    const images = linkedSource({ ...d, url: finding?.url, location: finding?.location }, finding?.evidence_text, finding ? ocr : undefined);
    if (d.sourceType === 'image_ocr') {
      if (!finding || !ocr || !finding.evidence_text.length || !array(d.sourceTextRanges, 'sourceTextRanges').length || !images.some(i => i.status === 'completed' && i.extractionStatus === 'readable')) fail('image detail', 'image confirmation requires actual nonempty readable OCR text and source ranges');
    }
    validateAiAnalysis(d.ai, finding?.evidence_text, terminal);
    if (d.sourceType === 'image_ocr' && (d.ai as AiAnalysis).chunks.some(c => c.rawStart === c.rawEnd)) fail('ai.chunks', 'image CLEF chunks must cover nonempty OCR text');
    if (!classifyAiAnalysis(d.ai as AiAnalysis).confirmed) fail('ai', 'confirmed result requires actual positive CLEF chunk');
  }
  unique(ids, 'findingIds');
  if (official && extra) { const findings = [...official.findings, ...extra.findings]; if (ids.length !== findings.length || findings.some(f => !ids.includes(f.id))) fail('details', 'exactly one detail per finding across both files'); }
}
export function validateScanStatusFileV2(value: unknown, ocr?: OcrFile): asserts value is ScanStatusFileV2 {
  const file = object(value, 'scanStatus', ['schemaVersion', 'run', 'scope', 'files', 'resultSaved', 'extraResultSaved', 'imageScope']); literal(file.schemaVersion, 'schemaVersion', [2]); validateRunSnapshotV2(file.run);
  const run = file.run; const scope = object(file.scope, 'scope', ['hostname', 'framePolicy', 'skipped', 'unvisitedUrls']); string(scope.hostname, 'hostname'); literal(scope.framePolicy, 'framePolicy', ['embedded']);
  if (scope.hostname !== new URL(run.entryUrl).hostname) fail('scope.hostname', 'must match entry hostname');
  strings(scope.unvisitedUrls, 'unvisitedUrls').forEach(validateEntryUrl);
  for (const item of array(scope.skipped, 'skipped')) { const s = object(item, 'skipped', ['url', 'reasonCode']); validateEntryUrl(s.url); literal(s.reasonCode, 'reasonCode', V2_ERROR_CODES); }
  const files = object(file.files, 'files', ['resultPath', 'resultSha256', 'extraResultPath', 'extraResultSha256', 'reviewPath', 'findingDetailsPath', 'evidenceDir', 'ocrPath']);
  pathHash(files.resultPath, files.resultSha256, 'result'); pathHash(files.extraResultPath, files.extraResultSha256, 'extraResult');
  for (const key of ['reviewPath', 'findingDetailsPath', 'evidenceDir', 'ocrPath']) if (files[key] !== null) pathHash(files[key], '0'.repeat(64), key);
  literal(file.resultSaved, 'resultSaved', [true, false]); literal(file.extraResultSaved, 'extraResultSaved', [true, false]);
  if (file.resultSaved !== (files.resultPath !== null) || file.extraResultSaved !== (files.extraResultPath !== null)) fail('files', 'saved flags must reflect registered paths and hashes');
  if (!['running', 'stopping', 'failed'].includes(run.state) && (!file.resultSaved || !file.extraResultSaved)) fail('state', 'either result save failure requires failed run');
  const imageScope = object(file.imageScope, 'imageScope', ['enabled', 'framePolicy', 'unsupportedKinds', 'pendingImageIds']); literal(imageScope.enabled, 'enabled', [run.ocrEnabled]); literal(imageScope.framePolicy, 'framePolicy', ['first']);
  const kinds = strings(imageScope.unsupportedKinds, 'unsupportedKinds'); if (kinds.length !== 3 || ['canvas', 'video', 'animation_remaining_frames'].some(k => !kinds.includes(k))) fail('unsupportedKinds', 'required excluded scope must be explicit');
  const pending = strings(imageScope.pendingImageIds, 'pendingImageIds');
  if (!['running', 'stopping'].includes(run.state) && run.ocrEnabled && !ocr) fail('ocr', 'selected terminal status requires actual OCR records');
  if (ocr) {
    validateRunOcrState(run, ocr);
    const expected = ocr.images.filter(i => ['discovered', 'captured', 'running', 'not_started', 'cancelled'].includes(i.status)).map(i => i.imageId);
    if (pending.length !== expected.length || expected.some(id => !pending.includes(id))) fail('pendingImageIds', 'must match pending OCR occurrences');
  }
}

/** Read-only V1 projection for legacy consumers during staged migration; never a product start contract. */
export function legacyRunSnapshot(snapshot: RunSnapshotV2): RunSnapshot {
  const { externalAnalysisConsent: _consent, ocrEnabled: _enabled, ocrModel: _model, imageCounts: _images, requestCounts: _requests, ...legacy } = snapshot;
  const { extraConfirmedFindings: _extra, ...counts } = snapshot.counts;
  return { ...legacy, counts, errors: snapshot.errors.filter(e => !['image', 'ocr'].includes(e.scope) && !['IMAGE_FETCH_ERROR', 'IMAGE_DECODE_ERROR', 'IMAGE_UNSUPPORTED', 'OCR_HTTP_ERROR', 'OCR_RESPONSE_INVALID', 'OCR_TIMEOUT', 'OCR_UNREADABLE'].includes(e.code)) as RunSnapshot['errors'] };
}
