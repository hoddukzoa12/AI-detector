import { mockAnalysisOptions } from './mock-transport.js';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { mkdtemp, rm, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { InspectorApplication } from '../../src/application/index.js';
import { createAiAnalysis, emptyRunCounts, type AiChoice, type CollectedPage, type RunCounts } from '../../src/core/index.js';
import { OutputStoreV2 } from '../../src/output/index.js';
import type { CrawlOptions, CrawlResult } from '../../src/crawler/index.js';
const roots: string[] = [];
afterEach(async () => { await Promise.all(roots.splice(0).map(root => rm(root, { recursive: true, force: true }))); });
async function root() { const path = await mkdtemp(join(tmpdir(), 'lifecycle-')); roots.push(path); return path; }
const url = 'https://public.example.test/article?id=2';
function page(text = '온라인 카지노 가입 배팅 보너스', multiple = false): CollectedPage {
  const bounds = { x: 0, y: 0, width: 80, height: 20 }; const capturedAt = new Date().toISOString();
  const element = (id: string) => ({ location: id, rawText: text, links: [], styles: [{ elementLocation: id, css: { opacity: '0', color: 'black', 'font-size': '16px' }, bounds }],
    tagName: 'p', attributes: {}, contextText: text, accessibility: { role: null, ariaHidden: null, ariaLabel: null }, bounds, documentBounds: bounds });
  return { url, capturedAt, discoveredUrls: [], frames: [{ frameUrl: url, framePath: [], snapshotId: 'raw_snapshot', capturedAt, html: '<p id="ad" style="opacity:0">Captured raw HTML</p>',
    elements: [element('#ad'), ...(multiple ? [element('#second')] : [])], viewport: { width: 800, height: 600, scrollX: 0, scrollY: 0 }, documentSize: { width: 800, height: 600 } }] };
}
const counts: RunCounts = { ...emptyRunCounts(), discoveredPages: 1, scannedPages: 1 };
function result(p: CollectedPage, options: CrawlOptions): CrawlResult {
  const stopped = options.signal?.aborted;
  return { pages: [p], state: stopped ? 'cancelled' : 'completed', counts, errors: [], scope: { hostname: new URL(url).hostname, framePolicy: 'embedded', skipped: [], unvisitedUrls: [] } };
}
const crawlPage = (p = page()) => async (_url: string, options: CrawlOptions = {}) => {
  await options.onPage?.(p); await options.onProgress?.({ counts, activeUrls: [], errors: [] }); return result(p, options);
};
function analysis(choice: AiChoice = 'illegal_ad', unfinished = false) {
  return createAiAnalysis([{ chunkId: 'chunk-0', rawStart: 0, rawEnd: 10, status: 'completed', choice, confidence: .9,
    probabilities: { illegal_ad: choice === 'illegal_ad' ? .9 : 1/30, non_ad: choice === 'non_ad' ? .9 : 1/30, general_ad: choice === 'general_ad' ? .9 : 1/30, uncertain: choice === 'uncertain' ? .9 : 1/30 }, reasonCode: null },
    ...(unfinished ? [{ chunkId: 'chunk-1', rawStart: 10, rawEnd: page().frames[0].elements[0].rawText.length, status: 'not_started' as const, choice: null, confidence: null, probabilities: null, reasonCode: 'RESOURCE_LIMIT' as const }] : [])]);
}
function deferred<T>() { let resolve!: (value: T) => void; const promise = new Promise<T>(res => { resolve = res; }); return { promise, resolve }; }
async function tick() { await new Promise<void>(resolve => setImmediate(resolve)); }
describe('AI and finalization lifecycle', () => {
  it.each(['non_ad', 'general_ad', 'uncertain'] as const)('AI %s replaces local confirmed without local fallback', async choice => {
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: 'unit-test-credential', crawl: crawlPage(), analyzeCandidate: async () => analysis(choice) });
    const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); const terminal = await app.wait(run.runId);
    expect(terminal.state).toBe('completed'); expect(app.findings(run.runId).findings).toHaveLength(0);
    expect(app.review(run.runId).candidates).toHaveLength(choice === 'uncertain' ? 1 : 0);
  });
  it('AI analyzes even locally excluded DOM candidates', async () => {
    const analyze = vi.fn<NonNullable<import('../../src/application/index.js').ApplicationOptions['analyzeCandidate']>>(async () => analysis());
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: 'unit-test-credential', crawl: crawlPage(page('메뉴 바로가기: 키보드 이용자')), analyzeCandidate: analyze });
    const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); await app.wait(run.runId);
    expect(analyze).toHaveBeenCalledTimes(1); expect(app.findings(run.runId).findings).toHaveLength(1);
    expect(app.details(run.runId).details[0].ruleIds).toEqual([]);
    expect(analyze.mock.calls[0][3]).toEqual(expect.objectContaining({ normalize: expect.any(Function) }));
  });
  it('preserves positive plus unfinished review and makes the run partial', async () => {
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: 'unit-test-credential', crawl: crawlPage(), analyzeCandidate: async () => analysis('illegal_ad', true) });
    const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); const terminal = await app.wait(run.runId);
    expect(terminal.state).toBe('partial'); expect(terminal.counts.confirmedFindings).toBe(1); expect(terminal.counts.reviewCandidates).toBe(1);
    expect(app.review(run.runId).candidates[0].ai?.chunks).toHaveLength(2);
  });
  it('AI failure is review/partial, sanitizes the key, and never locally confirms', async () => {
    const secret = 'unit-test-private-value';
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: secret, crawl: crawlPage(), analyzeCandidate: async () => { throw new Error(`transport ${secret}`); } });
    const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); const terminal = await app.wait(run.runId);
    expect(terminal.state).toBe('partial'); expect(terminal.counts.confirmedFindings).toBe(0); expect(app.review(run.runId).candidates[0].reason).toBe('AI_ERROR');
    expect(JSON.stringify(terminal)).not.toContain(secret);
  });
  it('OCR off still uses mandatory CLEF while image acquisition stays disabled', async () => {
    const analyze = vi.fn(async () => analysis());
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), crawl: crawlPage(), analyzeCandidate: analyze });
    const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); expect((await app.wait(run.runId)).state).toBe('completed');
    expect(analyze).toHaveBeenCalled(); expect(app.ocr(run.runId).enabled).toBe(false);
  });
  it('cancellation freezes confirmation but retains actual chunks and pending raw candidates', async () => {
    const entered = deferred<void>(); const gate = deferred<ReturnType<typeof analysis>>();
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: 'unit-test-credential', crawl: crawlPage(page(undefined, true)), analyzeCandidate: async (_candidate, _key, signal, options) => {
      options!.onProgress!(createAiAnalysis(analysis('illegal_ad', true).chunks.map((chunk, index) => ({ ...chunk, status: index === 0 ? 'running' : 'pending', choice: null, probabilities: null, confidence: null, reasonCode: null }))));
      entered.resolve(); signal.addEventListener('abort', () => gate.resolve(analysis('illegal_ad', true)), { once: true }); return gate.promise;
    } });
    const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); await entered.promise;
    expect(app.review(run.runId).candidates).toHaveLength(2); expect((await app.cancel(run.runId)).state).toBe('stopping');
    const terminal = await app.wait(run.runId); expect(terminal.state).toBe('cancelled'); expect(terminal.counts.confirmedFindings).toBe(0);
    expect(terminal.counts.reviewCandidates).toBe(2); expect(app.review(run.runId).candidates[0].ai?.chunks).toHaveLength(2);
    expect(app.review(run.runId).candidates[1].ai?.chunks[0].reasonCode).toBe('USER_CANCELLED');
    expect(await app.cancel(run.runId)).toEqual(terminal);
  });
  it('completion reservation keeps active until save and cancel returns stable terminal', async () => {
    const entered = deferred<void>(); const gate = deferred<void>();
    const outputRoot = await root(); const store = new OutputStoreV2(outputRoot, { beforeOperation: async operation => {
      if (operation.operation === 'write' && operation.path.includes('.staging-')) { entered.resolve(); await gate.promise; }
    } });
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputStore: store, crawl: crawlPage() });
    const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); await entered.promise;
    expect(app.get(run.runId).state).toBe('running'); expect(() => app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true })).toThrow('ACTIVE_RUN');
    let cancelReturned = false; const cancelled = app.cancel(run.runId).then(value => { cancelReturned = true; return value; }); await tick(); expect(cancelReturned).toBe(false);
    gate.resolve(); const terminal = await app.wait(run.runId); expect(terminal.state).toBe('completed'); expect(await cancelled).toEqual(terminal);
    expect(JSON.parse((await app.readFile(run.runId, 'scan-status.json')).toString()).run).toEqual(terminal);
  });
  it('user cancellation before completion reservation wins and no terminal state changes', async () => {
    const entered = deferred<void>(); const gate = deferred<void>();
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), crawl: async (_url, options = {}) => {
      await options.onPage?.(page()); entered.resolve(); await gate.promise; return result(page(), options);
    } });
    const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); await entered.promise; await app.cancel(run.runId); gate.resolve();
    const terminal = await app.wait(run.runId); expect(terminal.state).toBe('cancelled'); expect(terminal.counts.confirmedFindings).toBe(1);
    expect(await app.cancel(run.runId)).toEqual(terminal);
  });
  it('late old callbacks cannot affect a later execution and public data are clones', async () => {
    let old: CrawlOptions | undefined;
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), crawl: async (_url, options = {}) => { old ??= options; await options.onPage?.(page()); return result(page(), options); } });
    const first = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); await app.wait(first.runId);
    const second = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); await app.wait(second.runId);
    await old!.onPage?.(page('다른 카지노 가입 보너스')); await old!.onProgress?.({ counts: { ...counts, scannedPages: 999 }, errors: [], activeUrls: ['https://foreign.invalid'] });
    const findings = app.findings(second.runId); findings.findings[0].evidence_text = 'changed';
    expect(app.get(second.runId).counts.scannedPages).toBe(1); expect(app.findings(second.runId).findings[0].evidence_text).not.toBe('changed');
    expect(app.findings(first.runId).findings).toHaveLength(1);
  });
  it('bounds AI candidate work and retains unanalyzed originals', async () => {
    const analyze = vi.fn(async () => analysis());
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: 'unit-test-credential', maxAiCandidates: 1, crawl: crawlPage(page(undefined, true)), analyzeCandidate: analyze });
    const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); expect((await app.wait(run.runId)).state).toBe('partial');
    expect(analyze).toHaveBeenCalledTimes(1); expect(app.review(run.runId).candidates[0].ai?.chunks[0].reasonCode).toBe('RESOURCE_LIMIT');
  });
  it('time limit abort reason reaches crawler and becomes partial', async () => {
    let reason: unknown;
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), maxDurationMs: 15, crawl: async (_url, options = {}) => {
      await options.onPage?.(page()); await new Promise<void>(resolve => { if(options.signal!.aborted) { reason = options.signal!.reason; resolve(); } else options.signal!.addEventListener('abort', () => { reason = options.signal!.reason; resolve(); }, { once: true }); }); return result(page(), options);
    } });
    const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); const terminal = await app.wait(run.runId); expect(reason).toBe('TIME_LIMIT'); expect(terminal.state).toBe('partial');
    expect(terminal.errors).toContainEqual(expect.objectContaining({ scope: 'limit', code: 'TIME_LIMIT' }));
  });
  it('zero scanned and unexpected runtime errors are failed; policy exclusion remains distinct', async () => {
    const outputRoot = await root();
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot, crawl: async () => { throw new Error('collection crash'); } });
    const first = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); const terminal = await app.wait(first.runId);
    expect(terminal.state).toBe('failed'); expect(terminal.errors[0]).toEqual(expect.objectContaining({ scope: 'runtime', code: 'RUNTIME_ERROR' }));
    const policy = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), crawl: async () => ({ ...result(page(), {}), counts: { ...counts, skippedPages: 1 }, errors: [{ scope: 'page', code: 'LOGIN_REQUIRED', url, candidateId: null, message: 'Login excluded' }] }) });
    const second = policy.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); expect((await policy.wait(second.runId)).state).toBe('completed');
  });
  it('storage publication failure remains failed with preserved archive and exact count/status', async () => {
    const outputRoot = await root();
    const store = new OutputStoreV2(outputRoot, { beforeOperation: operation => { if (operation.operation === 'rename' && operation.path === 'latest.json') throw new Error('publication failure'); } });
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputStore: store, crawl: crawlPage() }); const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true });
    const terminal = await app.wait(run.runId); expect(terminal.state).toBe('failed'); expect(terminal.counts.confirmedFindings).toBe(1); expect(terminal.errors.at(-1)?.code).toBe('STORAGE_ERROR');
    const status = JSON.parse((await app.readFile(run.runId, 'scan-status.json')).toString()); expect(status.run).toEqual(terminal); expect(status.resultSaved).toBe(true);
    expect(JSON.parse(await readFile(join(outputRoot, 'runs', run.runId, 'scan-status.json'), 'utf8')).run.state).toBe('completed');
    expect(JSON.parse(await readFile(join(outputRoot, 'run-failures', run.runId + '.json'), 'utf8')).run.state).toBe('failed');
    expect(await app.cancel(run.runId)).toEqual(terminal);
  });
  it('begin storage failure returns failed status and never runs collection', async () => {
    const collection = vi.fn(); const store = new OutputStoreV2(await root(), { beforeOperation: () => { throw new Error('unwritable'); } });
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputStore: store, crawl: collection }); const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true });
    expect((await app.wait(run.runId)).state).toBe('failed'); expect(collection).not.toHaveBeenCalled();
    expect(JSON.parse((await app.readFile(run.runId, 'scan-status.json')).toString()).run.state).toBe('failed');
  });
});
it('detaches an abort-ignoring analyzer and never accepts its late positive', async () => {
  const entered = deferred<void>(); const late = deferred<ReturnType<typeof analysis>>(); let enteredOnce = false;
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: 'unit-test-credential', crawl: crawlPage(), analyzeCandidate: async (_candidate, _key, signal) => { if (enteredOnce) return analysis(); enteredOnce = true; entered.resolve(); if (signal.aborted) return analysis(); return late.promise; } });
  const first = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); await entered.promise; await app.cancel(first.runId);
  const terminal = await app.wait(first.runId); expect(terminal.state).toBe('cancelled'); expect(terminal.counts.confirmedFindings).toBe(0);
  const second = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); await app.wait(second.runId);
  late.resolve(analysis()); await tick(); expect(app.get(first.runId)).toEqual(terminal); expect(app.findings(second.runId).findings).toHaveLength(1);
});
it('independently bounds AI concurrency while crawler emits concurrent callbacks', async () => {
  let active = 0; let maximum = 0;
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: 'unit-test-credential', aiConcurrency: 1,
    crawl: async (_url, options = {}) => {
      const other = page(); other.url += '&other=1'; other.frames[0].snapshotId = 'other_snapshot';
      await Promise.all([options.onPage?.(page()), options.onPage?.(other)]); return { ...result(page(), options), counts: { ...counts, discoveredPages: 2, scannedPages: 2 } };
    }, analyzeCandidate: async () => { active++; maximum = Math.max(maximum, active); await tick(); active--; return analysis(); } });
  const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); expect((await app.wait(run.runId)).state).toBe('completed'); expect(maximum).toBe(1);
});
it('real CLEF classifier abort preserves completed chunks and bounds HTTP work', async () => {
  const called = deferred<void>(); let calls = 0;
  const fetchFn: typeof fetch = async (_url, init) => { calls++; called.resolve(); return new Promise<Response>((_resolve, reject) => init!.signal!.addEventListener('abort', () => reject(new Error('aborted')), { once: true })); };
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: 'unit-test-credential', crawl: crawlPage(), aiOptions: { fetch: fetchFn } });
  const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); await called.promise; await app.cancel(run.runId); const terminal = await app.wait(run.runId);
  expect(terminal.state).toBe('cancelled'); expect(calls).toBe(1); expect(app.review(run.runId).candidates[0].ai?.chunks[0].status).toBe('cancelled');
  expect(app.review(run.runId).candidates[0].ai?.chunks[0].reasonCode).toBe('USER_CANCELLED');
});
it('limits real classifier HTTP request count and retains remainder', async () => {
  let calls = 0;
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: 'unit-test-credential', maxAiRequests: 1,
    crawl: crawlPage(page('정상 안내 '.repeat(2000) + '온라인 카지노 가입 보너스')), aiOptions: { stateBudgetTokens: 100,
      fetch: async () => { calls++; return new Response(JSON.stringify({ model: 'cloudflare/clef', usage: { input_tokens: 10, output_tokens: 1 }, answers: { ad_class: { type: 'choice', choice: 'illegal_ad', confidence: .9,
        probabilities: { illegal_ad: .9, general_ad: 1/30, non_ad: 1/30, uncertain: 1/30 } } } })); } } });
  const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); const terminal = await app.wait(run.runId);
  expect(calls).toBe(1); expect(terminal.state).toBe('partial'); expect(app.review(run.runId).candidates[0].ai?.chunks.some(chunk => chunk.reasonCode === 'RESOURCE_LIMIT')).toBe(true);
});
it('bulk artifact timing appears identically in saved meta and public terminal run', async () => {
  const entered = deferred<void>(); const gate = deferred<void>();
  const store = new OutputStoreV2(await root(), { beforeOperation: async operation => {
    if(operation.operation === 'write' && operation.path.endsWith('/finding-details.json') && operation.path.includes('.staging-')) { entered.resolve(); await gate.promise; }
  } });
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputStore: store, crawl: crawlPage() }); const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true });
  await entered.promise; await new Promise<void>(resolve => setTimeout(resolve, 25)); const released = Date.now(); gate.resolve();
  const terminal = await app.wait(run.runId); expect(Date.parse(terminal.finishedAt!)).toBeGreaterThanOrEqual(released);
  const result = JSON.parse((await app.readFile(run.runId,'result.json')).toString()); const status = JSON.parse((await app.readFile(run.runId,'scan-status.json')).toString());
  expect(result.meta.finished_at).toBe(terminal.finishedAt); expect(result.meta.elapsed_sec).toBe(terminal.elapsedSec); expect(status.run).toEqual(terminal);
});
it.each(['cancel', 'deadline'] as const)('preserves a real positive chunk before later %s', async stop => {
  const nextRequest = deferred<void>(); let calls = 0;
  const fetchFn: typeof fetch = async (_url, init) => {
    calls++;
    if(calls === 1) return new Response(JSON.stringify({ model: 'cloudflare/clef', usage: { input_tokens: 10, output_tokens: 1 }, answers: { ad_class: { type: 'choice', choice: 'illegal_ad', confidence: .9,
      probabilities: { illegal_ad: .9, general_ad: 1/30, non_ad: 1/30, uncertain: 1/30 } } } }));
    nextRequest.resolve(); return new Promise<Response>((_resolve, reject) => init!.signal!.addEventListener('abort', () => reject(new Error('aborted')), { once: true }));
  };
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: 'unit-test-credential', maxDurationMs: stop === 'deadline' ? 300 : 10000,
    crawl: crawlPage(page('공개 페이지 정상 안내문 '.repeat(30) + '온라인 카지노 가입 배팅 보너스')), aiOptions: { fetch: fetchFn, stateBudgetTokens: 100 } });
  const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); await nextRequest.promise;
  expect(app.get(run.runId).counts.confirmedFindings).toBe(1);
  if(stop === 'cancel') await app.cancel(run.runId);
  const terminal = await app.wait(run.runId); expect(terminal.state).toBe(stop === 'cancel' ? 'cancelled' : 'partial');
  expect(terminal.counts.confirmedFindings).toBe(1); expect(terminal.counts.reviewCandidates).toBe(1);
  const chunks = app.review(run.runId).candidates[0].ai!.chunks; expect(chunks[0].status).toBe('completed');
  expect(chunks[1].reasonCode).toBe(stop === 'cancel' ? 'USER_CANCELLED' : 'TIME_LIMIT');
  expect(app.details(run.runId).details[0].ai!.chunks).toEqual(chunks);
  expect(JSON.parse((await app.readFile(run.runId, 'scan-status.json')).toString()).run).toEqual(terminal);
});
it('ignores a fully positive analyzer response returned after cancellation', async () => {
  const entered = deferred<void>();
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: 'unit-test-credential', crawl: crawlPage(), analyzeCandidate: async (_candidate, _key, signal) => {
    entered.resolve(); await new Promise<void>(resolve => signal.addEventListener('abort', () => resolve(), { once: true })); return analysis();
  } });
  const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); await entered.promise; await app.cancel(run.runId);
  const terminal = await app.wait(run.runId); expect(terminal.state).toBe('cancelled'); expect(terminal.counts.confirmedFindings).toBe(0);
  expect(app.review(run.runId).candidates[0].ai?.chunks[0].reasonCode).toBe('USER_CANCELLED');
});
function earlyProgress() {
  const planned = analysis('illegal_ad', true).chunks;
  return createAiAnalysis([planned[0], { ...planned[1], status: 'running', reasonCode: null },
    { chunkId: 'chunk-2', rawStart: planned[1].rawEnd, rawEnd: planned[1].rawEnd, status: 'pending', choice: null, probabilities: null, confidence: null, reasonCode: null }]);
}
it('rejects late completed chunks after cancellation and preserves accepted positive/progress ranges', async () => {
  const entered = deferred<void>(); const progress = earlyProgress();
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: 'unit-test-credential', crawl: crawlPage(), analyzeCandidate: async (_candidate, _key, signal, options) => {
    options!.onProgress!(progress); entered.resolve();
    await new Promise<void>(resolve => signal.addEventListener('abort', () => resolve(), { once: true }));
    return createAiAnalysis(progress.chunks.map(chunk => ({ ...progress.chunks[0], chunkId: chunk.chunkId, rawStart: chunk.rawStart, rawEnd: chunk.rawEnd, confidence: .99 })));
  } });
  const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); await entered.promise; await app.cancel(run.runId);
  const terminal = await app.wait(run.runId); expect(terminal.state).toBe('cancelled'); expect(terminal.counts.confirmedFindings).toBe(1); expect(terminal.counts.reviewCandidates).toBe(1);
  const chunks = app.review(run.runId).candidates[0].ai!.chunks;
  expect(chunks[0]).toEqual(progress.chunks[0]); expect(chunks.slice(1)).toEqual(progress.chunks.slice(1).map(chunk => ({ ...chunk, status: chunk.status === 'running' ? 'cancelled' : 'not_started', reasonCode: 'USER_CANCELLED' })));
  expect(app.details(run.runId).details[0].ai!.chunks).toEqual(chunks);
  expect(JSON.parse((await app.readFile(run.runId, 'scan-status.json')).toString()).run).toEqual(terminal);
});
it('preserves accepted positive and converts unfinished ranges to AI errors after analyzer rejection', async () => {
  const progress = earlyProgress(); const secret = 'test-rejection-secret';
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: secret, crawl: crawlPage(), analyzeCandidate: async (_candidate, _key, _signal, options) => {
    options!.onProgress!(progress); throw new Error(`transport failed ${secret}`);
  } });
  const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); const terminal = await app.wait(run.runId);
  expect(terminal.state).toBe('partial'); expect(terminal.counts.confirmedFindings).toBe(1); expect(terminal.counts.reviewCandidates).toBe(1);
  expect(terminal.errors.some(error => error.code === 'STORAGE_ERROR')).toBe(false); expect(JSON.stringify(terminal)).not.toContain(secret);
  const review = app.review(run.runId).candidates[0]; expect(review.reason).toBe('AI_ERROR');
  expect(review.ai!.chunks[0]).toEqual(progress.chunks[0]); expect(review.ai!.chunks.slice(1)).toEqual(progress.chunks.slice(1).map(chunk => ({ ...chunk, status: 'error', reasonCode: 'AI_HTTP_ERROR' })));
  expect(app.details(run.runId).details[0].ai!.chunks).toEqual(review.ai!.chunks);
  const details = JSON.parse((await app.readFile(run.runId, 'finding-details.json')).toString()); expect(details.details[0].ai.chunks).toEqual(review.ai!.chunks);
  expect(JSON.parse((await app.readFile(run.runId, 'scan-status.json')).toString()).run).toEqual(terminal);
});
it.each(['cancel', 'deadline', 'resource'] as const)('keeps accepted ranges and terminalizes running versus pending after %s abort', async stop => {
  const entered = deferred<void>(); const progress = earlyProgress();
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: 'unit-test-credential', maxDurationMs: stop === 'deadline' ? 50 : 10000, maxAiRequests: 1,
    crawl: crawlPage(), analyzeCandidate: async (_candidate, _key, signal, options) => {
      if(stop === 'resource') await options!.fetch!('https://fixed.test');
      options!.onProgress!(progress); entered.resolve();
      if(stop === 'resource') { options!.reserveRequest!(); }
      else await new Promise<void>(resolve => signal.addEventListener('abort', () => resolve(), { once: true }));
      return createAiAnalysis(progress.chunks.map(chunk => ({ ...progress.chunks[0], chunkId: chunk.chunkId, rawStart: chunk.rawStart, rawEnd: chunk.rawEnd })));
    }, aiOptions: { fetch: async () => new Response('{}') } });
  const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); await entered.promise; if(stop === 'cancel') await app.cancel(run.runId); const terminal = await app.wait(run.runId);
  expect(terminal.state).toBe(stop === 'cancel' ? 'cancelled' : 'partial'); expect(terminal.counts.confirmedFindings).toBe(1); expect(terminal.counts.reviewCandidates).toBe(1);
  const chunks = app.review(run.runId).candidates[0].ai!.chunks; const reasonCode = stop === 'deadline' ? 'TIME_LIMIT' : stop === 'resource' ? 'RESOURCE_LIMIT' : 'USER_CANCELLED';
  expect(chunks[0]).toEqual(progress.chunks[0]); expect(chunks[1]).toEqual({ ...progress.chunks[1], status: 'cancelled', reasonCode });
  expect(chunks[2]).toEqual({ ...progress.chunks[2], status: 'not_started', reasonCode });
  expect(app.details(run.runId).details[0].ai!.chunks).toEqual(chunks); expect(terminal.errors.some(error => error.code === 'STORAGE_ERROR')).toBe(false);
});
it('preserves accepted completed probabilities when later progress and normal final analysis overwrite them', async () => {
  const progress = earlyProgress();
  const changed = createAiAnalysis(progress.chunks.map(chunk => ({ ...analysis('non_ad').chunks[0], chunkId: chunk.chunkId, rawStart: chunk.rawStart, rawEnd: chunk.rawEnd })));
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: 'unit-test-credential', crawl: crawlPage(), analyzeCandidate: async (_candidate, _key, _signal, options) => {
    options!.onProgress!(progress); options!.onProgress!(changed); return changed;
  } });
  const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); const terminal = await app.wait(run.runId);
  expect(terminal.state).toBe('completed'); expect(terminal.counts.confirmedFindings).toBe(1); expect(terminal.counts.reviewCandidates).toBe(0);
  const chunks = app.details(run.runId).details[0].ai!.chunks; expect(chunks[0]).toEqual(progress.chunks[0]); expect(chunks.slice(1)).toEqual(changed.chunks.slice(1));
  expect(JSON.parse((await app.readFile(run.runId,'finding-details.json')).toString()).details[0].ai.chunks).toEqual(chunks);
});
it('marks scheduled candidates without accepted request progress as not_started after user cancel', async () => {
  const entered = deferred<void>();
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: 'unit-test-credential', crawl: crawlPage(page(undefined, true)), analyzeCandidate: async (_candidate, _key, signal) => {
    entered.resolve(); await new Promise<void>(resolve => signal.addEventListener('abort', () => resolve(), { once: true })); return analysis();
  } });
  const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); await entered.promise; await app.cancel(run.runId); const terminal = await app.wait(run.runId);
  expect(terminal.state).toBe('cancelled'); expect(terminal.counts.confirmedFindings).toBe(0); expect(terminal.counts.reviewCandidates).toBe(2);
  for (const candidate of app.review(run.runId).candidates) expect(candidate.ai!.chunks).toEqual([expect.objectContaining({ rawStart: 0, rawEnd: candidate.evidenceText.length, status: 'not_started', reasonCode: 'USER_CANCELLED' })]);
  const saved = JSON.parse((await app.readFile(run.runId, 'review.json')).toString()); expect(saved.candidates).toEqual(app.review(run.runId).candidates);
});
it('retains a producer not_started record when synchronous running progress cancels before transport', async () => {
  const planned = createAiAnalysis(analysis('illegal_ad', true).chunks.map(chunk => ({ ...chunk, status: 'pending', choice: null, probabilities: null, confidence: null, reasonCode: null })));
  let transportCalls = 0; let cancel: Promise<unknown> | undefined;
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: 'unit-test-credential', crawl: crawlPage(), analyzeCandidate: async (_candidate, _key, signal, options) => {
    options!.onProgress!(planned);
    options!.onProgress!(createAiAnalysis(planned.chunks.map((chunk, index) => ({ ...chunk, status: index === 0 ? 'running' : 'pending' }))));
    cancel = app.cancel(app.activeRunId!);
    if(!signal.aborted) { transportCalls++; return analysis(); }
    return createAiAnalysis(planned.chunks.map(chunk => ({ ...chunk, status: 'not_started', reasonCode: 'USER_CANCELLED' })));
  } });
  const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); const terminal = await app.wait(run.runId); await cancel;
  expect(transportCalls).toBe(0); expect(terminal.state).toBe('cancelled'); expect(terminal.counts.confirmedFindings).toBe(0);
  const chunks = app.review(run.runId).candidates[0].ai!.chunks; expect(chunks.every(chunk => chunk.status === 'not_started' && chunk.reasonCode === 'USER_CANCELLED')).toBe(true);
  expect(chunks.map(chunk => [chunk.rawStart, chunk.rawEnd])).toEqual(planned.chunks.map(chunk => [chunk.rawStart, chunk.rawEnd]));
});
