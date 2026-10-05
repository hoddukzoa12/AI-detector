import { afterEach, expect, it } from 'vitest';
import { createServer, type Server } from 'node:http';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { InspectorApplication } from '../../src/application/index.js';
import { startServer, type InspectorServer } from '../../src/server/index.js';
import { OutputStoreV2 } from '../../src/output/index.js';
import { validateScanStatusFileV2 } from '../../src/core/index.js';
import { imageCrawler, imagePage, imageUrl, ocrResponse, png } from './image-fixture.js';
import { mockAnalysisOptions, positiveClef } from './mock-transport.js';
const roots: string[] = []; const servers: Server[] = []; const localApis: InspectorServer[] = []; const applications: InspectorApplication[] = [];
afterEach(async () => {
  await Promise.all(localApis.splice(0).map(server => server.close()));
  await Promise.all(applications.splice(0).map(app => app.close()));
  await Promise.all(servers.splice(0).map(server => new Promise<void>(resolve => { server.close(() => resolve()); server.closeAllConnections(); })));
  await Promise.all(roots.splice(0).map(root => rm(root, { recursive: true, force: true })));
});
async function root() { const path = await mkdtemp(join(tmpdir(), 't7-cancel-')); roots.push(path); return path; }
async function fixture() {
  const requests: { method: string; url: string }[] = [];
  const server = createServer((request, response) => {
    requests.push({ method: request.method!, url: request.url! });
    if (request.url?.endsWith('.png')) { response.writeHead(200, { 'Content-Type': 'image/png' }); response.end(png(request.url === '/two.png' ? 2 : 1)); return; }
    response.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    response.end(request.url === '/policy' ? '<p id="policy" style="opacity:0">정책 뒤 원문</p><script>fetch("/write",{method:"POST",body:"synthetic"}).catch(()=>{});window.open("/popup");new WebSocket("ws://"+location.host+"/socket");</script>' :
      '<div id="owner" style="background-image:url(/one.png),url(/two.png);width:20px;height:20px"></div>');
  });
  servers.push(server); await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
  const address = server.address(); if (!address || typeof address === 'string') throw new Error('No listener');
  return { url: `http://127.0.0.1:${address.port}`, requests };
}
const request = { entryUrl: imageUrl, ocrEnabled: false, externalAnalysisConsent: true } as const;
const browserOptions = { dynamicWaitMs: 100, resourceWaitMs: 1000, scrollSteps: 0, maxPages: 1 };
async function status(app: InspectorApplication, runId: string) {
  const value = JSON.parse((await app.readFile(runId, 'scan-status.json')).toString());
  expect(value.run).toEqual(app.get(runId)); validateScanStatusFileV2(value, app.ocr(runId)); return value;
}
it.each(['ocr', 'clef'] as const)('real Chromium %s cancellation saves cancelled state and freezes exact file/API artifacts and late replies', async provider => {
  const site = await fixture(); const outputRoot = await root(); let cancel = true; let calls = 0;
  let resolveLate!: (response: Response) => void; const late = new Promise<Response>(resolve => { resolveLate = resolve; });
  const transport: typeof fetch = async (endpoint, init) => {
    calls++; expect(endpoint).toBe(provider === 'ocr' ? 'https://openrouter.ai/api/v1/chat/completions' : 'https://openrouter.ai/api/alpha/decisions');
    if (cancel && (provider === 'clef' || calls === 2)) { void app.cancel(app.activeRunId!); return late; }
    return provider === 'ocr' ? ocrResponse() : positiveClef(endpoint, init);
  };
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot, crawlOptions: browserOptions,
    ocrOptions: { fetch: provider === 'ocr' ? transport : async () => ocrResponse() }, aiOptions: { fetch: provider === 'clef' ? transport : positiveClef } }); applications.push(app);
  const run = app.start({ ...request, entryUrl: site.url, ocrEnabled: true }); const done = await app.wait(run.runId);
  expect(done.counts.scannedPages).toBe(1); expect(done.requestCounts).toEqual(provider === 'ocr' ? { ocr: 2, clef: 0 } : { ocr: 2, clef: 1 });
  expect(await status(app, run.runId)).toMatchObject({ resultSaved: true, extraResultSaved: true });
  const api = await startServer({ application: app, config: { mode: 'npm', apiKey: '', outputRoot, host: '127.0.0.1', port: 0 } }); localApis.push(api);
  const headers = { Authorization: `Bearer ${api.sessionToken}` }; const base = api.url + '/api/runs/' + run.runId;
  for (const [route, file] of [['ocr', 'ocr.json'], ['review', 'review.json'], ['finding-details', 'finding-details.json']] as const) {
    const response = await fetch(base + '/' + route, { headers }); const download = await fetch(base + '/files/' + file, { headers });
    expect(response.status).toBe(200); expect(download.status).toBe(200); expect(await response.json()).toEqual(await download.json());
  }
  for (const [route, file] of [['findings', 'result.json'], ['extra-findings', 'result_extra.json']] as const) {
    const result = await (await fetch(base + '/' + route, { headers })).json(); const download = await (await fetch(base + '/files/' + file, { headers })).json(); expect(result.findings).toEqual(download.findings);
  }
  const frozen = { run: app.get(run.runId), ocr: app.ocr(run.runId), review: app.review(run.runId), details: app.details(run.runId), bytes: await app.readFile(run.runId, 'ocr.json') };
  resolveLate(provider === 'ocr' ? ocrResponse() : await positiveClef('https://openrouter.ai/api/alpha/decisions'));
  await new Promise<void>(resolve => setImmediate(resolve)); expect(await app.cancel(run.runId)).toEqual(frozen.run);
  expect(app.ocr(run.runId)).toEqual(frozen.ocr); expect(app.review(run.runId)).toEqual(frozen.review); expect(app.details(run.runId)).toEqual(frozen.details); expect(await app.readFile(run.runId, 'ocr.json')).toEqual(frozen.bytes);
  cancel = false; const next = app.start({ ...request, entryUrl: site.url, ocrEnabled: true }); expect((await app.wait(next.runId)).state).toBe('completed');
  expect(app.get(run.runId)).toEqual(frozen.run); expect(app.ocr(run.runId)).toEqual(frozen.ocr); expect(done.state).toBe('cancelled');
});
it('real blocked POST, popup and WebSocket diagnostics preserve scanned confirmations as partial', async () => {
  const site = await fixture(); const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), crawlOptions: browserOptions }); applications.push(app);
  const run = app.start({ ...request, entryUrl: site.url + '/policy' }); const done = await app.wait(run.runId);
  expect(done.counts).toMatchObject({ scannedPages: 1, confirmedFindings: 1 }); expect(done.errors.some(error => error.code === 'RUNTIME_ERROR')).toBe(true);
  expect(site.requests.every(request => ['GET', 'HEAD'].includes(request.method))).toBe(true); expect(site.requests.some(request => request.url === '/socket')).toBe(false);
  expect(done.state).toBe('partial'); expect(await status(app, run.runId)).toMatchObject({ resultSaved: true, extraResultSaved: true });
});
it.each([false, true])('uses the producer fatal flag=%s independently of identical public runtime error code/message', async fatalError => {
  for (const cancelled of [false, true]) {
    const base = imageCrawler(imagePage([], true), []);
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), crawl: async (entry, options = {}) => {
      const result = await base(entry, options); if (cancelled) await app.cancel(app.activeRunId!);
      return Object.assign(result, { fatalError, errors: [{ scope: 'runtime' as const, code: 'RUNTIME_ERROR' as const, url: null, candidateId: null, message: 'Same public runtime diagnostic' }] });
    } }); applications.push(app);
    const run = app.start(request); const done = await app.wait(run.runId); expect(done.counts.confirmedFindings).toBe(1);
    expect(done.state).toBe(fatalError ? 'failed' : cancelled ? 'cancelled' : 'partial'); expect(await status(app, run.runId)).toMatchObject({ resultSaved: true, extraResultSaved: true });
  }
});
it('a genuine application/crawl rejection stays failed even after user cancellation and preserves accepted confirmation', async () => {
  const base = imageCrawler(imagePage([], true), []);
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), crawl: async (entry, options = {}) => {
    const result = await base(entry, options); await options.onProgress?.({ counts: result.counts, errors: [], activeUrls: [] }); await app.cancel(app.activeRunId!); throw new Error('Synthetic fatal adapter crash');
  } }); applications.push(app);
  const run = app.start(request); const done = await app.wait(run.runId); expect(done.state).toBe('failed'); expect(done.counts).toMatchObject({ scannedPages: 1, confirmedFindings: 1 });
  expect(done.errors).toContainEqual(expect.objectContaining({ scope: 'runtime', code: 'RUNTIME_ERROR' })); expect(await status(app, run.runId)).toMatchObject({ resultSaved: true, extraResultSaved: true });
});
it('storage failure remains failed after user cancellation and never claims saved results', async () => {
  const store = new OutputStoreV2(await root(), { beforeOperation: operation => { if (operation.operation === 'write' && operation.path.endsWith('/finding-details.json')) throw new Error('Synthetic storage failure'); } });
  const base = imageCrawler(imagePage([], true), []);
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputStore: store, crawl: async (entry, options = {}) => { const result = await base(entry, options); await app.cancel(app.activeRunId!); return result; } }); applications.push(app);
  const run = app.start(request); const done = await app.wait(run.runId); expect(done.state).toBe('failed'); expect(done.counts).toMatchObject({ scannedPages: 1, confirmedFindings: 1 });
  expect(done.errors).toContainEqual(expect.objectContaining({ code: 'STORAGE_ERROR' })); expect(await status(app, run.runId)).toMatchObject({ resultSaved: false, extraResultSaved: false });
});
