/** V2 mock API rendered in Chromium. These tests do not exercise the production server or provider accuracy. */
import { createServer, type Server } from 'node:http';
import { readFile } from 'node:fs/promises';
import { build } from 'esbuild';
import { chromium, type Browser, type Page } from 'playwright';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import type { AiAnalysis, OfficialFinding, RunState } from '../../src/core/types.js';
import type { ExtraFinding, FindingDetailV2, OcrFile, OcrImageOccurrence, PublicConfigV2, ReviewCandidateV2, RunSnapshotV2, ScanStatusFileV2 } from '../../src/core/v2.js';

const config: PublicConfigV2 = { aiConfigured: true, aiRequired: true, model: 'cloudflare/clef', ocrModel: 'google/gemini-3.8-flash', outputRoot: 'synthetic-output', limits: { maxOcrRequests: 100, maxClefRequests: 1000, maxImageBytes: 8388608, maxImagePixels: 16000000 } };
const raw = '<img src=x onerror="window.attacked=true">한글🙂';
const ai: AiAnalysis = { model: 'cloudflare/clef', choice: 'illegal_ad', probabilities: { illegal_ad: .9, general_ad: .04, non_ad: .03, uncertain: .03 }, confidence: .9, summaryChunkId: 'positive', chunks: [{ chunkId: 'positive', rawStart: 0, rawEnd: raw.length, status: 'completed', choice: 'illegal_ad', probabilities: { illegal_ad: .9, general_ad: .04, non_ad: .03, uncertain: .03 }, confidence: .9, reasonCode: null }] };
const official: OfficialFinding = { id: 'dom-positive', url: 'https://public.example/', location: '#text', technique: 'TRANSPARENT', evidence_text: raw, is_violation: true };
const extra: ExtraFinding = { id: 'image-positive', url: official.url, location: '#frame >>> #image', technique: 'ETC', extra_finding: 'IMAGE_AD_OCR', evidence_text: raw, is_violation: true };
const evidence = { snapshotId: 'snapshot-1', path: null, sha256: null };
function snapshot(state: RunState = 'running'): RunSnapshotV2 {
  return { runId: 'run-1', entryUrl: official.url, state, startedAt: '2026-10-04T01:00:00Z', finishedAt: ['running', 'stopping'].includes(state) ? null : '2026-10-04T01:00:03Z', elapsedSec: 3, aiEnabled: true, model: config.model, externalAnalysisConsent: true, ocrEnabled: false, ocrModel: null, counts: { discoveredPages: 1, scannedPages: 1, failedPages: 0, skippedPages: 0, pendingPages: 0, confirmedFindings: 0, extraConfirmedFindings: 0, reviewCandidates: 0 }, imageCounts: { discovered: 0, captured: 0, ocrCompleted: 0, failed: 0, pending: 0, skipped: 0 }, requestCounts: { ocr: 0, clef: 0 }, activeUrls: [], errors: [] };
}
function image(overrides: Partial<OcrImageOccurrence> = {}): OcrImageOccurrence {
  return { imageId: 'image-1', url: official.url, frameUrl: 'https://embedded.example/frame', framePath: ['#frame'], location: '#frame >>> #image', snapshotId: evidence.snapshotId, sourceKind: 'img', sourceIndex: 0, imageUrl: 'https://assets.example/unsafe.svg', capturedAt: '2026-10-04T01:00:01Z', original: { assetId: 'original-1', path: 'images/original.svg', sha256: 'a'.repeat(64), mime: 'image/svg+xml', byteLength: 80 }, input: { assetId: 'png-1', path: 'images/input.png', sha256: 'b'.repeat(64), mime: 'image/png', byteLength: 100, width: 10, height: 10, frameIndex: 0 }, styles: [], concealment: ['TRANSPARENT', 'OFFSCREEN'], status: 'completed', extractionStatus: 'readable', text: raw, confidence: null, model: config.ocrModel, promptVersion: 'ocr-v1', cacheOf: null, attemptCount: 1, usage: { promptTokens: null, completionTokens: null, totalTokens: null, costUsd: null }, reasonCode: null, ...overrides };
}
let browser: Browser, server: Server, page: Page, base: string;
let current: RunSnapshotV2, publicConfig: PublicConfigV2, findings: OfficialFinding[], extras: ExtraFinding[], details: FindingDetailV2[], reviews: ReviewCandidateV2[], images: OcrImageOccurrence[], starts: unknown[], requested: string[], previewType: string, downloadError: boolean, invalidPng: boolean, startError: string | null;
function ocr(): OcrFile { return { schemaVersion: 2, runId: current.runId, enabled: current.ocrEnabled, model: current.ocrModel, images }; }
function scanStatus(): ScanStatusFileV2 { return { schemaVersion: 2, run: current, scope: { hostname: 'public.example', framePolicy: 'embedded', skipped: [], unvisitedUrls: ['https://public.example/pending'] }, files: { resultPath: 'result.json', extraResultPath: 'result_extra.json', reviewPath: 'review.json', findingDetailsPath: 'finding-details.json', evidenceDir: 'evidence', resultSha256: 'a'.repeat(64), extraResultSha256: 'b'.repeat(64), ocrPath: 'ocr.json' }, resultSaved: true, extraResultSaved: true, imageScope: { enabled: current.ocrEnabled, framePolicy: 'first', unsupportedKinds: ['canvas', 'video', 'animation_remaining_frames'], pendingImageIds: images.filter(i => ['not_started', 'cancelled'].includes(i.status)).map(i => i.imageId) } }; }
beforeAll(async () => {
  const bundle = await build({ entryPoints: ['src/web/index.ts'], bundle: true, write: false, platform: 'browser', format: 'iife' });
  const css = await readFile('src/web/styles.css', 'utf8');
  const png = await readFile('test/fixtures/ocr-assets/no-text.png');
  server = createServer(async (req, res) => {
    const path = req.url ?? '/'; const json = (value: unknown, status = 200) => { res.writeHead(status, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(value)); };
    if (path === '/') { res.end('<html lang="ko"><link rel="stylesheet" href="/web.css"><div id="app"></div><script>window.__INSPECTOR_BOOTSTRAP__={sessionToken:"mock-session",pollIntervalMs:250}</script><script src="/web.js"></script></html>'); return; }
    if (path === '/web.js') { res.writeHead(200, { 'Content-Type': 'text/javascript' }); res.end(bundle.outputFiles[0].text); return; }
    if (path === '/web.css') { res.writeHead(200, { 'Content-Type': 'text/css' }); res.end(css); return; }
    requested.push(path);
    if (req.headers.authorization !== 'Bearer mock-session') { json({ error: { code: 'UNAUTHORIZED', message: '인증 필요' } }, 401); return; }
    if (path === '/api/config') { json(publicConfig); return; }
    if (path === '/api/runs' && req.method === 'POST') { let body = ''; for await (const chunk of req) body += String(chunk); const input = JSON.parse(body); starts.push(input); if (startError) { json({ error: { code: startError, message: '모의 시작 거부' } }, startError === 'ACTIVE_RUN' ? 409 : 400); return; } current.ocrEnabled = input.ocrEnabled === true; current.ocrModel = current.ocrEnabled ? config.ocrModel : null; json(current, 202); return; }
    if (path.includes('/images/')) { res.writeHead(200, { 'Content-Type': previewType, 'X-Content-Type-Options': 'nosniff' }); res.end(previewType === 'image/png' && !invalidPng ? png : '<svg onload="window.attacked=true"/>'); return; }
    if (path.includes('/files/') && downloadError) { json({ error: { code: 'NOT_FOUND', message: '파일 기록 실패' } }, 404); return; }
    if (path.endsWith('/related-links')) { json({ runId: current.runId, candidates: [{ candidateId: 'image-owner', links: ['https://owned.example/image-link', '<img src=x onerror=window.attacked=true>'] }, { candidateId: 'dom-1', links: ['https://owned.example/text-link'] }, { candidateId: 'review-1', links: ['https://owned.example/review-link'] }] }); return; }
    if (path.endsWith('/extra-findings')) { json({ runId: current.runId, findings: extras }); return; }
    if (path.endsWith('/findings')) { json({ runId: current.runId, findings }); return; }
    if (path.endsWith('/finding-details') || path.endsWith('/finding-details.json')) { json({ schemaVersion: 2, runId: current.runId, details }); return; }
    if (path.endsWith('/review') || path.endsWith('/review.json')) { json({ schemaVersion: 2, runId: current.runId, candidates: reviews }); return; }
    if (path.endsWith('/ocr') || path.endsWith('/ocr.json')) { json(ocr()); return; }
    if (path.endsWith('/scan-status.json')) { json(scanStatus()); return; }
    if (path.includes('/evidence/')) { json({ html: '<script>window.attacked=true</script>' }); return; }
    if (path.includes('/files/')) { json({ meta: { topic: 'TOPIC' }, findings: path.endsWith('/result_extra.json') ? extras : findings }); return; }
    json(current);
  });
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve)); const address = server.address(); if (!address || typeof address === 'string') throw new Error('No port'); base = `http://127.0.0.1:${address.port}`;
  browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
});
afterAll(async () => { await page?.close(); await browser?.close(); if (server) await new Promise<void>(resolve => { server.close(() => resolve()); server.closeAllConnections(); }); });
beforeEach(async () => { await page?.close(); page = await browser.newPage(); current = snapshot(); publicConfig = structuredClone(config); findings = []; extras = []; details = []; reviews = []; images = []; starts = []; requested = []; previewType = 'image/png'; invalidPng = false; downloadError = false; startError = null; });
async function open() { await page.goto(base); await page.getByLabel('진입 URL').waitFor(); }
async function start(ocrEnabled = false) { await open(); await page.getByLabel('진입 URL').fill(official.url); await page.getByLabel('외부 분석 전송 동의').check(); if (ocrEnabled) await page.getByLabel('이미지 OCR 사용').check(); await page.getByRole('button', { name: '점검 시작', exact: true }).click(); await page.getByText('실행 ID: run-1', { exact: true }).waitFor(); }
function withImageFinding() { findings = [official]; extras = [extra]; images = [image()]; current.counts.confirmedFindings = 1; current.counts.extraConfirmedFindings = 1; details = [{ findingId: official.id, candidateId: 'dom-1', decisionSource: 'clef', ruleIds: [], ai, evidence, resultFile: 'result.json', sourceType: 'dom_text', sourceIds: [], sourceTextRanges: [], observationIds: ['TRANSPARENT'] }, { findingId: extra.id, candidateId: 'image-owner', decisionSource: 'clef', ruleIds: [], ai, evidence, resultFile: 'result_extra.json', sourceType: 'image_ocr', sourceIds: ['image-1'], sourceTextRanges: [{ imageId: 'image-1', rawStart: 0, rawEnd: raw.length }], observationIds: [] }]; }

describe('V2 dashboard with authenticated mock API', () => {
  it('requires consent before start and defaults image OCR off', async () => {
    await open(); expect(await page.getByLabel('외부 분석 전송 동의').count()).toBe(1); await page.getByLabel('진입 URL').fill(official.url);
    expect(await page.getByRole('button', { name: '점검 시작', exact: true }).isDisabled()).toBe(true);
    await page.locator('form').evaluate(form => form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true })));
    expect(starts).toEqual([]); expect(await page.getByLabel('이미지 OCR 사용').isChecked()).toBe(false);
    await page.getByLabel('외부 분석 전송 동의').check(); await page.getByRole('button', { name: '점검 시작', exact: true }).click(); await page.getByText('실행 ID: run-1', { exact: true }).waitFor();
    expect(starts).toEqual([{ entryUrl: official.url, ocrEnabled: false, externalAnalysisConsent: true }]);
    expect(await page.getByText(/이미지 범위: 선택 제외/).count()).toBe(1);
  });
  it('blocks start when key is missing even with consent', async () => {
    publicConfig.aiConfigured = false; await page.goto(base); await page.getByText(/키 미설정/).waitFor(); await page.getByLabel('외부 분석 전송 동의').check();
    await page.locator('form').evaluate(form => form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true })));
    expect(await page.getByRole('button', { name: '점검 시작', exact: true }).isDisabled()).toBe(true); expect(starts).toEqual([]);
    expect(await page.getByText(/로컬 판정|AI 분석 사용/).count()).toBe(0);
  });
  it('shows transfer scope, request and image limits and one-frame exclusions', async () => {
    await start(true); expect(starts[0]).toEqual({ entryUrl: official.url, ocrEnabled: true, externalAnalysisConsent: true });
    expect(await page.getByText(/PNG.*OpenRouter/).count()).toBeGreaterThan(0);
    expect(await page.getByText(/OCR 최대 100.*CLEF 최대 1000/).count()).toBe(1);
    expect(await page.getByText(/8388608.*16000000/).count()).toBe(1);
    expect(await page.getByText(/첫 프레임.*캔버스.*영상/).count()).toBeGreaterThan(0);
  });
  it.each(['running', 'stopping', 'completed', 'partial', 'cancelled', 'failed'] as const)('distinguishes %s and zero detections from site safety', async state => {
    current = snapshot(state); await start(); await page.locator(`.badge.${state}`).waitFor(); await page.getByText('공식 탐지 0건', { exact: true }).waitFor();
    expect(await page.getByText('추가 이미지 탐지 0건', { exact: true }).count()).toBe(1);
    expect(await page.getByText(/불법광고 없음|안전한 사이트/).count()).toBe(0);
    expect(await page.getByRole('button', { name: '점검 중지', exact: true }).isDisabled()).toBe(state !== 'running');
    if (!['running', 'stopping'].includes(state)) await page.getByText('미방문: https://public.example/pending', { exact: true }).waitFor();
  });
  it('renders official/image evidence separately, authenticates PNG preview, and never executes XSS or original SVG', async () => {
    current = snapshot('partial'); withImageFinding(); reviews = [{ candidateId: 'review-1', url: 'javascript:window.attacked=true', location: '#review', evidenceText: '<script>window.attacked=true</script>', techniques: [], reason: 'OCR_NO_TEXT', ai: null, evidence, sourceType: 'image_ocr', sourceIds: ['image-1'], sourceTextRanges: [] }]; await start(true);
    await page.getByText('추가 이미지 탐지 1건', { exact: true }).waitFor(); expect(await page.locator('tbody tr').count()).toBe(2);
    expect(await page.locator('a[href^="javascript:"], iframe, img').count()).toBe(0);
    await page.getByRole('button', { name: '이미지 상세 image-1', exact: true }).first().click(); await page.getByRole('dialog').waitFor(); await page.getByRole('dialog').locator('img').waitFor();
    expect(requested).toContain('/api/runs/run-1/images/png-1'); expect(requested.some(path => path.includes('original-1') || path.includes('assets.example'))).toBe(false);
    expect(await page.getByRole('dialog').locator('img').getAttribute('src')).toMatch(/^blob:/);
    expect(await page.getByRole('dialog').textContent()).toContain('a'.repeat(64)); expect(await page.getByRole('dialog').textContent()).toContain('b'.repeat(64));
    expect(await page.getByRole('dialog').textContent()).toContain(raw); expect(await page.getByRole('dialog').textContent()).toContain('confidence: 미제공');
    expect(await page.getByRole('dialog').textContent()).toContain('TRANSPARENT'); expect(await page.getByRole('dialog').textContent()).toContain('positive');
    expect(await page.getByRole('dialog').textContent()).toContain('https://owned.example/image-link');
    expect(await page.getByRole('dialog').textContent()).toContain('<img src=x onerror=window.attacked=true>');
    expect(await page.locator('a[href^="https://owned.example"]').count()).toBe(0);
    await page.getByRole('button', { name: '닫기', exact: true }).click(); await page.getByRole('button', { name: '캡처 근거 보기 snapshot-1', exact: true }).first().click(); await page.getByRole('dialog').waitFor(); expect(await page.getByRole('dialog').textContent()).toContain('<script>window.attacked=true</script>'); expect(await page.evaluate(() => 'attacked' in window)).toBe(false);
  });
  it('rejects a non-PNG response for an authenticated preview', async () => {
    current = snapshot('completed'); images = [image()]; previewType = 'image/svg+xml'; await start(true); await page.getByRole('button', { name: '이미지 상세 image-1', exact: true }).click(); await page.getByRole('alert').filter({ hasText: 'PNG' }).waitFor(); expect(await page.locator('img').count()).toBe(0); expect(await page.evaluate(() => 'attacked' in window)).toBe(false);
  });
  it('rejects SVG bytes mislabeled as PNG rather than displaying the asset', async () => {
    current = snapshot('completed'); images = [image()]; invalidPng = true; await start(true);
    await page.getByRole('button', { name: '이미지 상세 image-1', exact: true }).click();
    await page.getByRole('alert').filter({ hasText: 'PNG' }).waitFor({ timeout: 2000 });
    expect(await page.locator('img').count()).toBe(0);
  });
  it.each([{ status: 'not_selected', extractionStatus: null, text: null, reasonCode: 'OCR_NOT_SELECTED', label: '선택 제외' }, { status: 'completed', extractionStatus: 'no_text', text: '', reasonCode: null, label: '문자 없음 · 검토' }, { status: 'completed', extractionStatus: 'unreadable', text: '', reasonCode: 'OCR_UNREADABLE', label: '읽기 불가 · 미완료' }, { status: 'error', extractionStatus: null, text: null, reasonCode: 'OCR_HTTP_ERROR', label: 'OCR/이미지 실패' }, { status: 'not_started', extractionStatus: null, text: null, reasonCode: 'RESOURCE_LIMIT', label: '미처리' }] as const)('distinguishes image $label', async item => {
    current = snapshot('partial'); const { label: _label, ...wire } = item; images = [image({ ...wire, ...(item.status === 'not_selected' || item.status === 'not_started' ? { original: null, input: null, capturedAt: null, attemptCount: 0 } : {}), ...(item.status === 'not_selected' ? { model: null } : {}) })]; await start(item.status !== 'not_selected'); await page.getByText(item.label, { exact: true }).waitFor(); expect(await page.getByText(/불법광고 없음/).count()).toBe(0);
  });
  it('discards an initial artifact batch arriving after a newer terminal refresh', async () => {
    withImageFinding(); let releaseOld: (() => Promise<void>) | undefined; let intercepted = false;
    await page.route('**/api/runs/run-1/finding-details', async route => {
      if (intercepted) { await route.continue(); return; } intercepted = true;
      const captured = structuredClone({ schemaVersion: 2, runId: current.runId, details });
      releaseOld = () => route.fulfill({ json: captured });
    });
    await start(true); await page.waitForFunction(() => document.querySelector('.badge.running'));
    current.state = 'cancelled'; current.finishedAt = '2026-10-04T01:00:03Z';
    details = details.map(item => ({ ...item, observationIds: ['terminal-observation'] }));
    await page.getByText('DOM 관측: terminal-observation', { exact: true }).first().waitFor();
    expect(releaseOld).toBeDefined(); await releaseOld!();
    // All queued response tasks must settle before inspecting the displayed final artifacts.
    await page.waitForFunction(() => document.querySelectorAll('tbody tr').length === 2);
    await new Promise(resolve => setTimeout(resolve, 100));
    expect(await page.getByText('DOM 관측: terminal-observation', { exact: true }).count()).toBe(2);
  });
  it('downloads all six registered JSON files and reports failures', async () => {
    current = snapshot('completed'); await start(); for (const file of ['result.json', 'result_extra.json', 'scan-status.json', 'review.json', 'finding-details.json', 'ocr.json']) { const pending = page.waitForEvent('download'); await page.getByRole('button', { name: `${file} 다운로드`, exact: true }).click(); expect((await pending).suggestedFilename()).toBe(`run-1-${file}`); }
    downloadError = true; await page.getByRole('button', { name: 'result_extra.json 다운로드', exact: true }).click(); await page.getByRole('alert').filter({ hasText: '파일 기록 실패' }).waitFor();
  });
  it.each(['INVALID_CONFIG', 'ACTIVE_RUN'])('surfaces server %s rejection', async code => { startError = code; await open(); await page.getByLabel('진입 URL').fill(official.url); await page.getByLabel('외부 분석 전송 동의').check(); await page.getByRole('button', { name: '점검 시작', exact: true }).click(); await page.getByRole('alert').filter({ hasText: code }).waitFor(); expect(await page.getByText(/실행 ID:/).count()).toBe(0); });
});
