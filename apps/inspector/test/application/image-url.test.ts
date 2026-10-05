import { afterEach, expect, it, vi } from 'vitest';
import { createHash } from 'node:crypto';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { InspectorApplication } from '../../src/application/index.js';
import type { ImageAcquisitionResult, ImageCollectionOptions } from '../../src/crawler/index.js';
import { assets, imageCrawler, imagePage, imageUrl, ocrResponse, owner } from './image-fixture.js';
import { mockAnalysisOptions } from './mock-transport.js';

const roots: string[] = [];
afterEach(async () => { await Promise.all(roots.splice(0).map(path => rm(path, { recursive: true, force: true }))); });
async function root() { const path = await mkdtemp(join(tmpdir(), 'image-url-app-')); roots.push(path); return path; }
const request = { entryUrl: imageUrl, ocrEnabled: true, externalAnalysisConsent: true } as const;
const finalUrl = 'https://cdn.example.test/redirected/banner.png?version=2';

it.each(['captured', 'decode_error'] as const)('persists the acquired final URL for %s without changing occurrence or DOM evidence', async outcome => {
  const path = await root(); const captured = await assets(path, 'redirected', 2);
  const metadata = owner(captured.imageId); const page = imagePage([metadata]);
  page.frames[0].html = `<img id="banner" src="${metadata.selectedUrl}">`;
  const originalHtml = page.frames[0].html;
  let acquisition: ImageAcquisitionResult = { status: 'captured', assets: captured };
  if (outcome === 'decode_error') {
    const bytes = Buffer.from('malformed image fixture'); const scratchPath = join(path, 'malformed.png');
    await writeFile(scratchPath, bytes);
    acquisition = { status: 'error', reasonCode: 'IMAGE_DECODE_ERROR', message: 'Mock decoder rejected fetched bytes', capturedAt: captured.capturedAt,
      original: { scratchPath, sha256: createHash('sha256').update(bytes).digest('hex'), mime: 'image/png', byteLength: bytes.length } };
  }
  const original = acquisition.status === 'captured' ? acquisition.assets.original : acquisition.original!;
  const originalBytes = await readFile(original.scratchPath); const ocr = vi.fn(async () => ocrResponse());
  let callback!: ImageCollectionOptions['onImage'];
  const crawl = imageCrawler(page, [acquisition], () => { page.images![0].imageUrl = finalUrl; });
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: join(path, 'output'), ocrOptions: { fetch: ocr },
    crawl: (entry, options = {}) => { callback = options.images!.onImage; return crawl(entry, options); } });
  const started = app.start(request); const done = await app.wait(started.runId);
  expect(done.state).toBe(outcome === 'captured' ? 'completed' : 'partial');
  expect(done.requestCounts).toEqual(outcome === 'captured' ? { ocr: 1, clef: 1 } : { ocr: 0, clef: 0 });
  expect(done.counts.extraConfirmedFindings).toBe(outcome === 'captured' ? 1 : 0);
  const dto = app.ocr(started.runId); const record = dto.images[0];
  expect(record).toMatchObject({ imageId: metadata.imageId, url: metadata.url, frameUrl: metadata.frameUrl, framePath: metadata.framePath,
    snapshotId: metadata.snapshotId, location: metadata.location, sourceKind: metadata.sourceKind, sourceIndex: metadata.sourceIndex,
    concealment: metadata.concealment, styles: metadata.styles, imageUrl: finalUrl, capturedAt: captured.capturedAt,
    status: outcome === 'captured' ? 'completed' : 'error', reasonCode: outcome === 'captured' ? null : 'IMAGE_DECODE_ERROR' });
  expect(record.original).toMatchObject({ sha256: createHash('sha256').update(originalBytes).digest('hex'), mime: original.mime, byteLength: originalBytes.length });
  expect(await readFile(join(path, 'output', record.original!.path!))).toEqual(originalBytes);
  if (outcome === 'captured') {
    expect(record.input).toMatchObject({ sha256: captured.input.sha256, mime: 'image/png', width: 2, height: 1, frameIndex: 0 });
    expect(record.input!.assetId).not.toBe(record.original!.assetId); expect(record.input!.path).not.toBe(record.original!.path);
    const inputBytes = await app.readImage(started.runId, record.input!.assetId);
    expect(createHash('sha256').update(inputBytes).digest('hex')).toBe(record.input!.sha256); expect(ocr).toHaveBeenCalledOnce();
    expect(app.details(started.runId).details[0].sourceIds).toEqual([metadata.imageId]);
    expect(app.extraFindings(started.runId).findings[0].location).toBe(metadata.location);
  } else {
    expect(record.input).toBeNull(); expect(ocr).not.toHaveBeenCalled();
    expect(app.review(started.runId).candidates[0]).toMatchObject({ reason: 'OCR_ERROR', sourceIds: [metadata.imageId] });
  }
  const saved = await app.readFile(started.runId, 'ocr.json'); expect(JSON.parse(saved.toString())).toEqual(dto);
  expect(JSON.parse((await app.readEvidence(started.runId, metadata.snapshotId)).toString()).html).toBe(originalHtml);
  await callback({ ...page.images![0], imageUrl: 'https://cdn.example.test/late.png' }, acquisition);
  expect(app.ocr(started.runId)).toEqual(dto); expect(await app.readFile(started.runId, 'ocr.json')).toEqual(saved);
});

it.each(['data:image/png,fixture-only', 'blob:https://public.example.test/fixture-only'])('keeps local asset metadata null after acquisition for %s', async selectedUrl => {
  const path = await root(); const captured = await assets(path, 'local'); const metadata = { ...owner(captured.imageId), selectedUrl, imageUrl: null };
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: join(path, 'output'), ocrOptions: { fetch: async () => ocrResponse() },
    crawl: imageCrawler(imagePage([metadata]), [{ status: 'captured', assets: captured }]) });
  const started = app.start(request); expect((await app.wait(started.runId)).state).toBe('completed');
  const dto = app.ocr(started.runId); expect(dto.images[0]).toMatchObject({ imageUrl: null, imageId: metadata.imageId, status: 'completed' });
  expect(JSON.parse((await app.readFile(started.runId, 'ocr.json')).toString())).toEqual(dto);
  expect(JSON.stringify(dto)).not.toContain(selectedUrl); expect(dto.images[0]).not.toHaveProperty('selectedUrl');
});

it('keeps the observed URL and absent assets when acquisition fails before an original is available', async () => {
  const path = await root(); const metadata = owner('unavailable'); const ocr = vi.fn(async () => ocrResponse());
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: join(path, 'output'), ocrOptions: { fetch: ocr },
    crawl: imageCrawler(imagePage([metadata]), [{ status: 'error', reasonCode: 'IMAGE_FETCH_ERROR', message: 'Mock asset unavailable' }]) });
  const started = app.start(request); const done = await app.wait(started.runId); expect(done.state).toBe('partial');
  expect(done.requestCounts).toEqual({ ocr: 0, clef: 0 }); expect(ocr).not.toHaveBeenCalled();
  const dto = app.ocr(started.runId);
  expect(dto.images[0]).toMatchObject({ imageUrl: metadata.imageUrl, original: null, input: null, capturedAt: null, status: 'error', reasonCode: 'IMAGE_FETCH_ERROR' });
  expect(JSON.parse((await app.readFile(started.runId, 'ocr.json')).toString())).toEqual(dto);
});
