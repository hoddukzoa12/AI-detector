import { spawn, execFile, type ChildProcess } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';
import { promisify } from 'node:util';
import { expect, it } from 'vitest';
import { chromium, type Browser } from 'playwright';
import type { OfficialResult } from '../../src/core/types.js';
import type { ExtraResult, OcrFile, RunSnapshotV2, ScanStatusFileV2 } from '../../src/core/v2.js';
import { findingTruth } from '../fixtures/truth.js';
import { startFixtureSite } from '../fixtures/site.js';

const execute = promisify(execFile);
async function processGroup(pid: number): Promise<number[]> {
  if (process.platform === 'win32') return [];
  const { stdout } = await execute('ps', ['-eo', 'pid=,pgid=']);
  return stdout.split('\n').flatMap(line => {
    const [candidate, group] = line.trim().split(/\s+/).map(Number);
    return group === pid ? [candidate] : [];
  });
}
async function terminal(api: (path: string) => Promise<Response>, id: string, condition: (run: RunSnapshotV2) => boolean | Promise<boolean>, limit: number) {
  const deadline = Date.now() + limit;
  let latest: RunSnapshotV2 | undefined;
  while (Date.now() < deadline) {
    latest = await (await api(`/api/runs/${id}`)).json() as RunSnapshotV2;
    if (await condition(latest)) return latest;
    await delay(20);
  }
  throw new Error('실행 상태 대기 실패: ' + JSON.stringify(latest));
}
async function exited(child: ChildProcess, limit: number): Promise<boolean> {
  if (child.exitCode !== null || child.signalCode !== null) return true;
  return Promise.race([new Promise<true>(resolve => child.once('exit', () => resolve(true))), delay(limit).then(() => false)]);
}

async function assertProductionCancellation(): Promise<void> {
  const site = await startFixtureSite();
  const output = await mkdtemp(resolve(tmpdir(), 'crawler-production-cancel-'));
  const auditPath = resolve(output, 'mock-clef-audit.jsonl');
  const oraclePath = resolve(output, 'mock-clef-oracle.json');
  const syntheticKey = 'fixture-only-clef-production-cancel';
  interface Audit { event: 'started' | 'settled'; delayed: boolean; choice: 'illegal_ad' | 'non_ad'; settledAt?: number }
  const audit = async (): Promise<Audit[]> => (await readFile(auditPath, 'utf8')).trim().split('\n').filter(Boolean).map(line => JSON.parse(line) as Audit);
  let child: ChildProcess | undefined;
  let ui: Browser | undefined;
  let diagnostic = '';
  try {
    await writeFile(auditPath, '', { mode: 0o600, flag: 'wx' });
    await writeFile(oraclePath, JSON.stringify({ positiveTexts: findingTruth.map(item => item.rawEvidence),
      immediateTexts: findingTruth.filter(item => item.pagePath === '/cases/types').map(item => item.rawEvidence), auditPath }), { mode: 0o600, flag: 'wx' });

    const ready = new Promise<string>((resolveReady, reject) => {
      child = spawn(process.execPath, ['--import', fileURLToPath(new URL('./production-cancellation-clef-preload.mjs', import.meta.url)), 'dist/main.mjs'], { detached: process.platform !== 'win32',
        env: { ...process.env, INSPECTOR_RUNTIME: 'npm', INSPECTOR_PORT: '0', INSPECTOR_HOST: '127.0.0.1',
          INSPECTOR_OUTPUT_DIR: output, INSPECTOR_CHROMIUM_PATH: chromium.executablePath(), OPENROUTER_API_KEY: syntheticKey, INSPECTOR_TEST_CLEF_ORACLE: oraclePath },
        stdio: ['ignore', 'pipe', 'pipe'] });
      let logged = '';
      const timer = setTimeout(() => reject(new Error('배포 서버 시작 실패')), 5000);
      child.once('error', error => { clearTimeout(timer); reject(error); });
      child.once('exit', code => { clearTimeout(timer); reject(new Error('배포 서버 종료: ' + code)); });
      child.stdout!.on('data', chunk => { logged += String(chunk); const address = logged.match(/http:\/\/127\.0\.0\.1:\d+/); if (address) { clearTimeout(timer); resolveReady(address[0]); } });
      child.stderr!.on('data', chunk => { diagnostic += String(chunk); });
    });
    const origin = await ready;
    ui = await chromium.launch({ headless: true }); const page = await ui.newPage();
    await page.goto(origin);
    expect(await page.locator('#ocr-enabled').isChecked()).toBe(false);
    await page.locator('#external-consent').check();
    await page.waitForFunction(() => !(document.querySelector('[data-action="start"]') as HTMLButtonElement)?.disabled);
    const token = await page.evaluate(() => (window as unknown as { __INSPECTOR_BOOTSTRAP__: { sessionToken: string } }).__INSPECTOR_BOOTSTRAP__.sessionToken);
    const api = (path: string) => fetch(origin + path, { headers: { Authorization: `Bearer ${token}`, Origin: origin } });
    await page.locator('#entry-url').fill(site.urls.entry);
    const started = page.waitForResponse(response => response.url().endsWith('/api/runs') && response.request().method() === 'POST');
    await page.getByRole('button', { name: '점검 시작', exact: true }).click();
    const startResponse = await started;
    expect(startResponse.status()).toBe(202);
    expect(startResponse.request().postDataJSON()).toEqual({ entryUrl: site.urls.entry, ocrEnabled: false, externalAnalysisConsent: true });
    const initial = await startResponse.json() as RunSnapshotV2;
    expect(initial).toMatchObject({ aiEnabled: true, model: 'cloudflare/clef', ocrEnabled: false, ocrModel: null, externalAnalysisConsent: true });
    const id = initial.runId;
    const before = await terminal(api, id, async run => run.counts.confirmedFindings === 17 && run.counts.pendingPages > 0 && (await audit()).some(record => record.event === 'started' && record.delayed), 10000);
    expect(before.counts.confirmedFindings).toBe(17);
    const cancelRequestedAt = Date.now();
    const cancelled = page.waitForResponse(response => response.url().endsWith(`/api/runs/${id}/cancel`));
    await page.getByRole('button', { name: '점검 중지', exact: true }).click();
    expect((await cancelled).status()).toBe(202);
    const run = await terminal(api, id, run => ['completed', 'partial', 'cancelled', 'failed'].includes(run.state), 5000);
    expect(run.state).toBe('cancelled'); expect(run.counts.confirmedFindings).toBe(17);
    expect(Date.now() - cancelRequestedAt).toBeLessThan(5000);
    expect(run.activeUrls).toEqual([]);
    expect(run.ocrEnabled).toBe(false); expect(run.requestCounts.ocr).toBe(0); expect(run.requestCounts.clef).toBeGreaterThan(0);
    expect(run.counts.extraConfirmedFindings).toBe(0);
    const names = ['result.json', 'result_extra.json', 'review.json', 'finding-details.json', 'ocr.json', 'scan-status.json'] as const;
    const files = new Map<string, Buffer>();
    const manifest = JSON.parse(await readFile(resolve(output, 'runs', id, 'manifest.json'), 'utf8')) as { schemaVersion: number; runId: string; files: Record<string, string>; evidence: Record<string, string> };
    expect(manifest.schemaVersion).toBe(2); expect(manifest.runId).toBe(id);
    for (const name of names) {
      const response = await api(`/api/runs/${id}/files/${name}`); expect(response.status).toBe(200);
      const bytes = Buffer.from(await response.arrayBuffer()); files.set(name, bytes);
      expect(await readFile(resolve(output, 'runs', id, name))).toEqual(bytes);
      expect(createHash('sha256').update(bytes).digest('hex')).toBe(manifest.files[name]);
      expect(bytes.includes(Buffer.from(syntheticKey))).toBe(false);
      expect(bytes.subarray(0, 3).equals(Buffer.from([239, 187, 191]))).toBe(false);
    }
    for (const [snapshotId, hash] of Object.entries(manifest.evidence)) {
      const response = await api(`/api/runs/${id}/evidence/${snapshotId}`); expect(response.status).toBe(200);
      const bytes = Buffer.from(await response.arrayBuffer());
      expect(await readFile(resolve(output, 'runs', id, 'evidence', snapshotId + '.json'))).toEqual(bytes);
      expect(createHash('sha256').update(bytes).digest('hex')).toBe(hash);
    }
    const result = JSON.parse(files.get('result.json')!.toString()) as OfficialResult;
    expect(result.findings).toHaveLength(17);
    for (const finding of result.findings) expect(site.expectedFindings.some(truth => truth.url === finding.url && truth.location === finding.location && truth.rawEvidence === finding.evidence_text && truth.technique === finding.technique)).toBe(true);
    const extra = JSON.parse(files.get('result_extra.json')!.toString()) as ExtraResult;
    expect(extra.findings).toEqual([]); expect(extra.meta).toEqual(result.meta);
    const status = JSON.parse(files.get('scan-status.json')!.toString()) as ScanStatusFileV2;
    expect(status.schemaVersion).toBe(2); expect(status.resultSaved).toBe(true); expect(status.extraResultSaved).toBe(true); expect(status.run).toEqual(run);
    expect(status.files.resultSha256).toBe(manifest.files['result.json']); expect(status.files.extraResultSha256).toBe(manifest.files['result_extra.json']);
    const ocr = JSON.parse(files.get('ocr.json')!.toString()) as OcrFile;
    expect(ocr).toEqual({ schemaVersion: 2, runId: id, enabled: false, model: null, images: [] });
    expect(status.scope.unvisitedUrls.length).toBeGreaterThan(0);
    expect(run.counts.pendingPages).toBe(status.scope.unvisitedUrls.length);
    const lateDeadline = Date.now() + 3000;
    while (!(await audit()).some(record => record.event === 'settled' && record.delayed) && Date.now() < lateDeadline) await delay(20);
    expect((await audit()).some(record => record.event === 'settled' && record.delayed && record.choice === 'illegal_ad' && record.settledAt! > Date.parse(run.finishedAt!))).toBe(true);
    expect((await audit()).filter(record => record.event === 'started')).toHaveLength(run.requestCounts.clef);
    expect(await (await api(`/api/runs/${id}`)).json()).toEqual(run);
    for (const name of names) {
      expect(Buffer.from(await (await api(`/api/runs/${id}/files/${name}`)).arrayBuffer())).toEqual(files.get(name));
      expect(await readFile(resolve(output, 'runs', id, name))).toEqual(files.get(name));
    }
    if (process.platform !== 'win32') expect(await processGroup(child!.pid!)).toEqual([child!.pid!]);
    child!.kill('SIGTERM'); expect(await exited(child!, 5000)).toBe(true);
    expect(child!.exitCode).toBe(0);
    if (process.platform !== 'win32') expect(await processGroup(child!.pid!)).toEqual([]);
    expect(site.requests.some(request => !['GET', 'HEAD'].includes(request.method))).toBe(false);
    expect(site.requests.some(request => request.origin === 'external' && request.path === '/outside')).toBe(false);
  } catch (error) {
    throw new Error((error instanceof Error ? error.message : String(error)) + '\n배포 서버 오류:\n' + diagnostic, { cause: error });
  } finally {
    await ui?.close().catch(() => {});
    if (child && child.exitCode === null && child.signalCode === null) {
      child.kill('SIGTERM');
      if (!await exited(child, 1000)) {
        if (process.platform === 'win32') child.kill('SIGKILL');
        else { try { process.kill(-child.pid!, 'SIGKILL'); } catch { child.kill('SIGKILL'); } }
        await exited(child, 1000);
      }
    }
    await site.stop(); await rm(output, { recursive: true, force: true });
  }
}

it('단독 배포 서버 취소(모의 CLEF)는 확정 17건·저장 해시를 보존하고 Chromium과 서버를 정상 종료한다', assertProductionCancellation, 25000);
it('동시 배포 서버 두 개의 취소(모의 CLEF)도 서로의 결과·해시·프로세스 정리를 보존한다', async () => {
  const results = await Promise.allSettled([assertProductionCancellation(), assertProductionCancellation()]);
  for (const result of results) if (result.status === 'rejected') throw result.reason;
}, 25000);
