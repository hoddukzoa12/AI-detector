import { afterEach, expect, it } from 'vitest';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { emptyImageCounts, emptyRequestCounts, emptyRunCountsV2 } from '../../src/core/state-v2.js';
import type { SaveArtifactsInputV2 } from '../../src/output/store-v2.js';
import { OutputStoreV2 } from '../../src/output/store-v2.js';
const roots: string[] = [];
afterEach(async () => { await Promise.all(roots.splice(0).map(p => rm(p, { recursive: true, force: true }))); });
async function root() { const p = await mkdtemp(join(tmpdir(), 'output-v2-')); roots.push(p); return p; }
function input(runId = 'v2-1'): SaveArtifactsInputV2 {
  return { run: { runId, entryUrl: 'https://example.org/', startedAt: '2026-10-01T00:00:00Z', finishedAt: '2026-10-01T00:00:01Z', elapsedSec: 1,
    state: 'completed', aiEnabled: true, model: 'cloudflare/clef', externalAnalysisConsent: true, ocrEnabled: false, ocrModel: null,
    counts: { ...emptyRunCountsV2(), discoveredPages: 1, scannedPages: 1 }, imageCounts: emptyImageCounts(), requestCounts: emptyRequestCounts(), activeUrls: [], errors: [] },
    scope: { hostname: 'example.org', framePolicy: 'embedded', skipped: [], unvisitedUrls: [] }, findings: [], extraFindings: [],
    review: { schemaVersion: 2, runId, candidates: [] }, details: { schemaVersion: 2, runId, details: [] },
    ocr: { schemaVersion: 2, runId, enabled: false, model: null, images: [] }, snapshots: [] };
}
async function start(store: OutputStoreV2, v: SaveArtifactsInputV2) { return store.beginRun({ ...v.run, state: 'running', finishedAt: null }, v.scope); }
it('always saves both empty UTF8 results and actual OCR, then reads after restart', async () => {
  const p = await root(), store = new OutputStoreV2(p), v = input(); await start(store, v);
  const saved = await store.saveArtifacts(v);
  expect(saved.result.meta).toEqual(saved.extraResult.meta); expect(saved.extraResult.findings).toEqual([]);
  expect(saved.status.extraResultSaved).toBe(true); expect(saved.status.imageScope.enabled).toBe(false);
  for (const name of ['result.json', 'result_extra.json', 'ocr.json'] as const) {
    const bytes = await new OutputStoreV2(p).readFile(v.run.runId, name);
    expect(bytes.subarray(0, 3)).not.toEqual(Buffer.from([239, 187, 191]));
  }
  expect(await new OutputStoreV2(p).readLatest()).toEqual(saved);
});
it('retains previous latest identity when the next canonical replacement fails', async () => {
  const p = await root(), store = new OutputStoreV2(p), old = input('old'); await start(store, old); await store.saveArtifacts(old);
  const marker = await readFile(join(p, 'latest.json'));
  const broken = new OutputStoreV2(p, { beforeOperation: ({ operation, path }) => { if (operation === 'rename' && path === 'result_extra.json') throw new Error('EACCES'); } });
  const next = input('new'); await start(broken, next);
  await expect(broken.saveArtifacts(next)).rejects.toMatchObject({ failureStatus: { run: { state: 'failed' } } });
  expect(await readFile(join(p, 'latest.json'))).toEqual(marker);
  expect((await new OutputStoreV2(p).readLatest())?.status.run.runId).toBe('old');
  expect(JSON.parse((await broken.readFile('new', 'scan-status.json')).toString()).run.state).toBe('failed');
});
it('requires actual terminal OCR, even when no images were found', async () => {
  const store = new OutputStoreV2(await root()), v = input(); v.run.ocrEnabled = true; v.run.ocrModel = 'google/gemini-3.8-flash';
  v.ocr.enabled = true; v.ocr.model = v.run.ocrModel; await start(store, v);
  await expect(store.saveArtifacts({ ...v, ocr: undefined } as unknown as SaveArtifactsInputV2)).rejects.toThrow();
  await expect(store.saveArtifacts(v)).resolves.toMatchObject({ ocr: { images: [] } });
});

import { writeFile, symlink, stat } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import type { CapturedImageAssets, OcrImageOccurrence } from '../../src/core/v2.js';
import { countImages } from '../../src/core/validation-v2.js';
import { OutputStore } from '../../src/output/store.js';
import { emptyRunCounts } from '../../src/core/state.js';
const sha = (b: Buffer) => createHash('sha256').update(b).digest('hex');
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD4cAAAAASUVORK5CYII=', 'base64');
async function scratch(bytes = png): Promise<CapturedImageAssets> {
  const p = await root(), path = join(p, 'image.png'); await writeFile(path, bytes, { mode: 0o600 });
  return { imageId: 'i1', capturedAt: '2026-10-01T00:00:00Z', original: { scratchPath: path, sha256: sha(bytes), byteLength: bytes.length, mime: 'image/png' },
    input: { scratchPath: path, sha256: sha(bytes), byteLength: bytes.length, mime: 'image/png', width: 1, height: 1, frameIndex: 0 } };
}
function imageInput(runId = 'images'): SaveArtifactsInputV2 {
  const v = input(runId); v.run.ocrEnabled = true; v.run.ocrModel = 'google/gemini-3.8-flash'; v.ocr.enabled = true; v.ocr.model = v.run.ocrModel;
  v.snapshots = [{ snapshotId: 's1', topPageUrl: v.run.entryUrl, frameUrl: 'https://example.org/frame', framePath: ['iframe:nth-of-type(1)'],
    capturedAt: v.run.startedAt, html: '<html>원문 대출 😀</html>', elements: [] }]; return v;
}
function occurrence(v: SaveArtifactsInputV2, refs: Awaited<ReturnType<OutputStoreV2['registerImageAssets']>>, imageId = 'i1'): OcrImageOccurrence {
  return { imageId, url: v.run.entryUrl, frameUrl: v.snapshots[0].frameUrl, framePath: v.snapshots[0].framePath, location: 'iframe:nth-of-type(1) >>> #banner',
    snapshotId: 's1', sourceKind: 'img', sourceIndex: 0, imageUrl: 'https://example.org/banner.png', capturedAt: v.run.startedAt, ...refs,
    styles: [{ elementLocation: 'iframe:nth-of-type(1) >>> #banner', css: { opacity: '0' }, bounds: { x: 0, y: 0, width: 1, height: 1 } }], concealment: ['TRANSPARENT'],
    status: 'completed', extractionStatus: 'readable', text: '한글 😀', confidence: null, model: 'google/gemini-3.8-flash', promptVersion: 'v1', cacheOf: null,
    attemptCount: 1, usage: { promptTokens: null, completionTokens: null, totalTokens: null, costUsd: null }, reasonCode: null };
}
function positiveAi(text: string) {
  const probabilities = { illegal_ad: .9, general_ad: .05, non_ad: .04, uncertain: .01 };
  return { model: 'cloudflare/clef' as const, summaryChunkId: 'chunk1', choice: 'illegal_ad' as const, probabilities, confidence: .9,
    chunks: [{ chunkId: 'chunk1', rawStart: 0, rawEnd: text.length, status: 'completed' as const, choice: 'illegal_ad' as const, probabilities, confidence: .9, reasonCode: null }] };
}
function positive(v: SaveArtifactsInputV2) {
  const text = v.ocr.images[0].text!, source = { sourceType: 'image_ocr' as const, sourceIds: v.ocr.images.map(i => i.imageId), sourceTextRanges: [{ imageId: 'i1', rawStart: 0, rawEnd: text.length }] };
  v.extraFindings = [{ id: 'extra1', url: v.run.entryUrl, is_violation: true, location: v.ocr.images[0].location, evidence_text: text, technique: 'ETC', extra_finding: 'IMAGE_AD_OCR' }];
  v.details.details = [{ findingId: 'extra1', candidateId: 'c1', decisionSource: 'clef', ruleIds: [], ai: positiveAi(text), evidence: { snapshotId: 's1', path: null, sha256: null },
    resultFile: 'result_extra.json', observationIds: [], ...source }];
  v.run.counts.extraConfirmedFindings = 1; v.run.imageCounts = countImages(v.ocr.images); v.run.requestCounts.ocr = v.ocr.images.reduce((s, i) => s + i.attemptCount, 0); return source;
}
it('registers identical original/input bytes under distinct role IDs, preserves OCR/raw DOM and internal frame style locations', async () => {
  const p = await root(), store = new OutputStoreV2(p), v = imageInput(); await start(store, v);
  const refs = await store.registerImageAssets(v.run.runId, await scratch());
  expect(refs.original.sha256).toBe(refs.input.sha256); expect(refs.original.assetId).not.toBe(refs.input.assetId);
  v.ocr.images = [occurrence(v, refs)]; positive(v); const original = structuredClone(v);
  const saved = await store.saveArtifacts(v); expect(v).toEqual(original);
  expect(saved.ocr.images[0].styles[0].elementLocation).toBe('#banner');
  expect(await store.readImage(v.run.runId, refs.input.assetId)).toEqual(png);
  await expect(store.readImage(v.run.runId, refs.original.assetId)).rejects.toMatchObject({ code: 'NOT_FOUND' });
  expect((await stat(join(p, refs.input.path!))).mode & 0o777).toBe(0o600);
  expect((await stat(join(p, 'runs/images/images'))).mode & 0o777).toBe(0o700);
  expect(JSON.parse((await store.readEvidence(v.run.runId, 's1')).toString()).html).toBe(v.snapshots[0].html);
  expect(saved.status.files.extraResultSha256).toBe(sha(await store.readFile(v.run.runId, 'result_extra.json')));
  await expect(store.readImage(v.run.runId, '../image.png')).rejects.toThrow();
  await expect(store.readImage(v.run.runId, 'unregistered')).rejects.toMatchObject({ code: 'NOT_FOUND' });
  await rm(join(p, refs.input.path!)); await symlink('/etc/hosts', join(p, refs.input.path!));
  await expect(store.readImage(v.run.runId, refs.input.assetId)).rejects.toThrow();
});
it('preserves different original assets, shared PNG cache relations and all assets for one owner', async () => {
  const store = new OutputStoreV2(await root()), v = imageInput(); await start(store, v);
  const a = await scratch(), b = await scratch(); const bbytes = Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"/>');
  const bp = join(await root(), 'original.svg'); await writeFile(bp, bbytes); b.original = { scratchPath: bp, sha256: sha(bbytes), byteLength: bbytes.length, mime: 'image/svg+xml' };
  const r1 = await store.registerImageAssets(v.run.runId, a), r2 = await store.registerImageAssets(v.run.runId, b);
  const i1 = occurrence(v, r1), i2 = { ...occurrence(v, r2, 'i2'), sourceKind: 'css_background' as const, extractionStatus: 'no_text' as const, text: '' };
  const i3 = { ...occurrence(v, r2, 'i3'), location: 'iframe:nth-of-type(1) >>> #other', cacheOf: 'i1', attemptCount: 0 };
  v.ocr.images = [i1, i2, i3]; positive(v);
  v.details.details[0].sourceIds = ['i1', 'i2'];
  v.review.candidates = [{ candidateId: 'c1', url: v.run.entryUrl, location: i1.location, evidenceText: i1.text!, techniques: [], reason: 'OCR_NO_TEXT', ai: positiveAi(i1.text!),
    evidence: { snapshotId: 's1', path: null, sha256: null }, sourceType: 'image_ocr', sourceIds: ['i1', 'i2'], sourceTextRanges: [{ imageId: 'i1', rawStart: 0, rawEnd: i1.text!.length }] }];
  v.run.counts.reviewCandidates = 1;
  const saved = await store.saveArtifacts(v); expect(saved.ocr.images[2].cacheOf).toBe('i1'); expect(saved.ocr.images[2].original?.sha256).not.toBe(saved.ocr.images[0].original?.sha256);
  await expect(store.readImage(v.run.runId, r2.original.assetId)).rejects.toThrow();
});
it('preserves original-only bytes after decode failure and records failed image work', async () => {
  const store = new OutputStoreV2(await root()), v = imageInput(); await start(store, v); const a = await scratch();
  const original = await store.registerOriginalAsset(v.run.runId, a.original);
  const i = occurrence(v, { original, input: null as never }); i.input = null; i.status = 'error'; i.extractionStatus = null; i.text = null; i.attemptCount = 0; i.reasonCode = 'IMAGE_DECODE_ERROR';
  v.ocr.images = [i]; v.run.state = 'partial'; v.run.imageCounts = countImages(v.ocr.images);
  expect((await store.saveArtifacts(v)).ocr.images[0].original?.sha256).toBe(sha(png));
});
it.each(['partial', 'unreadable'] as const)('rejects completed run for %s OCR response despite all requests completing', async extractionStatus => {
  const store = new OutputStoreV2(await root()), v = imageInput(); await start(store, v);
  const refs = await store.registerImageAssets(v.run.runId, await scratch()); const i = occurrence(v, refs); i.extractionStatus = extractionStatus; i.text = ''; i.reasonCode = 'OCR_UNREADABLE';
  v.ocr.images = [i]; v.run.imageCounts = countImages(v.ocr.images); v.run.requestCounts.ocr = 1;
  await expect(store.saveArtifacts(v)).rejects.toThrow();
});
it('rejects forged registration, scratch symlink/oversize/hash mismatch and actual image write failure', async () => {
  for (const fault of ['symlink', 'size', 'hash', 'write'] as const) {
    const p = await root(), v = imageInput(), store = new OutputStoreV2(p, { beforeOperation: ({ operation, path }) => { if (fault === 'write' && operation === 'write' && path.includes('/images/')) throw new Error('EACCES'); } }); await start(store, v);
    const a = await scratch(); if (fault === 'symlink') { const path = join(await root(), 'link.png'); await symlink(a.original.scratchPath, path); a.original.scratchPath = path; }
    if (fault === 'size') a.original.byteLength = 8 * 1024 * 1024 + 1;
    if (fault === 'hash') a.original.sha256 = '0'.repeat(64);
    await expect(store.registerImageAssets(v.run.runId, a)).rejects.toThrow();
    await expect(store.saveArtifacts(v)).rejects.toMatchObject({ failureStatus: { run: { state: 'failed' }, resultSaved: false, extraResultSaved: false } });
  }
});
it('reads V1 archives independently after restart and preserves every archived byte', async () => {
  const p = await root(), old = new OutputStore(p), v = input('legacy');
  const run = { runId: 'legacy', entryUrl: v.run.entryUrl, startedAt: v.run.startedAt, finishedAt: v.run.finishedAt, elapsedSec: 1, state: 'completed' as const,
    aiEnabled: false, model: null, counts: emptyRunCounts(), activeUrls: [], errors: [] };
  const scope = { hostname: 'example.org', framePolicy: 'embedded' as const, skipped: [], unvisitedUrls: [] };
  await old.beginRun({ ...run, state: 'running', finishedAt: null }, scope);
  await old.saveArtifacts({ run, scope, findings: [], review: { schemaVersion: 1, runId: 'legacy', candidates: [] }, details: { schemaVersion: 1, runId: 'legacy', details: [] }, snapshots: [] });
  const names = ['result.json', 'review.json', 'finding-details.json', 'scan-status.json', 'manifest.json'];
  const before = await Promise.all(names.map(n => readFile(join(p, 'runs/legacy', n))));
  const next = new OutputStoreV2(p); expect((await next.readLatest())?.status.schemaVersion).toBe(1); await expect(next.readFile('legacy', 'ocr.json')).rejects.toMatchObject({ code: 'NOT_FOUND' });
  const fresh = input('fresh'); await start(next, fresh); await next.saveArtifacts(fresh);
  expect(await Promise.all(names.map(n => readFile(join(p, 'runs/legacy', n))))).toEqual(before);
});
it.each(['dimensions', 'truncated'] as const)('rejects %s PNG at registration before claiming a registered input', async fault => {
  const store = new OutputStoreV2(await root()), v = imageInput(); await start(store, v);
  const a = await scratch(fault === 'truncated' ? png.subarray(0, 33) : png);
  if (fault === 'dimensions') a.input.width = 2;
  await expect(store.registerImageAssets(v.run.runId, a)).rejects.toThrow();
});
it.each(['evidence-write', 'archive-rename', 'extra-write'] as const)('preserves prior archive/latest on real filesystem %s failure', async fault => {
  const p = await root(), old = new OutputStoreV2(p), previous = input('previous'); await start(old, previous); await old.saveArtifacts(previous);
  const marker = await readFile(join(p, 'latest.json')), result = await readFile(join(p, 'runs/previous/result.json'));
  const store = new OutputStoreV2(p, { beforeOperation: async ({ operation, path }) => {
    if (fault === 'evidence-write' && operation === 'write' && path.includes('/evidence/')) await symlink('/etc/hosts', join(p, path));
    if (fault === 'archive-rename' && operation === 'rename' && path === 'runs/next') await writeFile(join(p, 'runs/next'), 'blocking-file');
    if (fault === 'extra-write' && operation === 'write' && path.endsWith('/result_extra.json')) await writeFile(join(p, path), 'blocking-file');
  } });
  const v = input('next'); v.snapshots = [{ snapshotId: 's1', topPageUrl: v.run.entryUrl, frameUrl: v.run.entryUrl, framePath: [], capturedAt: v.run.startedAt, html: '<html/>', elements: [] }];
  await start(store, v); await expect(store.saveArtifacts(v)).rejects.toMatchObject({ failureStatus: { run: { state: 'failed' }, resultSaved: false, extraResultSaved: false } });
  expect(await readFile(join(p, 'latest.json'))).toEqual(marker); expect(await readFile(join(p, 'runs/previous/result.json'))).toEqual(result);
});
it('preserves image confirmation plus a partial OCR asset in one owner with an actual terminal review', async () => {
  const store = new OutputStoreV2(await root()), v = imageInput(); await start(store, v); const refs = await store.registerImageAssets(v.run.runId, await scratch());
  const i1 = occurrence(v, refs), i2 = { ...occurrence(v, refs, 'i2'), sourceKind: 'css_background' as const, extractionStatus: 'partial' as const, text: '일부', reasonCode: 'OCR_UNREADABLE' as const };
  v.ocr.images = [i1, i2]; positive(v); v.run.state = 'partial'; v.run.counts.reviewCandidates = 1;
  v.review.candidates = [{ candidateId: 'c1', url: v.run.entryUrl, location: i1.location, evidenceText: i1.text!, techniques: [], reason: 'OCR_UNREADABLE', ai: positiveAi(i1.text!),
    evidence: { snapshotId: 's1', path: null, sha256: null }, sourceType: 'image_ocr', sourceIds: ['i1', 'i2'], sourceTextRanges: [{ imageId: 'i1', rawStart: 0, rawEnd: i1.text!.length }] }];
  const saved = await store.saveArtifacts(v); expect(saved.extraResult.findings).toHaveLength(1); expect(saved.review.candidates[0].reason).toBe('OCR_UNREADABLE');
  expect(saved.status.run.state).toBe('partial'); expect(saved.status.run.imageCounts.ocrCompleted).toBe(2);
});
it('refuses conflicting result IDs, missing details and forged asset metadata', async () => {
  const store = new OutputStoreV2(await root()), v = imageInput(); await start(store, v); const refs = await store.registerImageAssets(v.run.runId, await scratch());
  v.ocr.images = [occurrence(v, refs)]; positive(v);
  const missing = structuredClone(v); missing.details.details = []; await expect(store.saveArtifacts(missing)).rejects.toThrow();
  const duplicate = structuredClone(v); duplicate.findings = [{ id: 'extra1', url: v.run.entryUrl, is_violation: true, location: '#text', evidence_text: 'text', technique: 'JAMO' }]; await expect(store.saveArtifacts(duplicate)).rejects.toThrow();
  const forged = structuredClone(v); forged.ocr.images[0].input!.sha256 = '0'.repeat(64); await expect(store.saveArtifacts(forged)).rejects.toThrow();
  await expect(store.saveArtifacts(v)).resolves.toMatchObject({ extraResult: { findings: [{ id: 'extra1' }] } });
});
it('does not claim saved results when archive bytes fail verification after directory registration', async () => {
  const p = await root(); let stagedResult = '';
  const store = new OutputStoreV2(p, { beforeOperation: async ({ operation, path }) => {
    if (operation === 'write' && path.endsWith('/result.json')) stagedResult = path;
    if (operation === 'rename' && path === 'runs/images') await writeFile(join(p, stagedResult), '{}');
  } });
  const v = imageInput(); await start(store, v); const refs = await store.registerImageAssets(v.run.runId, await scratch()); v.ocr.images = [occurrence(v, refs)]; positive(v);
  await expect(store.saveArtifacts(v)).rejects.toMatchObject({ failureStatus: { run: { state: 'failed' }, resultSaved: false, extraResultSaved: false } });
});
it.each(['application/octet-stream', 'text/html'])('preserves acquired original MIME %s in quarantine, never serving it as input PNG', async mime => {
  const store = new OutputStoreV2(await root()), v = imageInput(); await start(store, v);
  const a = await scratch(); a.original.mime = mime; const refs = await store.registerImageAssets(v.run.runId, a);
  expect(refs.original.mime).toBe(mime); v.ocr.images = [occurrence(v, refs)]; positive(v);
  expect((await store.saveArtifacts(v)).ocr.images[0].original?.mime).toBe(mime);
  await expect(store.readImage(v.run.runId, refs.original.assetId)).rejects.toMatchObject({ code: 'NOT_FOUND' });
  expect(await store.readImage(v.run.runId, refs.input.assetId)).toEqual(png);
});
it('persists observed but unselected images with no capture/request/assets and both empty result files', async () => {
  const store = new OutputStoreV2(await root()), v = input(); v.snapshots = imageInput().snapshots;
  const i = occurrence(v, { original: null as never, input: null as never }); i.status = 'not_selected'; i.model = null; i.extractionStatus = null; i.text = null;
  i.capturedAt = null; i.attemptCount = 0; i.reasonCode = 'OCR_NOT_SELECTED'; v.ocr.images = [i]; v.run.imageCounts = countImages(v.ocr.images);
  await start(store, v); const saved = await store.saveArtifacts(v);
  expect(saved.status.imageScope.enabled).toBe(false); expect(saved.status.run.imageCounts).toEqual({ discovered: 1, captured: 0, ocrCompleted: 0, failed: 0, pending: 0, skipped: 1 });
  expect(saved.result.findings).toEqual([]); expect(saved.extraResult.findings).toEqual([]); expect(saved.ocr.images[0].input).toBeNull();
});
it('keeps direct DOM original and OCR extraction separate at the same owner with one detail for each result', async () => {
  const store = new OutputStoreV2(await root()), v = imageInput(); await start(store, v); const refs = await store.registerImageAssets(v.run.runId, await scratch());
  v.ocr.images = [occurrence(v, refs)]; positive(v); const text = '원문 대출 😀';
  v.findings = [{ id: 'dom1', url: v.run.entryUrl, is_violation: true, location: v.ocr.images[0].location, evidence_text: text, technique: 'JAMO' }];
  v.details.details.push({ findingId: 'dom1', candidateId: 'dom-c1', decisionSource: 'clef', ruleIds: [], ai: positiveAi(text), evidence: { snapshotId: 's1', path: null, sha256: null },
    resultFile: 'result.json', sourceType: 'dom_text', sourceIds: [], sourceTextRanges: [], observationIds: ['jamo-observation'] }); v.run.counts.confirmedFindings = 1;
  const saved = await store.saveArtifacts(v); expect(saved.result.findings[0].evidence_text).toBe(text); expect(saved.extraResult.findings[0].evidence_text).toBe('한글 😀');
  expect(saved.result.meta).toEqual(saved.extraResult.meta); expect(saved.details.details).toHaveLength(2);
  expect(new Set([...saved.result.findings, ...saved.extraResult.findings].map(f => f.id)).size).toBe(2);
});
it('previews only genuine registered active PNG inputs and preserves identical bytes after archival', async () => {
  const p = await root(), store = new OutputStoreV2(p), v = imageInput(); await start(store, v);
  await expect(store.readImage(v.run.runId, 'unregistered')).rejects.toMatchObject({ code: 'NOT_FOUND' });
  const a = await scratch(); a.original.mime = 'text/html';
  const originalBytes = Buffer.from('<html><script>throw new Error("original must never execute")</script></html>');
  const originalPath = join(await root(), 'original.html'); await writeFile(originalPath, originalBytes);
  a.original = { scratchPath: originalPath, sha256: sha(originalBytes), byteLength: originalBytes.length, mime: 'text/html' };
  const refs = await store.registerImageAssets(v.run.runId, a);
  await expect(store.readImage(v.run.runId, refs.original.assetId)).rejects.toMatchObject({ code: 'NOT_FOUND' });
  await expect(store.readImage(v.run.runId, '../input.png')).rejects.toThrow();
  await expect(store.readImage('another-run', refs.input.assetId)).rejects.toMatchObject({ code: 'NOT_FOUND' });
  await rm(a.input.scratchPath); await rm(originalPath);
  const activeBytes = await store.readImage(v.run.runId, refs.input.assetId); expect(activeBytes).toEqual(png);
  v.ocr.images = [occurrence(v, refs)]; positive(v); await store.saveArtifacts(v);
  expect(await store.readImage(v.run.runId, refs.input.assetId)).toEqual(activeBytes);
  expect(await new OutputStoreV2(p).readImage(v.run.runId, refs.input.assetId)).toEqual(activeBytes);
});
it.each(['tampered', 'symlink'] as const)('rejects %s registered active PNG instead of serving unverified scratch or original bytes', async fault => {
  const p = await root(), store = new OutputStoreV2(p), v = imageInput(); await start(store, v);
  const refs = await store.registerImageAssets(v.run.runId, await scratch());
  const { readdir } = await import('node:fs/promises');
  const staging = (await readdir(join(p, 'runs'))).find(name => name.startsWith('.staging-'))!;
  const inputPath = join(p, 'runs', staging, 'images', `${refs.input.assetId}.png`);
  if (fault === 'tampered') { const changed = Buffer.from(png); changed[40] ^= 1; await writeFile(inputPath, changed); }
  else { await rm(inputPath); await symlink('/etc/hosts', inputPath); }
  await expect(store.readImage(v.run.runId, refs.input.assetId)).rejects.toMatchObject({ name: 'OutputStorageErrorV2' });
});
it('keeps active PNG registration private when callers mutate returned references', async () => {
  const store = new OutputStoreV2(await root()), v = imageInput(); await start(store, v);
  const refs = await store.registerImageAssets(v.run.runId, await scratch()), assetId = refs.input.assetId;
  refs.input.assetId = 'forged'; refs.input.sha256 = '0'.repeat(64); refs.input.path = '/etc/hosts'; refs.input.width = 99;
  expect(await store.readImage(v.run.runId, assetId)).toEqual(png);
  await expect(store.readImage(v.run.runId, 'forged')).rejects.toMatchObject({ code: 'NOT_FOUND' });
});
it.each([false, true])('rechecks actual archive bytes after latest publication failure (late corruption: %s)', async corrupt => {
  const p = await root(), old = new OutputStoreV2(p), previous = input('previous'); await start(old, previous); await old.saveArtifacts(previous);
  const markerBefore = await readFile(join(p, 'latest.json'));
  const oldResultBefore = await readFile(join(p, 'runs/previous/result.json'));
  let failedManifestBefore: Buffer | null = null;
  const store = new OutputStoreV2(p, { beforeOperation: async ({ operation, path }) => {
    if (operation !== 'rename' || path !== 'latest.json') return;
    failedManifestBefore = await readFile(join(p, 'runs/failed-publication/manifest.json'));
    if (corrupt) await writeFile(join(p, 'runs/failed-publication/ocr.json'), '{}');
    throw new Error('Latest publication failed');
  } });
  const v = input('failed-publication'); await start(store, v);
  const failure = await store.saveArtifacts(v).catch(error => error);
  const expected = { run: { state: 'failed' }, resultSaved: !corrupt, extraResultSaved: !corrupt };
  expect(failure).toMatchObject({ name: 'OutputStorageErrorV2', failureStatus: expected });
  const persisted = JSON.parse(await readFile(join(p, 'run-failures/failed-publication.json'), 'utf8'));
  expect(persisted).toMatchObject(expected);
  if (corrupt) {
    expect(Object.values(failure.failureStatus.files)).toEqual(Array(8).fill(null));
    expect(Object.values(persisted.files)).toEqual(Array(8).fill(null));
    await expect(store.readFile(v.run.runId, 'result.json')).rejects.toThrow();
    await expect(new OutputStoreV2(p).readFile(v.run.runId, 'ocr.json')).rejects.toThrow();
    expect(await readFile(join(p, 'runs/failed-publication/ocr.json'), 'utf8')).toBe('{}');
  } else {
    expect(persisted.files.resultSha256).toBe(sha(await store.readFile(v.run.runId, 'result.json')));
    expect(JSON.parse((await new OutputStoreV2(p).readFile(v.run.runId, 'scan-status.json')).toString())).toMatchObject(expected);
  }
  expect(await readFile(join(p, 'runs/failed-publication/manifest.json'))).toEqual(failedManifestBefore);
  expect(await readFile(join(p, 'latest.json'))).toEqual(markerBefore);
  expect(await readFile(join(p, 'runs/previous/result.json'))).toEqual(oldResultBefore);
  expect((await new OutputStoreV2(p).readLatest())?.status.run.runId).toBe(previous.run.runId);
});
it.each(['manifest', 'rehashed-ocr'] as const)('does not bless %s replacement during failed latest publication', async fault => {
  const p = await root(), store = new OutputStoreV2(p, { beforeOperation: async ({ operation, path }) => {
    if (operation !== 'rename' || path !== 'latest.json') return;
    const manifestPath = join(p, 'runs/replaced/manifest.json');
    if (fault === 'manifest') await writeFile(manifestPath, '{}');
    else {
      const ocrPath = join(p, 'runs/replaced/ocr.json'), bytes = Buffer.from(JSON.stringify(JSON.parse(await readFile(ocrPath, 'utf8'))));
      await writeFile(ocrPath, bytes);
      const manifest = JSON.parse(await readFile(manifestPath, 'utf8')); manifest.files['ocr.json'] = sha(bytes);
      await writeFile(manifestPath, JSON.stringify(manifest));
    }
    throw new Error('Latest publication failed');
  } });
  const v = input('replaced'); await start(store, v);
  await expect(store.saveArtifacts(v)).rejects.toMatchObject({ failureStatus: { resultSaved: false, extraResultSaved: false } });
  const persisted = JSON.parse(await readFile(join(p, 'run-failures/replaced.json'), 'utf8'));
  expect(persisted.resultSaved).toBe(false); expect(persisted.extraResultSaved).toBe(false); expect(Object.values(persisted.files)).toEqual(Array(8).fill(null));
  if (fault === 'manifest') expect(await readFile(join(p, 'runs/replaced/manifest.json'), 'utf8')).toBe('{}');
  else {
    const manifest = JSON.parse(await readFile(join(p, 'runs/replaced/manifest.json'), 'utf8'));
    expect(manifest.files['ocr.json']).toBe(sha(await readFile(join(p, 'runs/replaced/ocr.json'))));
  }
  expect(await store.readLatest()).toBeNull();
});
