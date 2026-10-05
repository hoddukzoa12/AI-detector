/** Mock decisions verify wiring/retention only, never actual CLEF quality or connectivity. */
import { afterEach, expect, it } from 'vitest';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import { chromium, type Browser, type Page } from 'playwright';
import { InspectorApplication, type ApplicationOptions } from '../../src/application/index.js';
import { startServer, type InspectorServer } from '../../src/server/index.js';
import { startFixtureSite, type FixtureSite } from '../fixtures/site.js';
import { assertTruth, independentOfficialResult, sha256 } from '../../scripts/verification.js';
import type { RunSnapshotV2 as RunSnapshot, ReviewFileV2 as ReviewFile, FindingDetailsFileV2 as FindingDetailsFile } from '../../src/core/index.js';
import { createFixtureTransport } from '../../scripts/mock-transport.js';
let root: string, server: InspectorServer | undefined, fixture: FixtureSite | undefined, browser: Browser | undefined;
const fakeKey = 'offline-ai-wiring-placeholder';
afterEach(async () => { await server?.close(); server = undefined; await browser?.close(); browser = undefined; await fixture?.stop(); fixture = undefined; if (root) await rm(root, { recursive: true, force: true }); });
const completed = (run: RunSnapshot) => ['completed', 'partial', 'failed', 'cancelled'].includes(run.state);
async function wait(api: (path: string) => Promise<Response>, id: string, predicate = completed): Promise<RunSnapshot> {
  const end = Date.now() + 60000; while (Date.now() < end) { const run = await (await api(`/api/runs/${id}`)).json() as RunSnapshot; if (predicate(run)) return run; await delay(50); } throw new Error('Integrated run timed out');
}
function decision(choice = 'illegal_ad', probability = .9): Response {
  return new Response(JSON.stringify({ model: 'cloudflare/clef', usage: { input_tokens: 10, output_tokens: 1 }, answers: { ad_class: { type: 'choice', choice, confidence: probability,
    probabilities: Object.fromEntries(['illegal_ad', 'general_ad', 'non_ad', 'uncertain'].map(key => [key, key === choice ? probability : (1 - probability) / 3])) } } }));
}
function checkRequest(endpoint: Parameters<typeof fetch>[0], init?: RequestInit): { rawText: string } {
  expect(endpoint).toBe('https://openrouter.ai/api/alpha/decisions'); expect(init?.method).toBe('POST'); expect(init?.redirect).toBe('error');
  expect((init?.headers as Record<string, string>).Authorization).toBe(`Bearer ${fakeKey}`);
  const body = JSON.parse(init!.body as string); expect(body.model).toBe('cloudflare/clef'); expect(Object.keys(body.state).sort()).toEqual(['links', 'normalizedText', 'rawText']);
  expect(typeof body.state.rawText).toBe('string'); expect(Array.isArray(body.state.links)).toBe(true); expect(JSON.stringify(body)).not.toContain(fakeKey);
  expect(JSON.stringify(body)).not.toMatch(/"(?:html|cookies|history|apiKey)"/); return body.state;
}
async function setup(options: ApplicationOptions) {
  root = await mkdtemp(resolve(tmpdir(), 'inspector-ai-integration-')); fixture = await startFixtureSite();
  const app = new InspectorApplication({ outputRoot: root, apiKey: fakeKey, executablePath: chromium.executablePath(),
    crawlOptions: { dynamicWaitMs: 0, resourceWaitMs: 0, scrollSteps: 0, navigationTimeoutMs: 1000 }, ...options });
  server = await startServer({ application: app, port: 0, config: { mode: 'npm', apiKey: fakeKey, outputRoot: root, host: '127.0.0.1', port: 0 } }); browser = await chromium.launch({ headless: true }); const page = await browser.newPage(); await page.goto(server.url);
  await page.locator('#external-consent').check();
  await page.waitForFunction(() => !(document.querySelector('[data-action="start"]') as HTMLButtonElement).disabled);
  const headers = { Authorization: `Bearer ${server.sessionToken}`, Origin: server.url, 'Content-Type': 'application/json' };
  const api = (path: string, body?: unknown) => fetch(server!.url + path, { headers, method: body === undefined ? 'GET' : 'POST', ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
  return { page, api, app };
}
async function start(page: Page, entry: string, ocr = false) {
  await page.locator('#entry-url').fill(entry); await page.locator('#ocr-enabled').setChecked(ocr);
  const response = page.waitForResponse(response => response.url().endsWith('/api/runs') && response.request().method() === 'POST'); await page.getByRole('button', { name: '점검 시작', exact: true }).click();
  const started = await response; expect(started.status()).toBe(202);
  return (await started.json() as RunSnapshot).runId;
}
async function artifacts(api: (path: string) => Promise<Response>, id: string) {
  const bytes = Buffer.from(await (await api(`/api/runs/${id}/files/result.json`)).arrayBuffer()); const result = independentOfficialResult(bytes);
  const review = await (await api(`/api/runs/${id}/files/review.json`)).json() as ReviewFile; const details = await (await api(`/api/runs/${id}/files/finding-details.json`)).json() as FindingDetailsFile;
  const statusText = await (await api(`/api/runs/${id}/files/scan-status.json`)).text(); const status = JSON.parse(statusText);
  expect(status.resultSaved).toBe(true); expect(status.files.resultSha256).toBe(sha256(bytes));
  for (const value of [bytes.toString(), JSON.stringify(review), JSON.stringify(details), statusText]) expect(value).not.toContain(fakeKey);
  expect(bytes).toEqual(await readFile(resolve(root, 'runs', id, 'result.json')));
  return { result, review, details, status, bytes };
}
for (const scenario of ['uncertain', 'below-threshold', 'http-error'] as const) it(`real DOM + classifier + server + UI: mock ${scenario} stays review without local fallback`, async () => {
  let calls = 0; const { page, api } = await setup({ aiOptions: { fetch: async (endpoint, init) => {
    calls++; checkRequest(endpoint, init); return scenario === 'http-error' ? new Response('mock failure', { status: 503 }) : decision(scenario === 'uncertain' ? 'uncertain' : 'illegal_ad', scenario === 'uncertain' ? .9 : .79);
  } } });
  const id = await start(page, fixture!.urls.queryOne); const run = await wait(api, id); expect(run.state).toBe(scenario === 'http-error' ? 'partial' : 'completed'); expect(calls).toBe(1);
  const { result, review, details } = await artifacts(api, id); expect(result.findings).toEqual([]); expect(details.details).toEqual([]); expect(review.candidates.length).toBe(1);
  expect(review.candidates[0].evidenceText).toBe(fixture!.expectedFindings.find(item => item.caseId === 'query-one')!.rawEvidence);
  expect(review.candidates[0].reason).toBe(scenario === 'http-error' ? 'AI_ERROR' : 'UNCERTAIN'); expect(review.candidates[0].ai?.chunks[0].status).toBe(scenario === 'http-error' ? 'error' : 'completed');
  await page.waitForFunction(() => document.querySelectorAll('.review-card').length === 1); expect(await page.locator('.review-card').textContent()).toContain(scenario === 'http-error' ? 'AI_HTTP_ERROR' : 'UNCERTAIN');
}, 60000);
it('real long raw DOM + mock positive chunk and unfinished resource-limited chunk preserve confirmation and review', async () => {
  let calls = 0; const { page, api } = await setup({ aiOptions: { stateBudgetTokens: 120, maxChunks: 1, fetch: async (endpoint, init) => { calls++; checkRequest(endpoint, init); return decision('illegal_ad', .8); } } });
  const id = await start(page, fixture!.urls.types); const run = await wait(api, id); expect(run.state).toBe('partial'); expect(calls).toBeGreaterThan(0);
  const { result, review, details } = await artifacts(api, id); assertTruth(result, fixture!.expectedFindings.filter(item => item.url === fixture!.urls.types)); const long = fixture!.expectedFindings.find(item => item.caseId === 'long-tail')!;
  expect(result.findings).toContainEqual(expect.objectContaining({ location: long.location, evidence_text: long.rawEvidence, technique: long.technique }));
  const pending = review.candidates.find(item => item.location === long.location)!; expect(pending).toBeDefined(); expect(pending.reason).toBe('NOT_ANALYZED');
  expect(pending.ai!.chunks[0].status).toBe('completed'); expect(pending.ai!.chunks[0].probabilities!.illegal_ad).toBe(.8);
  expect(pending.ai!.chunks.at(-1)!.status).toBe('not_started'); expect(pending.ai!.chunks.at(-1)!.reasonCode).toBe('RESOURCE_LIMIT');
  expect(pending.ai!.chunks[0].rawStart).toBe(0); expect(pending.ai!.chunks.at(-1)!.rawEnd).toBe(long.rawEvidence.length);
  expect(details.details.every(detail => detail.decisionSource === 'clef')).toBe(true);
}, 60000);
it('real DOM + mock positive then hanging chunk: UI cancel freezes findings; late positive cannot change saved bytes', async () => {
  let longCalls = 0, releaseLate: (() => void) | undefined;
  const { page, api } = await setup({ aiOptions: { stateBudgetTokens: 120, fetch: async (endpoint, init) => {
    const state = checkRequest(endpoint, init);
    if (state.rawText.includes('공개 게시판의 정상적인 안내')) {
      longCalls++; if (longCalls === 2) return new Promise<Response>(res => { releaseLate = () => res(decision('illegal_ad', .99)); });
    }
    return decision();
  } } });
  const id = await start(page, fixture!.urls.types); const deadline = Date.now() + 30000; while (!releaseLate && Date.now() < deadline) await delay(25); expect(releaseLate).toBeDefined();
  const before = await (await api(`/api/runs/${id}/findings`)).json(); expect(before.findings.some((item: { location: string }) => item.location === '#long-tail')).toBe(true);
  // Observe active chunks in both places before cancellation, then require final saved states below.
  await page.waitForFunction(() => {
    const row = [...document.querySelectorAll('tbody tr')].find(node => node.textContent?.includes('#long-tail'));
    const card = [...document.querySelectorAll('.review-card')].find(node => node.textContent?.includes('#long-tail'));
    return [row, card].every(node => node && [...node.querySelectorAll('.analysis li')].some(chunk => chunk.textContent?.includes(' · running ·')));
  });
  await page.getByRole('button', { name: '점검 중지', exact: true }).click(); const run = await wait(api, id); expect(run.state).toBe('cancelled');
  const saved = await artifacts(api, id); expect(saved.result.findings).toEqual(before.findings); const long = saved.review.candidates.find(item => item.location === '#long-tail')!;
  expect(long.ai!.chunks[0].status).toBe('completed'); expect(long.ai!.chunks.some(chunk => chunk.status === 'cancelled' || chunk.status === 'not_started')).toBe(true);
  const hash = sha256(saved.bytes); releaseLate!(); await delay(250); expect(sha256(Buffer.from(await (await api(`/api/runs/${id}/files/result.json`)).arrayBuffer()))).toBe(hash);
  expect((await artifacts(api, id)).review).toEqual(saved.review); await page.waitForFunction(() => document.querySelector('.badge.cancelled'));
  const longFinding = saved.result.findings.find(item => item.location === '#long-tail')!;
  const longDetail = saved.details.details.find(item => item.findingId === longFinding.id)!;
  const renderedChunks = (chunks: NonNullable<typeof long.ai>['chunks']) => chunks.map(chunk => ({
    text: `${chunk.chunkId} · UTF-16 [${chunk.rawStart}, ${chunk.rawEnd}) · ${chunk.status} · ${chunk.choice ?? '미판정'}${chunk.reasonCode ? ` · ${chunk.reasonCode}` : ''}`,
    probabilities: chunk.probabilities,
  }));
  const displayedChunks = async (selector: ReturnType<Page['locator']>) => (await selector.locator('.analysis li').allTextContents()).map(text => {
    const marker = text.lastIndexOf(' · 확률 ');
    return { text: marker < 0 ? text : text.slice(0, marker), probabilities: marker < 0 ? null : JSON.parse(text.slice(marker + ' · 확률 '.length)) };
  });
  const row = page.locator('tbody tr').filter({ hasText: '#long-tail' });
  const card = page.locator('.review-card').filter({ hasText: '#long-tail' });
  await expect.poll(() => displayedChunks(row), { timeout: 5000 }).toEqual(renderedChunks(longDetail.ai!.chunks));
  await expect.poll(() => displayedChunks(card), { timeout: 5000 }).toEqual(renderedChunks(long.ai!.chunks));
  expect([...longDetail.ai!.chunks, ...long.ai!.chunks].some(chunk => ['running', 'pending'].includes(chunk.status))).toBe(false);
}, 60000);
it('real crawl resource page limit keeps confirmed 17 and unvisited ranges separate from completed', async () => {
  const mock = createFixtureTransport(); const { page, api } = await setup({ crawlOptions: { maxPages: 2, concurrency: 1, dynamicWaitMs: 0, resourceWaitMs: 0, scrollSteps: 0 },
    aiOptions: { fetch: mock.fetch }, ocrOptions: { fetch: mock.fetch } });
  const id = await start(page, fixture!.urls.entry); const run = await wait(api, id); expect(run.state).toBe('partial');
  const { result, status } = await artifacts(api, id);
  assertTruth(result, fixture!.expectedFindings.filter(item => [fixture!.urls.entry, fixture!.urls.types].includes(item.url)));
  expect(result.findings.length).toBe(17); expect(status.scope.unvisitedUrls.length).toBeGreaterThan(0); expect(status.run.errors.some((item: { code: string }) => item.code === 'RESOURCE_LIMIT')).toBe(true);
  expect(mock.counts().clef).toBeGreaterThan(0); expect(run.requestCounts).toEqual(mock.counts()); expect(run.requestCounts.ocr).toBe(0);
}, 60000);
