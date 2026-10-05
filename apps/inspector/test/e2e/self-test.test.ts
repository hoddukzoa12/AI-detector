import { expect, it } from 'vitest';
import { spawn } from 'node:child_process';
import { mkdtemp, mkdir, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import { chromium } from 'playwright';
import { parseSelfTestArgs } from '../../scripts/self-test.js';
import { independentOfficialResult, independentExtraResult, sha256 } from '../../scripts/verification.js';

async function cli(args: string[]) {
  return new Promise<{ code: number | null; stdout: string; stderr: string }>((res, rej) => {
    const env = { ...process.env }; delete env.OPENROUTER_API_KEY; delete env.INSPECTOR_OUTPUT_DIR;
    const child = spawn(process.execPath, ['dist/self-test.mjs', ...args], { env, stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '', stderr = ''; child.stdout.on('data', bytes => { stdout += bytes.toString(); }); child.stderr.on('data', bytes => { stderr += bytes.toString(); });
    child.once('error', rej); child.once('exit', code => res({ code, stdout, stderr }));
  });
}
it('shipped self-test rejects unknown, duplicate, missing flags and incomplete desktop configuration', async () => {
  for (const args of [['--unknown'], ['--mode', 'npm', '--mode', 'docker'], ['--mode'], ['--mode', 'desktop'], ['--mode', 'invalid'], ['--mode', 'npm', '--exe-path', 'x']]) {
    expect(() => parseSelfTestArgs(args)).toThrow(); const result = await cli(args); expect(result.code).toBe(1);
    expect(result.stderr).toContain('Self-test FAIL'); expect(result.stderr).not.toContain('MODULE_NOT_FOUND');
  }
});
it('two real desktop-mode CLI runs resolve exe-adjacent .env and never overwrite existing results/latest/runs', async () => {
  const root = await mkdtemp(resolve(tmpdir(), 'inspector-self-test-'));
  try {
    const exe = resolve(root, 'Inspektor.exe'), output = resolve(root, 'resolved-output');
    await writeFile(exe, 'Linux-only executable reference, not a Windows execution proof');
    await writeFile(resolve(root, '.env'), 'INSPECTOR_OUTPUT_DIR=resolved-output\nOPENROUTER_API_KEY=test\n');
    await mkdir(resolve(output, 'runs', 'existing'), { recursive: true });
    const originals = ['result.json', 'latest.json', 'runs/existing/result.json'];
    for (const path of originals) await writeFile(resolve(output, path), `keep:${path}`);
    const hashes = await Promise.all(originals.map(async path => sha256(await readFile(resolve(output, path)))));
    for (let i = 0; i < 2; i++) {
      const result = await cli(['--mode', 'desktop', '--exe-path', exe, '--chromium-path', chromium.executablePath()]); expect(result.code).toBe(0); expect(result.stdout).toContain('Self-test PASS');
    }
    const dirs = await readdir(resolve(output, 'self-test')); expect(dirs.length).toBe(2);
    for (const dir of dirs) {
      const isolated = resolve(output, 'self-test', dir); const report = JSON.parse(await readFile(resolve(isolated, 'self-test-report.json'), 'utf8'));
      expect(report.mode).toBe('desktop'); expect(report.platform).toBe(process.platform); expect(report.outputRoot).toBe(output); expect(report.executableReference).toBe(exe);
      expect(report.chromiumPath).toBe(chromium.executablePath()); expect(report.actualWindowsGuiExecution).toBe('NOT_RUN'); expect(report.schemaVersion).toBe(2); expect(report.aiEnabled).toBe(true); expect(report.inferenceTransport).toBe('EXPLICIT_SYNTHETIC_HTTP_MOCK'); expect(report.transportCalls.ocr).toBeGreaterThan(0); expect(report.transportCalls.clef).toBeGreaterThan(0); expect(report.actualOcrInference).toBe('NOT_RUN'); expect(report.actualClefInference).toBe('NOT_RUN');
      expect(report.runs[0].state).toBe('partial'); expect(report.runs[0].findings).toBe(25); expect(report.runs[1].state).toBe('completed'); expect(report.runs[1].findings).toBe(0);
      const bytes = await readFile(resolve(isolated, 'runs', report.runs[0].runId, 'result.json')); independentOfficialResult(bytes); expect(sha256(bytes)).toBe(report.runs[0].resultSha256);
      const emptyBytes = await readFile(resolve(isolated, 'runs', report.runs[1].runId, 'result.json')); expect(independentOfficialResult(emptyBytes).findings).toEqual([]); expect(sha256(emptyBytes)).toBe(report.runs[1].resultSha256);
      expect(report.runs).toHaveLength(4); expect(report.runs[2]).toMatchObject({state:'partial', findings:1, extraFindings:20, imageOccurrences:39}); expect(report.runs[3].findings).toBe(5); expect(report.menuTitleNegatives).toBe(22);
      for (const run of report.runs) {
        const archive = resolve(isolated, 'runs', run.runId); const manifest = JSON.parse(await readFile(resolve(archive, 'manifest.json'), 'utf8'));
        for (const [name, hash] of Object.entries(manifest.files)) expect(sha256(await readFile(resolve(archive, name)))).toBe(hash);
        independentExtraResult(await readFile(resolve(archive, 'result_extra.json')));
        for (const name of ['scan-status.json','review.json','finding-details.json','ocr.json']) expect(JSON.parse(await readFile(resolve(archive,name),'utf8')).schemaVersion).toBe(2);
      }
      expect(JSON.stringify(report)).not.toContain('synthetic-deployment-http-placeholder');
    }
    expect(await Promise.all(originals.map(async path => sha256(await readFile(resolve(output, path)))))).toEqual(hashes);
    const failed = await cli(['--mode', 'npm', '--chromium-path', resolve(root, 'missing-chromium'), '--output-dir', output]); expect(failed.code).toBe(1); expect(failed.stderr).toContain('Self-test FAIL');
  } finally { await rm(root, { recursive: true, force: true }); }
}, 120000);
it('independent validator rejects malformed official schemas, techniques, duplicate identity, invalid UTF-8 and BOM', () => {
  const valid = { meta: { topic: 'TOPIC', entry_url: 'http://example.test/', started_at: '2026-10-04T01:00:00Z', finished_at: '2026-10-04T01:00:01Z', elapsed_sec: 1 }, findings: [{ id: 'one', url: 'http://example.test/', is_violation: true, location: '#ad', evidence_text: 'raw', technique: 'TRANSPARENT' }] };
  const encoded = (value: unknown) => Buffer.from(JSON.stringify(value)); expect(independentOfficialResult(encoded(valid)).findings.length).toBe(1); expect(independentOfficialResult(encoded({ ...valid, meta: { ...valid.meta, elapsed_sec: .75 }, findings: [{ ...valid.findings[0], evidence_text: '' }] })).findings[0].evidence_text).toBe('');
  const bads: unknown[] = [null, [], { ...valid, status: 'completed' }, { ...valid, findings: {} }, { ...valid, meta: { ...valid.meta, topic: 'wrong' } }, { ...valid, meta: { ...valid.meta, elapsed_sec: -1 } }, { ...valid, meta: { ...valid.meta, entry_url: 'file:///private' } }, { ...valid, meta: { ...valid.meta, finished_at: 'not-a-date' } }, { ...valid, meta: { ...valid.meta, started_at: '2026-02-30T01:00:00Z' } }];
  for (const key of ['id', 'url', 'is_violation', 'location', 'evidence_text', 'technique']) { const finding: Record<string, unknown> = { ...valid.findings[0] }; delete finding[key]; bads.push({ ...valid, findings: [finding] }); }
  for (const patch of [{ technique: ['TRANSPARENT'] }, { technique: 'ETC' }, { is_violation: false }, { id: '' }, { url: 'file:///secret' }, { location: '' }, { evidence_text: 3 }, { normalized: 'extra' }]) bads.push({ ...valid, findings: [{ ...valid.findings[0], ...patch }] });
  bads.push({ ...valid, findings: [valid.findings[0], { ...valid.findings[0], id: 'two' }] }, { ...valid, findings: [valid.findings[0], { ...valid.findings[0], location: '#different' }] });
  for (const bad of bads) expect(() => independentOfficialResult(encoded(bad))).toThrow();
  expect(() => independentOfficialResult(Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), encoded(valid)]))).toThrow(); expect(() => independentOfficialResult(Buffer.from([0xff]))).toThrow();
});
