import { afterEach, expect, it } from 'vitest';
import { createServer, type Server } from 'node:http';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { InspectorApplication } from '../../src/application/index.js';
import { validateReviewFileV2, validateScanStatusFileV2 } from '../../src/core/index.js';
import { OutputStoreV2 } from '../../src/output/index.js';
import { assets, imageCrawler, imagePage, imageUrl, ocrResponse, owner, png } from './image-fixture.js';
import { mockAnalysisOptions } from './mock-transport.js';
const roots: string[] = []; const servers: Server[] = []; const applications: InspectorApplication[] = [];
afterEach(async () => {
  await Promise.all(applications.splice(0).map(app => app.close()));
  await Promise.all(servers.splice(0).map(server => new Promise<void>(resolve => { server.close(() => resolve()); server.closeAllConnections(); })));
  await Promise.all(roots.splice(0).map(root => rm(root, { recursive: true, force: true })));
});
async function root() { const path = await mkdtemp(join(tmpdir(), 't7-review-')); roots.push(path); return path; }
async function fixture() {
  const server = createServer((request, response) => {
    if (request.url?.endsWith('.png')) {
      response.writeHead(200, { 'Content-Type': 'image/png' });
      response.end(request.url === '/bad.png' ? 'malformed supported PNG' : png(request.url === '/two.png' ? 2 : 1)); return;
    }
    response.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    response.end(request.url === '/nested' ? '<iframe id="frame" src="/frame"></iframe>' : request.url === '/frame' ? '<img id="inside" src="/one.png">' :
      '<div id="owner" style="background-image:url(/bad.png),url(/one.png),url(/two.png);width:20px;height:20px"></div>');
  });
  servers.push(server); await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
  const address = server.address(); if (!address || typeof address === 'string') throw new Error('No listener');
  return `http://127.0.0.1:${address.port}`;
}
const request = { entryUrl: imageUrl, ocrEnabled: true, externalAnalysisConsent: true } as const;
const browserOptions = { dynamicWaitMs: 0, resourceWaitMs: 1000, scrollSteps: 0, maxPages: 1 };
async function assertSaved(app: InspectorApplication, runId: string, state: string) {
  const status = JSON.parse((await app.readFile(runId, 'scan-status.json')).toString());
  expect(status).toMatchObject({ run: { state }, resultSaved: true, extraResultSaved: true });
  expect(status.run).toEqual(app.get(runId)); validateScanStatusFileV2(status, app.ocr(runId));
  validateReviewFileV2(app.review(runId), app.ocr(runId), true);
}
it('preserves decode-error review precedence when the real image collector reaches the global OCR cap', async () => {
  const entryUrl = await fixture(); const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), limits: { maxOcrRequests: 1 },
    crawlOptions: browserOptions, ocrOptions: { fetch: async () => ocrResponse() } }); applications.push(app);
  const run = app.start({ ...request, entryUrl }); const done = await app.wait(run.runId);
  expect(done.requestCounts).toEqual({ ocr: 1, clef: 0 });
  expect(app.ocr(run.runId).images.map(image => image.status)).toEqual(['error', 'completed', 'not_started']);
  const review = app.review(run.runId).candidates[0]; expect(review.reason).toBe('OCR_ERROR'); expect(review.evidenceText).toBe('읽힌 글자');
  expect(review.sourceIds).toHaveLength(3); expect(review.sourceTextRanges).toEqual([{ imageId: app.ocr(run.runId).images[1].imageId, rawStart: 0, rawEnd: '읽힌 글자'.length }]);
  expect(review.ai!.chunks).toEqual([expect.objectContaining({ status: 'not_started', reasonCode: 'RESOURCE_LIMIT' })]);
  expect(done.state).toBe('partial'); await assertSaved(app, run.runId, 'partial');
});
it('keeps OCR failure precedence when the candidate scheduling limit prevents CLEF', async () => {
  const path = await root(); const captured = await assets(path, 'readable'); const images = [owner('bad', '#banner', 'css_background', 0), owner('readable', '#banner', 'css_background', 1)];
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: join(path, 'output'), maxAiCandidates: 1,
    crawl: imageCrawler(imagePage(images, true), [{ status: 'error', reasonCode: 'IMAGE_DECODE_ERROR', message: 'fixture decode failure' }, { status: 'captured', assets: captured }]),
    ocrOptions: { fetch: async () => ocrResponse() } }); applications.push(app);
  const run = app.start(request); const done = await app.wait(run.runId); const review = app.review(run.runId).candidates[0];
  expect(done.requestCounts).toEqual({ ocr: 1, clef: 1 }); expect(done.counts.confirmedFindings).toBe(1); expect(review.reason).toBe('OCR_ERROR');
  expect(review.ai!.chunks[0]).toMatchObject({ status: 'not_started', reasonCode: 'RESOURCE_LIMIT' }); expect(done.state).toBe('partial'); await assertSaved(app, run.runId, 'partial');
});
it('keeps OCR failure precedence when cancellation releases an image candidate waiting for a CLEF slot', async () => {
  const path = await root(); const first = await assets(path, 'first'); const second = await assets(path, 'second', 2);
  const images = [owner('first', '#first'), owner('bad', '#second', 'css_background', 0), owner('second', '#second', 'css_background', 1)];
  let entered!: () => void; const activeRequest = new Promise<void>(resolve => { entered = resolve; });
  const base = imageCrawler(imagePage(images), []);
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: join(path, 'output'), aiConcurrency: 1, ocrOptions: { fetch: async () => ocrResponse() },
    aiOptions: { fetch: async () => { entered(); return new Promise<Response>(() => {}); } },
    crawl: async (entry, options = {}) => base(entry, { ...options, images: { ...options.images!, onImage: async image => {
      if (image.imageId !== 'first') return;
      const firstWork = options.images!.onImage(images[0], { status: 'captured', assets: first }); await activeRequest;
      await options.images!.onImage(images[1], { status: 'error', reasonCode: 'IMAGE_DECODE_ERROR', message: 'fixture decode failure' });
      const secondWork = options.images!.onImage(images[2], { status: 'captured', assets: second });
      for (let attempt = 0; attempt < 100 && !app.review(app.activeRunId!).candidates.some(candidate => candidate.location === '#second'); attempt++) await new Promise<void>(resolve => setTimeout(resolve, 5));
      expect(app.review(app.activeRunId!).candidates.some(candidate => candidate.location === '#second')).toBe(true);
      await app.cancel(app.activeRunId!); await Promise.all([firstWork, secondWork]);
    } } }) }); applications.push(app);
  const run = app.start(request); const done = await app.wait(run.runId);
  const review = app.review(run.runId).candidates.find(candidate => candidate.location === '#second')!;
  expect(done.requestCounts).toEqual({ ocr: 2, clef: 1 }); expect(review.reason).toBe('OCR_ERROR');
  expect(review.ai!.chunks[0]).toMatchObject({ status: 'not_started', reasonCode: 'USER_CANCELLED' }); expect(done.state).toBe('cancelled'); await assertSaved(app, run.runId, 'cancelled');
});
it('restores all public artifact DTOs from a verified nested-frame archive when latest publication fails', async () => {
  const entryUrl = (await fixture()) + '/nested'; const path = await root(); let fail = false;
  const store = new OutputStoreV2(path, { beforeOperation: operation => { if (fail && operation.operation === 'rename' && operation.path === 'latest.json') throw new Error('fixture publication failure'); } });
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputStore: store, crawlOptions: browserOptions, ocrOptions: { fetch: async () => ocrResponse() } }); applications.push(app);
  const first = app.start({ ...request, entryUrl }); expect((await app.wait(first.runId)).state).toBe('completed'); const latest = await readFile(join(path, 'latest.json')); fail = true;
  const second = app.start({ ...request, entryUrl }); const done = await app.wait(second.runId); expect(done.state).toBe('failed');
  await assertSaved(app, second.runId, 'failed'); expect(await readFile(join(path, 'latest.json'))).toEqual(latest);
  const archived = async (file: Parameters<InspectorApplication['readFile']>[1]) => JSON.parse((await app.readFile(second.runId, file)).toString());
  expect(app.ocr(second.runId)).toEqual(await archived('ocr.json'));
  expect(app.review(second.runId)).toEqual(await archived('review.json')); expect(app.details(second.runId)).toEqual(await archived('finding-details.json'));
  expect(app.findings(second.runId).findings).toEqual((await archived('result.json')).findings); expect(app.extraFindings(second.runId).findings).toEqual((await archived('result_extra.json')).findings);
});
it('does not claim saved results when a publication failure leaves an archive that cannot be reverified', async () => {
  const path = await root(); const captured = await assets(path, 'source'); let fail = false; let currentId = '';
  const store = new OutputStoreV2(join(path, 'output'), { beforeOperation: async operation => {
    if (fail && operation.operation === 'rename' && operation.path === 'latest.json') {
      await writeFile(join(path, 'output', 'runs', currentId, 'ocr.json'), '{}'); throw new Error('fixture publication and archive corruption');
    }
  } });
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputStore: store, crawl: imageCrawler(imagePage([owner('source')]), [{ status: 'captured', assets: captured }]), ocrOptions: { fetch: async () => ocrResponse() } }); applications.push(app);
  const first = app.start(request); currentId = first.runId; expect((await app.wait(first.runId)).state).toBe('completed'); const latest = await readFile(join(path, 'output', 'latest.json')); fail = true;
  const second = app.start(request); currentId = second.runId; const done = await app.wait(second.runId); expect(done.state).toBe('failed');
  const status = JSON.parse((await app.readFile(second.runId, 'scan-status.json')).toString());
  expect(status).toMatchObject({ resultSaved: false, extraResultSaved: false, files: { resultPath: null, extraResultPath: null, resultSha256: null, extraResultSha256: null, ocrPath: null } });
  expect(status.run).toEqual(done); validateScanStatusFileV2(status, app.ocr(second.runId)); expect(await readFile(join(path, 'output', 'latest.json'))).toEqual(latest);
  await expect(app.readFile(second.runId, 'ocr.json')).rejects.toThrow(); expect(await app.readFile(first.runId, 'result_extra.json')).toBeInstanceOf(Buffer);
});
