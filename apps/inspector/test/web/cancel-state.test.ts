/** Independent wire fixtures over real HTTP + Chromium. No production application/classifier/schema helpers. */
import { createServer, type ServerResponse } from 'node:http';
import { build } from 'esbuild';
import { chromium, type Browser, type Page } from 'playwright';
import { afterAll, afterEach, beforeAll, expect, it } from 'vitest';
import type { FindingDetailsFileV2 as FindingDetailsFile, ReviewFileV2 as ReviewFile, RunSnapshotV2 as RunSnapshot } from '../../src/core/v2.js';
import type { AiAnalysis, OfficialFinding } from '../../src/core/types.js';

const finding: OfficialFinding = { id: 'positive-1', url: 'https://public.example/page', is_violation: true, location: '#positive', evidence_text: '이미 확인된 양성 원문', technique: 'TRANSPARENT' };
function analysis(tail: 'running' | 'cancelled' | 'not_started' | 'error'): AiAnalysis {
  return { model: 'cloudflare/clef', summaryChunkId: 'positive', choice: 'illegal_ad', probabilities: { illegal_ad: .9, general_ad: .04, non_ad: .03, uncertain: .03 }, confidence: .9, chunks: [
    { chunkId: 'positive', rawStart: 0, rawEnd: 3, status: 'completed', choice: 'illegal_ad', probabilities: { illegal_ad: .9, general_ad: .04, non_ad: .03, uncertain: .03 }, confidence: .9, reasonCode: null },
    { chunkId: 'tail', rawStart: 3, rawEnd: finding.evidence_text.length, status: tail, choice: null, probabilities: null, confidence: null, reasonCode: tail === 'running' ? null : tail === 'error' ? 'AI_HTTP_ERROR' : 'USER_CANCELLED' },
  ] };
}
function snapshot(id: string, state: RunSnapshot['state']): RunSnapshot {
  return { runId: id, entryUrl: 'https://public.example/', startedAt: '2026-10-04T01:00:00Z', finishedAt: ['running', 'stopping'].includes(state) ? null : '2026-10-04T01:00:03Z', elapsedSec: 3,
    state, externalAnalysisConsent: true, ocrEnabled: false, ocrModel: null, imageCounts: { discovered: 0, captured: 0, ocrCompleted: 0, failed: 0, pending: 0, skipped: 0 }, requestCounts: { ocr: 0, clef: 0 }, aiEnabled: true, model: 'cloudflare/clef', counts: { discoveredPages: state === 'completed' ? 1 : 2, scannedPages: 1, failedPages: 0, skippedPages: 0, pendingPages: state === 'completed' ? 0 : 1, extraConfirmedFindings: 0, confirmedFindings: id === 'run-2' ? 0 : 1, reviewCandidates: id === 'run-2' ? 0 : 1 }, activeUrls: state === 'running' ? ['https://public.example/page'] : [], errors: [] };
}
function details(id: string, tail: Parameters<typeof analysis>[0]): FindingDetailsFile { if (id === 'run-2') return { schemaVersion: 2, runId: id, details: [] }; return { schemaVersion: 2, runId: id, details: [{ findingId: finding.id, candidateId: 'candidate-1', resultFile: 'result.json', sourceType: 'dom_text', sourceIds: [], sourceTextRanges: [], observationIds: [], decisionSource: 'clef', ruleIds: [], ai: analysis(tail), evidence: { snapshotId: 'captured-1', path: null, sha256: null } }] }; }
function review(id: string, tail: Parameters<typeof analysis>[0]): ReviewFile { if (id === 'run-2') return { schemaVersion: 2, runId: id, candidates: [] }; return { schemaVersion: 2, runId: id, candidates: [{ sourceType: 'dom_text', sourceIds: [], sourceTextRanges: [], candidateId: 'candidate-1', url: finding.url, location: finding.location, evidenceText: finding.evidence_text, techniques: ['TRANSPARENT'], reason: tail === 'error' ? 'AI_ERROR' : 'NOT_ANALYZED', ai: analysis(tail), evidence: { snapshotId: 'captured-1', path: null, sha256: null } }] }; }
const json = (response: ServerResponse, value: unknown, status = 200) => { if (!response.headersSent) response.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }); response.end(JSON.stringify(value)); };
let browser: Browser; let page: Page | undefined; const servers = new Set<ReturnType<typeof createServer>>();
beforeAll(async () => { browser = await chromium.launch({ headless: true }); });
afterEach(async () => {
  await page?.close(); page = undefined;
  for (const server of servers) await new Promise<void>(res => { server.close(() => res()); server.closeAllConnections(); });
  servers.clear();
});
afterAll(async () => { await browser.close(); });
async function fixture(options: { cancel: 'terminal' | 'stopping' | 'error'; holdOld?: boolean }) {
  const bundle = await build({ entryPoints: ['src/web/index.ts'], bundle: true, write: false, platform: 'browser', format: 'iife' });
  let id = 'run-1', state: RunSnapshot['state'] = 'running', tail: Parameters<typeof analysis>[0] = 'running', cancels = 0;
  const calls: string[] = [], held: (() => void)[] = []; let holding = false;
  const server = createServer(async (req, res) => {
    const path = req.url ?? '/';
    if (path === '/') { res.end('<div id="app"></div><script>window.__INSPECTOR_BOOTSTRAP__={sessionToken:"local-mock-session",config:{aiConfigured:true,aiRequired:true,ocrModel:"google/gemini-3.8-flash",limits:{maxOcrRequests:100,maxClefRequests:1000,maxImageBytes:8388608,maxImagePixels:16000000},model:"cloudflare/clef",outputRoot:"synthetic-output"},pollIntervalMs:250}</script><script src="/web.js"></script>'); return; }
    if (path === '/web.js') { res.writeHead(200, { 'Content-Type': 'text/javascript' }); res.end(bundle.outputFiles[0].text); return; }
    calls.push(path); expect(req.headers.authorization).toBe('Bearer local-mock-session');
    if (path === '/api/runs') { req.resume(); json(res, snapshot(id, state), 202); return; }
    if (path.endsWith('/cancel')) {
      req.resume(); cancels++; holding = false;
      if (options.cancel === 'error') { json(res, { error: { code: 'FORBIDDEN', message: '모의 취소 요청 실패' } }, 403); return; }
      state = options.cancel === 'terminal' ? 'cancelled' : 'stopping'; if (state === 'cancelled') tail = 'cancelled'; json(res, snapshot(id, state), state === 'cancelled' ? 200 : 202); return;
    }
    const routeId = /^\/api\/runs\/([^/]+)/.exec(path)?.[1] ?? id;
    if (path.endsWith('/finding-details') || path.endsWith('/review')) {
      const captured = structuredClone(path.endsWith('/review') ? review(routeId, tail) : details(routeId, tail));
      if (holding && options.holdOld) { res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }); res.flushHeaders(); held.push(() => json(res, captured)); } else json(res, captured); return;
    }
    if (path.endsWith('/related-links')) { json(res, { runId: routeId, candidates: [] }); return; }
    if (path.endsWith('/extra-findings')) { json(res, { runId: routeId, findings: [] }); return; }
    if (path.endsWith('/ocr')) { json(res, { schemaVersion: 2, runId: routeId, enabled: false, model: null, images: [] }); return; }
    if (path.endsWith('/findings')) { json(res, { runId: routeId, findings: routeId === 'run-2' ? [] : [finding] }); return; }
    if (path.endsWith('/files/scan-status.json')) { json(res, { schemaVersion: 2, run: snapshot(routeId, state), scope: { hostname: 'public.example', framePolicy: 'embedded', skipped: [], unvisitedUrls: state === 'completed' ? [] : ['https://public.example/pending'] }, files: { resultPath: `runs/${routeId}/result.json`, reviewPath: `runs/${routeId}/review.json`, findingDetailsPath: `runs/${routeId}/finding-details.json`, evidenceDir: `runs/${routeId}/evidence`, resultSha256: '0'.repeat(64), extraResultPath: `runs/${routeId}/result_extra.json`, extraResultSha256: '1'.repeat(64), ocrPath: `runs/${routeId}/ocr.json` }, resultSaved: true, extraResultSaved: true, imageScope: { enabled: false, framePolicy: 'first', unsupportedKinds: ['canvas', 'video', 'animation_remaining_frames'], pendingImageIds: [] } }); return; }
    json(res, snapshot(routeId, state));
  });
  servers.add(server);
  await new Promise<void>(res => server.listen(0, '127.0.0.1', res)); const address = server.address(); if (!address || typeof address === 'string') throw new Error('No mock port');
  page = await browser.newPage(); await page.goto(`http://127.0.0.1:${address.port}`); await page.getByLabel('진입 URL').fill('https://public.example/'); await page.getByLabel('외부 분석 전송 동의').check();
  await page.getByRole('button', { name: '점검 시작', exact: true }).click(); await page.waitForFunction(() => document.querySelectorAll('.analysis li').length === 4);
  return { page, calls, held, hold() { holding = true; }, update(nextState: RunSnapshot['state'], nextTail: Parameters<typeof analysis>[0]) { state = nextState; tail = nextTail; },
    nextRun() { id = 'run-2'; state = 'completed'; }, get cancels() { return cancels; }, async close() { for (const release of held.splice(0)) release(); await page?.close(); await new Promise<void>(res => { server.close(() => res()); server.closeAllConnections(); }); servers.delete(server); } };
}
async function displayedTail(page: Page): Promise<string[]> { return page.locator('li').filter({ hasText: /^tail ·/ }).allTextContents(); }
async function waitTail(page: Page, status: string) { await page.waitForFunction(status => { const tails = [...document.querySelectorAll('li')].filter(node => node.textContent?.startsWith('tail ·')); return tails.length === 2 && tails.every(node => node.textContent?.includes(` · ${status} ·`)); }, status, { timeout: 3000 }); }
it.each(['terminal', 'stopping'] as const)('reloads final details/review for the same run after %s cancel response', async cancel => {
  const api = await fixture({ cancel });
  try {
    expect((await displayedTail(api.page)).every(item => item.includes(' · running ·'))).toBe(true);
    const initial = api.calls.filter(path => path.endsWith('/finding-details')).length;
    await api.page.getByRole('button', { name: '점검 중지', exact: true }).click();
    if (cancel === 'stopping') { await api.page.locator('.badge.stopping').waitFor(); api.update('cancelled', 'not_started'); }
    await api.page.locator('.badge.cancelled').waitFor(); await waitTail(api.page, cancel === 'terminal' ? 'cancelled' : 'not_started');
    expect(api.calls.filter(path => path.endsWith('/finding-details')).length).toBeGreaterThan(initial); expect(api.cancels).toBe(1);
    expect(await api.page.locator('tbody tr').count()).toBe(1); expect(await api.page.locator('.review-card').count()).toBe(1);
  } finally { await api.close(); }
});
it('recovers artifact polling when cancel fails and the same run continues', async () => {
  const api = await fixture({ cancel: 'error' });
  try {
    await api.page.getByRole('button', { name: '점검 중지', exact: true }).click(); await api.page.getByRole('alert').filter({ hasText: '모의 취소 요청 실패' }).waitFor();
    api.update('running', 'error'); await api.page.locator('.badge.running').waitFor(); await waitTail(api.page, 'error');
    expect(await api.page.getByRole('button', { name: '점검 중지', exact: true }).isEnabled()).toBe(true);
  } finally { await api.close(); }
});
it.each(['same-run', 'new-run'] as const)('discards held pre-cancel details/review after terminal refresh in %s', async phase => {
  const api = await fixture({ cancel: 'terminal', holdOld: true });
  try {
    api.hold(); await api.page.waitForResponse(response => response.url().endsWith('/findings'));
    const deadline = Date.now() + 1000; while (api.held.length < 2 && Date.now() < deadline) await new Promise(res => setTimeout(res, 10));
    expect(api.held.length).toBe(2); const old = api.held.splice(0);
    await api.page.getByRole('button', { name: '점검 중지', exact: true }).click(); await api.page.locator('.badge.cancelled').waitFor(); await waitTail(api.page, 'cancelled');
    if (phase === 'new-run') { api.nextRun(); await api.page.getByRole('button', { name: '점검 시작', exact: true }).click(); await api.page.getByText('실행 ID: run-2', { exact: true }).waitFor(); }
    const response = api.page.waitForEvent('requestfinished', { predicate: request => request.url().endsWith('/api/runs/run-1/review') });
    for (const release of old) release(); await response; await new Promise(res => setTimeout(res, 100));
    if (phase === 'new-run') { await api.page.getByText('공식 탐지 0건', { exact: true }).waitFor(); expect(await api.page.locator('tbody tr').count()).toBe(0); expect(await api.page.locator('.review-card').count()).toBe(0); }
    else expect((await displayedTail(api.page)).every(item => item.includes(' · cancelled ·'))).toBe(true);
  } finally { await api.close(); }
});
