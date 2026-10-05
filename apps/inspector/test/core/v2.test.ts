import { describe, expect, it } from 'vitest';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { createAiAnalysis } from '../../src/core/ai.js';
import { RunRegistryV2 } from '../../src/core/state-v2.js';
import { OCR_MODEL, type OcrImageOccurrence, type OcrFile, type ExtraResult, type FindingDetailsFileV2 } from '../../src/core/v2.js';
import { combineReadableImageText, imageOccurrenceKey, imageOwnerKey, countImages,
  validateOcrFile, validateStartRunRequestV2, validateRunSnapshotV2, validateFindingDetailsFileV2,
  validateReviewFileV2, validateResultPair, validateScanStatusFileV2 } from '../../src/core/validation-v2.js';
import { validateOfficialResult, validateScanStatusFile, validateReviewFile, validateFindingDetailsFile } from '../../src/core/validation.js';

const evidence = { snapshotId: 's1', path: null, sha256: null };
const image = (patch: Partial<OcrImageOccurrence> = {}): OcrImageOccurrence => ({
  imageId: 'i1', url: 'https://example.org/?a=1', frameUrl: 'about:srcdoc', framePath: ['#frame'],
  location: '#frame >>> #owner', snapshotId: 's1', sourceKind: 'img', sourceIndex: 0,
  imageUrl: 'https://assets.example/banner.png', capturedAt: '2026-10-04T00:00:00Z',
  original: { assetId: 'a1', path: null, sha256: null, mime: 'image/png', byteLength: 10 },
  input: { assetId: 'p1', path: null, sha256: null, mime: 'image/png', byteLength: 12, width: 2, height: 2, frameIndex: 0 },
  styles: [], concealment: [], status: 'completed', extractionStatus: 'readable', text: '😀한글', confidence: null,
  model: OCR_MODEL, promptVersion: 'v1', cacheOf: null, attemptCount: 1,
  usage: { promptTokens: null, completionTokens: null, totalTokens: null, costUsd: null }, reasonCode: null, ...patch,
});
const ocr = (images = [image()]): OcrFile => ({ schemaVersion: 2, runId: 'r1', enabled: true, model: OCR_MODEL, images });
const ai = createAiAnalysis([{ chunkId: 'ch1', rawStart: 0, rawEnd: 4, status: 'completed', choice: 'illegal_ad',
  probabilities: { illegal_ad: .9, general_ad: .04, non_ad: .04, uncertain: .02 }, confidence: .9, reasonCode: null }]);
const meta = { topic: 'TOPIC' as const, entry_url: 'https://example.org/', started_at: '2026-10-04T00:00:00Z', finished_at: '2026-10-04T00:00:01Z', elapsed_sec: 1 };
const official = { meta, findings: [{ id: 'f1', url: image().url, location: image().location, is_violation: true as const, technique: 'JAMO' as const, evidence_text: '😀한글' }] };
const extra: ExtraResult = { meta, findings: [{ id: 'f2', url: image().url, location: image().location, is_violation: true, technique: 'ETC', extra_finding: 'IMAGE_AD_OCR', evidence_text: '😀한글' }] };

describe('strict V2 execution boundary', () => {
  it.each([{ entryUrl: 'https://example.org/', aiEnabled: false }, { entryUrl: 'https://example.org/', ocrEnabled: false },
    { entryUrl: 'https://example.org/', ocrEnabled: true, externalAnalysisConsent: false },
    { entryUrl: 'https://example.org/', ocrEnabled: false, externalAnalysisConsent: true, apiKey: 'fixture' }])('rejects invalid product request %o', request => {
    expect(() => validateStartRunRequestV2(request)).toThrow();
  });
  it('rejects missing consent/key before allocating and freezes both confirmed counts during cancellation', () => {
    let ids = 0;
    const registry = new RunRegistryV2({ createRunId: () => `r${++ids}` });
    expect(() => registry.start({ entryUrl: 'https://example.org/', ocrEnabled: false, externalAnalysisConsent: true })).toThrow(/INVALID_CONFIG/);
    expect(ids).toBe(0);
    const handle = registry.start({ entryUrl: 'https://example.org/', ocrEnabled: false, externalAnalysisConsent: true, apiKey: 'fixture-key' });
    expect(handle.snapshot).toMatchObject({ aiEnabled: true, model: 'cloudflare/clef', ocrEnabled: false, ocrModel: null });
    expect(() => registry.start({ entryUrl: 'https://example.org/', ocrEnabled: true, externalAnalysisConsent: true, apiKey: 'fixture-key' })).toThrow(/ACTIVE_RUN/);
    registry.update(handle.snapshot.runId, { counts: { scannedPages: 1, extraConfirmedFindings: 1 } });
    let late = true;
    handle.signal.addEventListener('abort', () => { late = registry.update(handle.snapshot.runId, { counts: { extraConfirmedFindings: 99 } }); });
    registry.requestCancel(handle.snapshot.runId);
    expect(late).toBe(false);
    expect(() => registry.finish(handle.snapshot.runId, { saved: true, extraSaved: true, counts: { ...handle.snapshot.counts, scannedPages: 1 } })).toThrow();
    const done = registry.finish(handle.snapshot.runId, { saved: true, extraSaved: true });
    expect(done.state).toBe('cancelled');
    expect(done.counts.extraConfirmedFindings).toBe(1);
    expect(registry.finish(done.runId, { saved: false, extraSaved: false })).toEqual(done);
    expect(registry.requestCancel(done.runId)).toEqual(done);
  });
  it('fails either result save and allows complete runs with no-text review', () => {
    for (const extraSaved of [false, true]) {
      const registry = new RunRegistryV2();
      const { snapshot } = registry.start({ entryUrl: 'https://example.org/', ocrEnabled: true, externalAnalysisConsent: true, apiKey: 'fixture-key' });
      const file = { ...ocr([image({ extractionStatus: 'no_text', text: '' })]), runId: snapshot.runId };
      registry.update(snapshot.runId, { counts: { scannedPages: 1, reviewCandidates: 1 }, imageCounts: countImages(file.images), requestCounts: { ocr: 1 } });
      const terminal = registry.finish(snapshot.runId, { saved: true, extraSaved, ocr: file });
      expect(terminal.state).toBe(extraSaved ? 'completed' : 'failed');
      expect(() => validateRunSnapshotV2({ ...terminal, aiEnabled: false })).toThrow();
    }
  });
  it.each(['partial', 'unreadable'] as const)('derives partial completion from actual %s OCR even with empty errors', extractionStatus => {
    const registry = new RunRegistryV2({ createRunId: () => 'r1' });
    registry.start({ entryUrl: meta.entry_url, ocrEnabled: true, externalAnalysisConsent: true, apiKey: 'fixture-key' });
    const file = ocr([image({ extractionStatus, text: extractionStatus === 'partial' ? '일부' : '', reasonCode: 'OCR_UNREADABLE' })]);
    registry.update('r1', { counts: { scannedPages: 1, reviewCandidates: 1 }, imageCounts: countImages(file.images), requestCounts: { ocr: 1 } });
    const run = registry.finish('r1', { saved: true, extraSaved: true, ocr: file });
    expect(run.state).toBe('partial');
  });
  it('rejects selected completion without actual OCR records and leaves the run active', () => {
    const registry = new RunRegistryV2();
    const { snapshot } = registry.start({ entryUrl: meta.entry_url, ocrEnabled: true, externalAnalysisConsent: true, apiKey: 'fixture-key' });
    registry.update(snapshot.runId, { counts: { scannedPages: 1 } });
    expect(() => registry.finish(snapshot.runId, { saved: true, extraSaved: true })).toThrow();
    expect(registry.get(snapshot.runId)?.state).toBe('running');
  });
  it('preserves positive findings and actual request counts atomically through failure', () => {
    const registry = new RunRegistryV2();
    const { snapshot } = registry.start({ entryUrl: 'https://example.org/', ocrEnabled: true, externalAnalysisConsent: true, apiKey: 'fixture-key' });
    const file = { ...ocr(), runId: snapshot.runId };
    registry.update(snapshot.runId, { counts: { scannedPages: 1, confirmedFindings: 1, extraConfirmedFindings: 1 }, imageCounts: countImages(file.images), requestCounts: { ocr: 1, clef: 2 } });
    const before = registry.get(snapshot.runId);
    expect(() => registry.update(snapshot.runId, { counts: { confirmedFindings: 0 } })).toThrow();
    expect(() => registry.update(snapshot.runId, { requestCounts: { clef: 0 } })).toThrow();
    expect(registry.get(snapshot.runId)?.counts).toEqual(before?.counts);
    expect(() => registry.finish(snapshot.runId, { saved: false, extraSaved: false, counts: { ...snapshot.counts, scannedPages: 1 }, ocr: file })).toThrow();
    const terminal = registry.finish(snapshot.runId, { saved: false, extraSaved: false, ocr: file });
    expect(terminal).toMatchObject({ state: 'failed', counts: { confirmedFindings: 1, extraConfirmedFindings: 1 }, requestCounts: { ocr: 1, clef: 2 } });
  });
  it('removes configured keys, authorization headers and PNG payloads from stored diagnostics', () => {
    const registry = new RunRegistryV2();
    const { snapshot } = registry.start({ entryUrl: 'https://example.org/', ocrEnabled: true, externalAnalysisConsent: true, apiKey: 'fixture-key' });
    registry.update(snapshot.runId, { errors: [{ scope: 'ocr', code: 'OCR_HTTP_ERROR', url: null, candidateId: null,
      message: 'fixture-key Authorization: Basic private-fixture\nCookie: session=fixture-cookie\ndata:image/png;base64,QUJDRA==' }] });
    const serialized = JSON.stringify(registry.get(snapshot.runId));
    for (const value of ['fixture-key', 'private-fixture', 'fixture-cookie', 'QUJDRA==']) expect(serialized).not.toContain(value);
  });
});

describe('OCR occurrence, read status and UTF-16 ownership', () => {
  it('preserves occurrences but groups one owner and orders only readable assets', () => {
    const images = [image({ imageId: 'after', sourceKind: 'css_after', text: '끝' }), image(),
      image({ imageId: 'partial', sourceKind: 'css_background', extractionStatus: 'partial', text: '일부', reasonCode: 'OCR_UNREADABLE' })];
    expect(new Set(images.map(imageOccurrenceKey)).size).toBe(3);
    expect(new Set(images.map(imageOwnerKey)).size).toBe(1);
    expect(imageOccurrenceKey(image({ url: 'https://example.org/?a=2' }))).not.toBe(imageOccurrenceKey(image()));
    expect(combineReadableImageText(images)).toEqual({ rawText: '😀한글\n끝', sourceTextRanges: [
      { imageId: 'i1', rawStart: 0, rawEnd: 4 }, { imageId: 'after', rawStart: 5, rawEnd: 6 }] });
    expect(() => validateOcrFile(ocr(images), true)).not.toThrow();
    expect(countImages(images)).toEqual({ discovered: 3, captured: 3, ocrCompleted: 3, failed: 0, pending: 0, skipped: 0 });
  });
  it.each<Partial<OcrImageOccurrence>>([{ confidence: .9 as never }, { sourceIndex: 1 }, { extractionStatus: 'no_text' },
    { extractionStatus: 'unreadable', text: '' }, { status: 'running' }, { attemptCount: -1 },
    { imageUrl: 'data:image/png;base64,AAAA' }, { concealment: ['OFFSCREEN', 'OFFSCREEN'] },
    { input: { ...image().input!, mime: 'image/svg+xml' } }, { cacheOf: 'missing', attemptCount: 0 }])('rejects invalid OCR state %o', patch => {
    expect(() => validateOcrFile(ocr([image(patch)]), true)).toThrow();
  });
  it.each([
    ['error', 'IMAGE_DECODE_ERROR', 'text/html'], ['error', 'IMAGE_DECODE_ERROR', 'application/octet-stream'],
    ['unsupported', 'IMAGE_UNSUPPORTED', 'text/html'], ['unsupported', 'IMAGE_UNSUPPORTED', 'application/octet-stream'],
  ] as const)('preserves fetched original bytes with actual MIME for %s/%s/%s', (status, reasonCode, mime) => {
    const bytes = mime === 'text/html' ? Buffer.from('<html>fixture response</html>') : Buffer.from([0, 255, 1, 254]);
    const original = { assetId: 'original-response', path: 'images/original-response.bin',
      sha256: createHash('sha256').update(bytes).digest('hex'), mime, byteLength: bytes.length };
    const occurrence = image({ original, input: null, status, reasonCode, extractionStatus: null, text: null, attemptCount: 0 });
    expect(() => validateOcrFile(ocr([occurrence]), true)).not.toThrow();
    expect(occurrence.original).toEqual(original);
    expect(countImages([occurrence])).toMatchObject({ captured: 1, ocrCompleted: 0, failed: status === 'error' ? 1 : 0, skipped: status === 'unsupported' ? 1 : 0 });
  });
  it.each(['text/html', 'application/octet-stream', 'image/svg+xml', 'IMAGE/PNG'])('rejects %s as the OCR input MIME', mime => {
    expect(() => validateOcrFile(ocr([image({ input: { ...image().input!, mime } })]), true)).toThrow();
  });
  it.each(['', 'text/html; charset=utf-8', 'text/html\r\nX-Header: injected', 'text/ht\0ml', ' text/html',
    'text/html ', 'text /html', 'text', 'text/html/extra', 'text/*'])('rejects unsafe or unnormalized original MIME %s', mime => {
    expect(() => validateOcrFile(ocr([image({ original: { ...image().original!, mime }, input: null,
      status: 'error', reasonCode: 'IMAGE_DECODE_ERROR', extractionStatus: null, text: null, attemptCount: 0 })]), true)).toThrow();
  });
  it('requires not-selected images to have no assets, requests or inferred results', () => {
    const skipped = image({ status: 'not_selected', model: null, original: null, input: null, capturedAt: null, attemptCount: 0,
      extractionStatus: null, text: null, reasonCode: 'OCR_NOT_SELECTED' });
    const file = { ...ocr([skipped]), enabled: false, model: null };
    expect(() => validateOcrFile(file, true)).not.toThrow();
    expect(() => validateOcrFile({ ...file, images: [{ ...skipped, original: image().original }] }, true)).toThrow();
  });
  it('validates completed caches against model/version/input hash without merging source identity', () => {
    const original = image({ input: { ...image().input!, path: 'images/p1.png', sha256: 'a'.repeat(64) } });
    const cached = image({ imageId: 'i2', location: '#other', cacheOf: 'i1', attemptCount: 0, input: { ...original.input!, assetId: 'p2', path: 'images/p2.png' } });
    expect(() => validateOcrFile(ocr([original, cached]), true)).not.toThrow();
    expect(() => validateOcrFile(ocr([original, { ...cached, promptVersion: 'different' }]), true)).toThrow();
    expect(() => validateOcrFile(ocr([original, { ...cached, text: 'invented' }]), true)).toThrow();
  });
  it('allows a valid no-text completion cache but rejects incomplete OCR caches', () => {
    const original = image({ extractionStatus: 'no_text', text: '', input: { ...image().input!, path: 'images/p1.png', sha256: 'a'.repeat(64) } });
    const cached = { ...original, imageId: 'i2', location: '#other', cacheOf: 'i1', attemptCount: 0, input: { ...original.input!, assetId: 'p2', path: 'images/p2.png' } };
    expect(() => validateOcrFile(ocr([original, cached]), true)).not.toThrow();
    const partial = { ...original, extractionStatus: 'partial' as const, text: '일부', reasonCode: 'OCR_UNREADABLE' as const };
    expect(() => validateOcrFile(ocr([partial, { ...cached, extractionStatus: 'partial', text: '일부', reasonCode: 'OCR_UNREADABLE' }]), true)).toThrow();
  });
  it('rejects conflicting registered assets and preserves one owner identity across frames', () => {
    const other = image({ imageId: 'i2', framePath: ['#otherframe'], location: '#otherframe >>> #owner', input: { ...image().input!, width: 3 } });
    expect(imageOwnerKey(other)).not.toBe(imageOwnerKey(image()));
    expect(() => validateOcrFile(ocr([image(), other]), true)).toThrow();
  });
  it('accepts repeated frame selectors in different nesting levels', () => {
    expect(() => validateOcrFile(ocr([image({ framePath: ['iframe#same', 'iframe#same'], location: 'iframe#same >>> iframe#same >>> #owner' })]), true)).not.toThrow();
  });
});

it('reads fixed V1 fixture bytes and preserves its SHA without V2 migration writes', async () => {
  const fixture = new URL('./fixtures/contracts-v1.json', import.meta.url);
  const before = await readFile(fixture);
  const expectedSha = '3fd88967884903dbac3af424085c9dcd545d1a7760e8d9f12d24b809bec45106';
  expect(createHash('sha256').update(before).digest('hex')).toBe(expectedSha);
  const archive = JSON.parse(before.toString());
  validateOfficialResult(archive.result); validateScanStatusFile(archive.status); validateReviewFile(archive.review);
  validateFindingDetailsFile(archive.details, archive.result);
  expect(archive.status.run).toMatchObject({ aiEnabled: false, model: null });
  expect(archive.details.details[0].decisionSource).toBe('local');
  const after = await readFile(fixture);
  expect(after.equals(before)).toBe(true);
  expect(createHash('sha256').update(after).digest('hex')).toBe(expectedSha);
});

describe('two result files and linked V2 detail/review', () => {
  const details = (): FindingDetailsFileV2 => ({ schemaVersion: 2, runId: 'r1', details: [
    { findingId: 'f1', candidateId: 'dom', decisionSource: 'clef', ruleIds: [], ai, evidence,
      resultFile: 'result.json', sourceType: 'dom_text', sourceIds: [], sourceTextRanges: [], observationIds: ['obs1'] },
    { findingId: 'f2', candidateId: 'image', decisionSource: 'clef', ruleIds: [], ai, evidence,
      resultFile: 'result_extra.json', sourceType: 'image_ocr', sourceIds: ['i1'], sourceTextRanges: [{ imageId: 'i1', rawStart: 0, rawEnd: 4 }], observationIds: [] },
  ] });
  it('enforces cross-file IDs and exactly one CLEF-only detail for each result', () => {
    expect(() => validateResultPair(official, extra)).not.toThrow();
    expect(() => validateResultPair(official, { ...extra, findings: [{ ...extra.findings[0], id: 'f1' }] })).toThrow();
    expect(() => validateFindingDetailsFileV2(details(), official, extra, ocr(), true)).not.toThrow();
    expect(() => validateFindingDetailsFileV2({ ...details(), details: details().details.slice(1) }, official, extra, ocr(), true)).toThrow();
    for (const patch of [{ sourceIds: ['missing'] }, { sourceTextRanges: [{ imageId: 'i1', rawStart: 1, rawEnd: 4 }] },
      { decisionSource: 'local' }, { resultFile: 'result.json' }, { sourceTextRanges: [] }]) {
      expect(() => validateFindingDetailsFileV2({ ...details(), details: [details().details[0], { ...details().details[1], ...patch }] }, official, extra, ocr(), true)).toThrow();
    }
  });
  it('retains no-text image review without CLEF and rejects local or mismatched reason/ranges', () => {
    const noText = ocr([image({ extractionStatus: 'no_text', text: '' })]);
    const candidate = { candidateId: 'image', url: image().url, location: image().location, evidenceText: '', techniques: [],
      sourceType: 'image_ocr', sourceIds: ['i1'], sourceTextRanges: [], reason: 'OCR_NO_TEXT', ai: null, evidence };
    const review = { schemaVersion: 2, runId: 'r1', candidates: [candidate] };
    expect(() => validateReviewFileV2(review, noText, true)).not.toThrow();
    expect(() => validateReviewFileV2({ ...review, candidates: [{ ...candidate, techniques: ['TRANSPARENT'] }] }, noText, true)).toThrow();
    expect(() => validateReviewFileV2({ ...review, candidates: [{ ...candidate, reason: 'UNCERTAIN' }] }, noText, true)).toThrow();
    expect(() => validateReviewFileV2({ ...review, candidates: [candidate, { ...candidate, candidateId: 'duplicate-owner' }] }, noText, true)).toThrow();
    expect(() => validateReviewFileV2({ ...review, candidates: [candidate, { ...candidate, candidateId: 'duplicate-owner' }] }, undefined, true)).toThrow();
    const domCandidate = { ...candidate, candidateId: 'dom-owner', sourceType: 'dom_text', sourceIds: [], techniques: ['JAMO'], evidenceText: '직접 원문', reason: 'NOT_ANALYZED' };
    expect(() => validateReviewFileV2({ ...review, candidates: [candidate, domCandidate] }, noText, true)).not.toThrow();
    expect(() => validateReviewFileV2({ ...review, candidates: [domCandidate, { ...domCandidate, candidateId: 'second-dom-id' }] }, noText, true)).toThrow();
  });
  it('preserves a confirmed readable asset alongside another asset with incomplete OCR', () => {
    const partial = image({ imageId: 'partial', sourceKind: 'css_background', extractionStatus: 'partial', text: '일부', reasonCode: 'OCR_UNREADABLE' });
    const file = ocr([image(), partial]);
    const detail = { ...details().details[1], sourceIds: ['i1', 'partial'] };
    expect(() => validateFindingDetailsFileV2({ ...details(), details: [details().details[0], detail] }, official, extra, file, true)).not.toThrow();
    const review = { schemaVersion: 2, runId: 'r1', candidates: [{ candidateId: detail.candidateId, url: extra.findings[0].url,
      location: extra.findings[0].location, evidenceText: extra.findings[0].evidence_text, techniques: [], reason: 'OCR_UNREADABLE',
      ai, evidence, sourceType: detail.sourceType, sourceIds: detail.sourceIds, sourceTextRanges: detail.sourceTextRanges }] };
    expect(() => validateReviewFileV2(review, file, true)).not.toThrow();
  });
  it.each(['finding-details', 'review'] as const)('validates persisted %s ranges by ordered values, regardless of JSON object key order', async target => {
    const images = [image(),
      image({ imageId: 'partial', sourceKind: 'css_background', extractionStatus: 'partial', text: '일부', reasonCode: 'OCR_UNREADABLE' }),
      image({ imageId: 'tail', sourceKind: 'css_after', text: '끝' })];
    const combined = combineReadableImageText(images);
    const imageDetail = { ...details().details[1], sourceIds: images.map(i => i.imageId), sourceTextRanges: combined.sourceTextRanges };
    const bundle = { official, extra: { ...extra, findings: [{ ...extra.findings[0], evidence_text: combined.rawText }] },
      details: { ...details(), details: [details().details[0], imageDetail] }, ocr: ocr(images),
      review: { schemaVersion: 2, runId: 'r1', candidates: [{ candidateId: imageDetail.candidateId, url: images[0].url,
        location: images[0].location, evidenceText: combined.rawText, techniques: [], reason: 'OCR_UNREADABLE', ai, evidence,
        sourceType: imageDetail.sourceType, sourceIds: imageDetail.sourceIds, sourceTextRanges: combined.sourceTextRanges }] } };
    const directory = await mkdtemp(join(tmpdir(), 'inspector-core-range-roundtrip-'));
    try {
      const path = join(directory, `${target}.json`);
      // The output serializer sorts object keys while preserving arrays and captured Unicode strings.
      await writeFile(path, JSON.stringify(bundle, (_key, value: unknown) => value !== null && typeof value === 'object' && !Array.isArray(value)
        ? Object.fromEntries(Object.entries(value).sort(([a], [b]) => a.localeCompare(b))) : value));
      const persisted = JSON.parse(await readFile(path, 'utf8')) as typeof bundle;
      const ranges = target === 'finding-details' ? persisted.details.details[1].sourceTextRanges : persisted.review.candidates[0].sourceTextRanges;
      expect(Object.keys(ranges[0])).toEqual(['imageId', 'rawEnd', 'rawStart']);
      expect(Object.keys(combined.sourceTextRanges[0])).toEqual(['imageId', 'rawStart', 'rawEnd']);
      const validate = () => target === 'finding-details'
        ? validateFindingDetailsFileV2(persisted.details, persisted.official, persisted.extra, persisted.ocr, true)
        : validateReviewFileV2(persisted.review, persisted.ocr, true);
      expect(validate).not.toThrow();
      const expectedRanges = structuredClone(ranges);
      for (const patch of [{ imageId: 'partial' }, { rawStart: 2 }, { rawEnd: 3 }]) {
        Object.assign(ranges[0], patch);
        expect(validate).toThrow();
        Object.assign(ranges[0], expectedRanges[0]);
      }
      ranges.reverse();
      expect(validate).toThrow();
    } finally { await rm(directory, { recursive: true, force: true }); }
  });
  it('rejects fabricated image positives without readable text or with a zero-length positive chunk', () => {
    const emptyAi = createAiAnalysis([{ ...ai.chunks[0], rawStart: 0, rawEnd: 0 }]);
    const noText = ocr([image({ extractionStatus: 'no_text', text: '' })]);
    const noTextExtra = { ...extra, findings: [{ ...extra.findings[0], evidence_text: '' }] };
    const noTextDetails = { ...details(), details: [details().details[0], { ...details().details[1], ai: emptyAi, sourceTextRanges: [] }] };
    expect(() => validateFindingDetailsFileV2(noTextDetails, official, noTextExtra, noText, true)).toThrow();
    expect(() => validateFindingDetailsFileV2({ ...details(), details: [details().details[0], { ...details().details[1], ai: emptyAi }] }, official, extra, ocr(), true)).toThrow();
    expect(() => validateFindingDetailsFileV2(details(), official, extra, undefined, true)).toThrow();
  });
  it('cross-checks V2 status/image counts and save flags', () => {
    const registry = new RunRegistryV2({ createRunId: () => 'r1' });
    const { snapshot } = registry.start({ entryUrl: meta.entry_url, ocrEnabled: true, externalAnalysisConsent: true, apiKey: 'fixture-key' });
    registry.update(snapshot.runId, { counts: { scannedPages: 1 }, imageCounts: countImages(ocr().images), requestCounts: { ocr: 1, clef: 0 } });
    const run = registry.finish('r1', { saved: true, extraSaved: true, ocr: ocr() });
    const status = { schemaVersion: 2, run, scope: { hostname: 'example.org', framePolicy: 'embedded', skipped: [], unvisitedUrls: [] },
      files: { resultPath: 'result.json', resultSha256: 'a'.repeat(64), extraResultPath: 'result_extra.json', extraResultSha256: 'b'.repeat(64),
        reviewPath: null, findingDetailsPath: null, evidenceDir: null, ocrPath: null }, resultSaved: true, extraResultSaved: true,
      imageScope: { enabled: true, framePolicy: 'first', unsupportedKinds: ['canvas', 'video', 'animation_remaining_frames'], pendingImageIds: [] } };
    expect(() => validateScanStatusFileV2(status, ocr())).not.toThrow();
    expect(() => validateScanStatusFileV2({ ...status, run: { ...run, imageCounts: { ...run.imageCounts, discovered: 0 } } }, ocr())).toThrow();
    expect(() => validateScanStatusFileV2({ ...status, extraResultSaved: false }, ocr())).toThrow();
    const partial = ocr([image({ extractionStatus: 'partial', text: '일부', reasonCode: 'OCR_UNREADABLE' })]);
    expect(() => validateScanStatusFileV2(status, partial)).toThrow();
    expect(() => validateScanStatusFileV2(status)).toThrow();
  });
});
