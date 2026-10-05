import { describe, expect, it } from 'vitest';
import { validateOfficialResult, validateEntryUrl, validateRunSnapshot, validateReviewFile,
  validateFindingDetailsFile, validateEvidenceSnapshot, createAiAnalysis, classifyAiAnalysis,
  validateScanStatusFile, validateStartRunRequest, validatePublicConfig, validateApiErrorResponse,
  type AiChunk, type OfficialResult } from '../../src/core/index.js';

const result = (): OfficialResult => ({ meta: { topic: 'TOPIC', entry_url: 'https://example.org/',
  started_at: '2026-10-04T00:00:00.000Z', finished_at: '2026-10-04T00:00:01.000Z', elapsed_sec: 1 },
  findings: [{ id: 'f1', url: 'https://example.org/board?q=1', is_violation: true,
    location: 'iframe[src="https://ads.example/frame"] >>> p', evidence_text: '원문', technique: 'JAMO' }] });
const chunk = (overrides: Partial<AiChunk> = {}): AiChunk => ({ chunkId: 'c1', rawStart: 0, rawEnd: 2,
  status: 'completed', choice: 'illegal_ad', probabilities: { illegal_ad: .9, general_ad: .04, non_ad: .04, uncertain: .02 },
  confidence: .8, reasonCode: null, ...overrides });
const evidence = { snapshotId: 's1', path: null, sha256: null };

describe('official output contract', () => {
  it('permits flat positive findings and zero findings', () => {
    expect(() => validateOfficialResult(result())).not.toThrow();
    expect(() => validateOfficialResult({ ...result(), findings: [] })).not.toThrow();
  });
  it.each([
    (r: OfficialResult) => ({ ...r, success: true }),
    (r: OfficialResult) => ({ ...r, meta: { ...r.meta, elapsed_sec: NaN } }),
    (r: OfficialResult) => ({ ...r, meta: { ...r.meta, finished_at: 'yesterday' } }),
    (r: OfficialResult) => ({ ...r, findings: [{ ...r.findings[0], technique: ['JAMO'] }] }),
    (r: OfficialResult) => ({ ...r, findings: [{ ...r.findings[0], is_violation: false }] }),
    (r: OfficialResult) => ({ ...r, findings: [{ ...r.findings[0], evidence_text: undefined }] }),
    (r: OfficialResult) => ({ ...r, findings: [r.findings[0], { ...r.findings[0], location: 'p' }] }),
    (r: OfficialResult) => ({ ...r, findings: [r.findings[0], { ...r.findings[0], id: 'f2' }] }),
  ])('rejects malformed, extra and duplicate fields', (mutate) => {
    expect(() => validateOfficialResult(mutate(result()))).toThrow();
  });
  it('keeps two different techniques on the same element', () => {
    const r = result(); r.findings.push({ ...r.findings[0], id: 'f2', technique: 'OFFSCREEN' });
    expect(() => validateOfficialResult(r)).not.toThrow();
  });
});

describe('entry and internal contracts', () => {
  it.each(['relative', 'ftp://example.org/', 'https://user:pass@example.org/', '', 'javascript:alert(1)'])(
    'rejects invalid entry %s', (url) => expect(() => validateEntryUrl(url)).toThrow());
  it('preserves original absolute URL query and hash', () => {
    expect(validateEntryUrl('https://example.org/board?a=1#top')).toBe('https://example.org/board?a=1#top');
  });
  it('rejects negative counters and nonfinite elapsed time', () => {
    const run = { runId: 'r1', entryUrl: 'https://example.org/', startedAt: '2026-10-04T00:00:00.000Z',
      state: 'running', finishedAt: null, elapsedSec: 0, aiEnabled: false, model: null,
      counts: { discoveredPages: 0, scannedPages: 0, failedPages: 0, skippedPages: 0, pendingPages: 0,
        confirmedFindings: 0, reviewCandidates: 0 }, activeUrls: [], errors: [] };
    expect(() => validateRunSnapshot(run)).not.toThrow();
    expect(() => validateRunSnapshot({ ...run, elapsedSec: Infinity })).toThrow();
    expect(() => validateRunSnapshot({ ...run, counts: { ...run.counts, scannedPages: -1 } })).toThrow();
    expect(() => validateRunSnapshot({ ...run, state: 'completed' })).toThrow();
    const scan = { schemaVersion: 1, run, scope: { hostname: 'example.org', framePolicy: 'embedded', skipped: [], unvisitedUrls: [] },
      files: { resultPath: null, reviewPath: null, findingDetailsPath: null, evidenceDir: null, resultSha256: null }, resultSaved: false };
    expect(() => validateScanStatusFile(scan)).not.toThrow();
    expect(() => validateScanStatusFile({ ...scan, resultSaved: true })).toThrow();
    expect(() => validateScanStatusFile({ ...scan, files: { ...scan.files, resultPath: '../.env' } })).toThrow();
  });
  it('accepts only public API fields and the specified error code set', () => {
    expect(() => validateStartRunRequest({ entryUrl: 'https://example.org/', aiEnabled: false })).not.toThrow();
    expect(() => validateStartRunRequest({ entryUrl: 'https://example.org/', aiEnabled: false, apiKey: 'secret' })).toThrow();
    expect(() => validatePublicConfig({ aiConfigured: true, model: 'cloudflare/clef', outputRoot: '/output' })).not.toThrow();
    expect(() => validatePublicConfig({ aiConfigured: true, model: 'cloudflare/clef', outputRoot: '/output', apiKey: 'secret' })).toThrow();
    expect(() => validateApiErrorResponse({ error: { code: 'INVALID_CONFIG', message: 'Key missing' } })).not.toThrow();
    expect(() => validateApiErrorResponse({ error: { code: 'AI_NOT_CONFIGURED', message: 'Key missing' } })).toThrow();
  });
  it('checks review Unicode ranges and completed response fields', () => {
    const ai = createAiAnalysis([chunk({ rawEnd: 3, probabilities: { illegal_ad: .6, general_ad: .2, non_ad: .1, uncertain: .1 } })]);
    const review = { schemaVersion: 1, runId: 'r1', candidates: [{ candidateId: 'c1', url: 'https://example.org/',
      location: 'p', evidenceText: '😀x', techniques: ['JAMO'], reason: 'UNCERTAIN', ai, evidence }] };
    expect(() => validateReviewFile(review)).not.toThrow();
    expect(() => validateReviewFile({ ...review, candidates: [{ ...review.candidates[0], ai:
      createAiAnalysis([chunk({ rawEnd: 1 })]) }] })).toThrow();
    expect(() => validateReviewFile({ ...review, candidates: [{ ...review.candidates[0], techniques: ['JAMO', 'JAMO'] }] })).toThrow();
    expect(() => validateReviewFile({ ...review, candidates: [{ ...review.candidates[0], ai:
      { ...ai, chunks: [{ ...chunk(), probabilities: { illegal_ad: 1, general_ad: 1, non_ad: 1, uncertain: 1 } }] } }] })).toThrow();
  });
  it('rejects impossible dates, backwards timestamps and undefined optional fields', () => {
    expect(() => validateOfficialResult({ ...result(), meta: { ...result().meta, started_at: '2026-02-30T00:00:00Z' } })).toThrow();
    expect(() => validateOfficialResult({ ...result(), meta: { ...result().meta, finished_at: '2026-10-03T00:00:00Z' } })).toThrow();
    expect(() => validateOfficialResult({ ...result(), meta: { ...result().meta, tool_version: undefined } })).toThrow();
  });
  it('rejects active chunks in terminal files and mismatched review reasons', () => {
    const pending = createAiAnalysis([chunk({ status: 'pending', choice: null, probabilities: null, confidence: null })]);
    const candidate = { candidateId: 'c1', url: 'https://example.org/', location: 'p', evidenceText: '원문',
      techniques: ['JAMO'], reason: 'NOT_ANALYZED', ai: pending, evidence };
    const file = { schemaVersion: 1, runId: 'r1', candidates: [candidate] };
    expect(() => validateReviewFile(file)).not.toThrow();
    expect(() => validateReviewFile(file, true)).toThrow();
    expect(() => validateReviewFile({ ...file, candidates: [{ ...candidate, reason: 'AI_ERROR' }] })).toThrow();
  });
  it('preserves a local candidate cancelled before classification as not analyzed', () => {
    const candidate = { candidateId: 'c1', url: 'https://example.org/', location: 'p', evidenceText: '원문',
      techniques: ['OFFSCREEN'], reason: 'NOT_ANALYZED', ai: null, evidence };
    const file = { schemaVersion: 1, runId: 'r1', candidates: [candidate] };
    expect(() => validateReviewFile(file, true)).not.toThrow();
    expect(() => validateReviewFile({ ...file, candidates: [{ ...candidate, reason: 'AI_ERROR' }] }, true)).toThrow();
  });
  it('requires one matching detail per finding', () => {
    const details = { schemaVersion: 1, runId: 'r1', details: [{ findingId: 'f1', candidateId: 'c1',
      decisionSource: 'local', ruleIds: ['r1'], ai: null, evidence }] };
    expect(() => validateFindingDetailsFile(details, result())).not.toThrow();
    expect(() => validateFindingDetailsFile({ ...details, details: [] }, result())).toThrow();
    expect(() => validateFindingDetailsFile({ ...details, details: [{ ...details.details[0], findingId: 'other' }] }, result())).toThrow();
    expect(() => validateFindingDetailsFile({ ...details, details: [{ ...details.details[0], decisionSource: 'clef' }] }, result())).toThrow();
  });
  it('rejects completed AI choice contradicting the highest probability and permits ties', () => {
    const makeReview = (ai: ReturnType<typeof createAiAnalysis>) => ({ schemaVersion: 1, runId: 'r1', candidates: [{
      candidateId: 'c1', url: 'https://example.org/', location: 'p', evidenceText: '원문', techniques: ['JAMO'],
      reason: 'UNCERTAIN', ai, evidence }] });
    const inconsistent = createAiAnalysis([chunk({ choice: 'non_ad', probabilities: {
      illegal_ad: .9, non_ad: .1, general_ad: 0, uncertain: 0 } })]);
    expect(() => validateReviewFile(makeReview(inconsistent), true)).toThrow();
    const tied = createAiAnalysis([chunk({ choice: 'non_ad', probabilities: {
      illegal_ad: .5, non_ad: .5, general_ad: 0, uncertain: 0 } })]);
    expect(() => validateReviewFile(makeReview(tied), true)).not.toThrow();
  });
  it('rejects CLEF confirmed details whose completed chunks are wholly strong negative', () => {
    const ai = createAiAnalysis([chunk({ choice: 'non_ad', probabilities: {
      illegal_ad: .02, general_ad: .02, non_ad: .94, uncertain: .02 } })]);
    const details = { schemaVersion: 1, runId: 'r1', details: [{ findingId: 'f1', candidateId: 'c1',
      decisionSource: 'clef', ruleIds: [], ai, evidence }] };
    expect(() => validateFindingDetailsFile(details, result(), true)).toThrow();
    expect(() => validateFindingDetailsFile({ ...details, details: [{ ...details.details[0],
      ai: createAiAnalysis([chunk()]) }] }, result(), true)).not.toThrow();
  });
  it('checks evidence bounds, URL and fields without editing raw HTML', () => {
    const snapshot = { snapshotId: 's1', topPageUrl: 'https://example.org/', frameUrl: 'https://ads.example/',
      framePath: ['iframe[src="https://ads.example/"]'], capturedAt: '2026-10-04T00:00:00.000Z', html: '<p>원문</p>',
      elements: [{ location: 'p', rawText: '원문', styles: [{ elementLocation: 'p', css: { opacity: '0' },
        bounds: { x: 0, y: 0, width: 1, height: 1 } }] }] };
    expect(() => validateEvidenceSnapshot(snapshot)).not.toThrow();
    expect(() => validateEvidenceSnapshot({ ...snapshot, elements: [{ ...snapshot.elements[0], styles: [{
      ...snapshot.elements[0].styles[0], bounds: { x: NaN, y: 0, width: 1, height: 1 } }] }] })).toThrow();
  });
});

describe('AI summary scope and decision', () => {
  it('takes an actual strongest positive chunk, retains unfinished review', () => {
    const analysis = createAiAnalysis([chunk({ chunkId: 'later', rawStart: 2, rawEnd: 4 }),
      chunk({ chunkId: 'early', rawStart: 0 }), chunk({ chunkId: 'pending', rawStart: 4, rawEnd: 6,
        status: 'not_started', choice: null, probabilities: null, confidence: null, reasonCode: 'TIME_LIMIT' })]);
    expect(analysis.summaryChunkId).toBe('early');
    expect(classifyAiAnalysis(analysis)).toEqual({ confirmed: true, review: true, excluded: false, reason: 'NOT_ANALYZED' });
  });
  it('never converts failed or missing classification to a local decision', () => {
    const analysis = createAiAnalysis([chunk({ status: 'error', choice: null, probabilities: null,
      confidence: null, reasonCode: 'AI_HTTP_ERROR' })]);
    expect(analysis.summaryChunkId).toBeNull();
    expect(classifyAiAnalysis(analysis)).toEqual({ confirmed: false, review: true, excluded: false, reason: 'AI_ERROR' });
  });
  it('excludes only wholly strong negative chunks', () => {
    const analysis = createAiAnalysis([chunk({ choice: 'non_ad', probabilities: { illegal_ad: .02, general_ad: .02,
      non_ad: .94, uncertain: .02 } })]);
    expect(classifyAiAnalysis(analysis)).toEqual({ confirmed: false, review: false, excluded: true, reason: null });
    expect(classifyAiAnalysis(createAiAnalysis([chunk({ choice: 'illegal_ad', probabilities: {
      illegal_ad: .6, general_ad: .2, non_ad: .1, uncertain: .1 } })])).reason).toBe('UNCERTAIN');
  });
});
