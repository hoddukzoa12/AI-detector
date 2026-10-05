/** Windows-only packaged runtime check. Synthetic inference; never reads an API secret. */
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import { release, platform } from 'node:os';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { _electron } from 'playwright';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const packageRoot = resolve(root, 'release/Inspektor-win32-x64');
const proof = resolve(root, 'release/windows-ci');
const executable = resolve(packageRoot, 'Inspektor.exe');
const bundledNode = resolve(packageRoot, 'resources/runtime/node.exe');
const chromium = resolve(packageRoot, 'resources/browser/chrome-win64/chrome.exe');
const bundledSelfTest = resolve(packageRoot, 'resources/app/dist/self-test.mjs');
// Only public, synthetic evidence is uploaded. No real key or ambient Node preload is used.
const env = Object.fromEntries(Object.entries(process.env).filter(([key, value]) => value !== undefined &&
  !['OPENROUTER_API_KEY', 'NODE_OPTIONS', 'ELECTRON_RUN_AS_NODE'].includes(key)));
env.OPENROUTER_API_KEY = '';
const report = {
  schemaVersion: 1, assertions: 'RUNNING', platform: platform(), osRelease: release(),
  runnerImage: process.env.ImageOS ?? null, sourceCommit: process.env.GITHUB_SHA ?? null,
  inferenceTransport: 'EXPLICIT_SYNTHETIC_HTTP_MOCK', actualOcrInference: 'NOT_RUN',
  actualClefInference: 'NOT_RUN', actualWindows11: 'NOT_RUN', targetPc30MinuteRun: 'NOT_RUN',
  repositoryLicense: 'UNRESOLVED', checks: [],
};
await mkdir(proof, { recursive: true });
const save = () => writeFile(resolve(proof, 'windows-runner-report.json'), JSON.stringify(report, null, 2) + '\n');

async function runOwned(command, args, extraEnv, name) {
  const child = spawn(command, args, { cwd: packageRoot, env: { ...env, ...extraEnv }, stdio: ['ignore', 'pipe', 'pipe'] });
  let stdout = '', stderr = '';
  child.stdout.on('data', value => { stdout += value.toString(); });
  child.stderr.on('data', value => { stderr += value.toString(); });
  let exitCode;
  try {
    exitCode = await new Promise((res, rej) => {
      const timer = setTimeout(() => { child.kill('SIGKILL'); rej(new Error(`${name}: timeout`)); }, 180000);
      child.once('error', error => { clearTimeout(timer); rej(error); });
      child.once('exit', (code, signal) => { clearTimeout(timer); res(signal ? null : code); });
    });
  } catch (error) {
    report.checks.push({ name, exitCode: null, error: error.message });
    await save(); throw error;
  } finally {
    await writeFile(resolve(proof, `${name}.log`), stdout + stderr);
  }
  report.checks.push({ name, exitCode }); await save();
  assert.equal(exitCode, 0, `${name}: nonzero exit; inspect synthetic log`);
  return stdout.trim();
}
async function inspectSelfTest(directory, name) {
  const reports = [];
  async function walk(path) {
    for (const entry of await readdir(path, { withFileTypes: true })) {
      const full = resolve(path, entry.name);
      if (entry.isDirectory()) await walk(full);
      else if (entry.name === 'self-test-report.json') reports.push(JSON.parse(await readFile(full, 'utf8')));
    }
  }
  await walk(directory); assert.equal(reports.length, 1, `${name}: one actual self-test report`);
  const actual = reports[0];
  assert.equal(actual.assertions, 'PASS'); assert.equal(actual.platform, 'win32'); assert.equal(actual.mode, 'desktop');
  assert.equal(actual.inferenceTransport, 'EXPLICIT_SYNTHETIC_HTTP_MOCK');
  assert.deepEqual(actual.runs.map(run => run.findings), [25, 0, 1, 5]);
  assert.equal(actual.runs[2].extraFindings, 20); assert.equal(actual.runs[2].imageOccurrences, 39);
  assert.equal(actual.menuTitleNegatives, 22);
  report.checks.push({ name: `${name}-evidence`, assertions: 'PASS', nodeVersion: actual.nodeVersion,
    chromiumVersion: actual.chromiumVersion, officialFindings: 25, imageOwners: 20, imageOccurrences: 39,
    menuTitleNegatives: 22, source: `${name}-output` }); await save();
}
let desktop;
try {
  assert.equal(process.platform, 'win32', 'Must actually execute on Windows');
  await save();
  const version = await runOwned(bundledNode, ['--version'], {}, 'bundled-node-version');
  assert.equal(version, 'v24.19.0');
  const cliOutput = resolve(proof, 'bundled-node-output');
  await runOwned(bundledNode, [bundledSelfTest, '--mode', 'desktop', '--exe-path', executable,
    '--chromium-path', chromium, '--output-dir', cliOutput], {}, 'bundled-node-self-test');
  await inspectSelfTest(cliOutput, 'bundled-node');
  const electronOutput = resolve(proof, 'electron-output');
  await runOwned(executable, ['--self-test'], { INSPECTOR_OUTPUT_DIR: electronOutput }, 'electron-self-test');
  await inspectSelfTest(electronOutput, 'electron');
  desktop = await _electron.launch({ executablePath: executable, cwd: packageRoot, env: {
    ...env, INSPECTOR_OUTPUT_DIR: resolve(proof, 'gui-output'),
  }, timeout: 60000 });
  const page = await desktop.firstWindow();
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.locator('#entry-url').waitFor({ state: 'visible' });
  assert.equal(await page.locator('#ocr-enabled').isChecked(), false);
  assert.equal(await page.locator('#external-consent').isChecked(), false);
  assert.equal(await page.getByRole('button', { name: '점검 시작', exact: true }).isDisabled(), true);
  const config = await page.evaluate(async () => {
    const token = globalThis.__INSPECTOR_BOOTSTRAP__.sessionToken;
    const response = await globalThis.fetch('/api/config', { headers: { Authorization: `Bearer ${token}` } });
    if (response.status !== 200) throw new Error('GUI config request failed');
    const value = await response.json();
    return { aiConfigured: value.aiConfigured, aiRequired: value.aiRequired, model: value.model, ocrModel: value.ocrModel };
  });
  assert.deepEqual(config, { aiConfigured: false, aiRequired: true, model: 'cloudflare/clef', ocrModel: 'google/gemini-3.8-flash' });
  const security = await desktop.evaluate(({ BrowserWindow, app }) => {
    const preferences = BrowserWindow.getAllWindows()[0].webContents.getLastWebPreferences();
    return { sandbox: preferences.sandbox, contextIsolation: preferences.contextIsolation,
      nodeIntegration: preferences.nodeIntegration, hardwareAcceleration: app.isHardwareAccelerationEnabled() };
  });
  assert.deepEqual(security, { sandbox: true, contextIsolation: true, nodeIntegration: false, hardwareAcceleration: false });
  assert.deepEqual(errors, []);
  await page.screenshot({ path: resolve(proof, 'windows-gui.png'), fullPage: true });
  const processHandle = desktop.process();
  const exit = new Promise((res, rej) => {
    const timer = setTimeout(() => rej(new Error('GUI did not shut down')), 15000);
    processHandle.once('exit', (code, signal) => { clearTimeout(timer); res({ code, signal }); });
  });
  await desktop.evaluate(({ BrowserWindow }) => { setTimeout(() => BrowserWindow.getAllWindows()[0].close(), 100); });
  const closed = await exit; assert.equal(closed.code, 0); assert.equal(closed.signal, null);
  report.checks.push({ name: 'real-exe-gui', assertions: 'PASS', config, security, closeExitCode: closed.code });
  report.assertions = 'PASS'; await save();
  console.log('Actual Windows runner: bundled Node/Chromium, EXE self-test, GUI and graceful close PASS (synthetic inference; Windows 11 NOT_RUN).');
} catch (error) {
  report.assertions = 'FAIL'; report.error = error instanceof Error ? error.message : 'Windows assertion failed';
  await save(); throw error;
} finally {
  if (desktop) await desktop.close().catch(() => {});
}
