import { cp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { dirname, resolve, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { packager } from '@electron/packager';
import { OCR_FIXTURE_ASSETS } from './ocr-fixture-assets.mjs';
import { extractChromiumCredits, inventory, sha256, verifyPackage, verifyFixtureAssets } from './packaging-lib.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const release = resolve(root, 'release');
const cache = resolve(release, 'cache');
const stage = resolve(release, '.stage-app');
const versions = { electron: '44.5.1', node: '24.19.0', playwright: '1.63.0', chromium: '153.0.8010.12', chromiumRevision: '1243' };
const chromiumSha256 = '415968b02065d4a9e2c10b85f0ae9f489b8fba500e94d9d0a7b7c4852a7234c1';
const npm = process.platform === 'win32' ? 'npm.cmd' : 'npm';
function run(command, args, cwd = root) {
  return new Promise((res, rej) => {
    const child = spawn(command, args, { cwd, stdio: 'inherit', env: { ...process.env, PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD: '1', ELECTRON_SKIP_BINARY_DOWNLOAD: '1' } });
    child.once('error', rej);
    child.once('exit', code => code === 0 ? res() : rej(new Error(`${command} failed (${code})`)));
  });
}
async function download(url, filename) {
  const path = resolve(cache, filename);
  await run('curl', ['--fail', '--location', '--retry', '3', '--silent', '--show-error', url, '--output', `${path}.partial`]);
  await cp(`${path}.partial`, path); await rm(`${path}.partial`);
  return path;
}
async function cached(url, filename, expected) {
  const path = resolve(cache, filename);
  const valid = await sha256(path).then(hash => hash === expected, () => false);
  if (!valid) await download(url, filename);
  if (await sha256(path) !== expected) throw new Error(`Download checksum mismatch: ${filename}`);
  return path;
}
async function officialArtifact(url, filename, checksumUrl, checksumName) {
  const sums = await download(checksumUrl, checksumName);
  const line = (await readFile(sums, 'utf8')).split(/\r?\n/).find(line => line.trim().split(/\s+/)[1]?.replace(/^\*/, '') === filename);
  if (!line || !/^[0-9a-f]{64}\s/.test(line)) throw new Error(`Official checksum unavailable: ${filename}`);
  const expected = line.slice(0, 64);
  return { path: await cached(url, filename, expected), url, checksumUrl, sha256: expected, hashAuthority: 'official HTTPS SHASUMS256.txt (signature not independently verified)' };
}
async function thirdPartyNotices(directory) {
  const notices = [];
  for (const item of await inventory(directory)) {
    if (/(^|\/)(LICENSE(?:[._-].*)?|LICENCE(?:[._-].*)?|NOTICE(?:[._-].*)?|COPYING(?:[._-].*)?|COPYRIGHT(?:[._-].*)?)$/i.test(item.path)) notices.push(item);
  }
  for (const name of ['playwright', 'playwright-core', 'dotenv', '@huggingface/tokenizers']) {
    if (!notices.some(item => item.path.startsWith(`${name}/`))) throw new Error(`Production dependency license missing: ${name}`);
  }
  return notices;
}
await mkdir(cache, { recursive: true });
const pkg = JSON.parse(await readFile(resolve(root, 'package.json'), 'utf8'));
if (pkg.devDependencies.electron !== versions.electron || pkg.dependencies.playwright !== versions.playwright) throw new Error('Update audited runtime pins before changing dependencies');
const browsers = JSON.parse(await readFile(resolve(root, 'node_modules/playwright-core/browsers.json'), 'utf8'));
const chromium = browsers.browsers.find(item => item.name === 'chromium');
if (chromium.revision !== versions.chromiumRevision || chromium.browserVersion !== versions.chromium) throw new Error('Playwright/Chromium pins differ');
await run(npm, ['run', 'build']);
await verifyFixtureAssets(resolve(root,'dist/ocr-assets'));
for(const name of OCR_FIXTURE_ASSETS) { const source=await readFile(resolve(root,'test/fixtures/ocr-assets',name)); const built=await readFile(resolve(root,'dist/ocr-assets',name)); if(!source.equals(built))throw new Error('Built OCR fixture differs from checked-in source'); }
const electronFile = `electron-v${versions.electron}-win32-x64.zip`;
const nodeFile = `node-v${versions.node}-win-x64.zip`;
const electron = await officialArtifact(`https://github.com/electron/electron/releases/download/v${versions.electron}/${electronFile}`, electronFile,
  `https://github.com/electron/electron/releases/download/v${versions.electron}/SHASUMS256.txt`, 'electron-SHASUMS256.txt');
const node = await officialArtifact(`https://nodejs.org/dist/v${versions.node}/${nodeFile}`, nodeFile,
  `https://nodejs.org/dist/v${versions.node}/SHASUMS256.txt`, 'node-SHASUMS256.txt');
const browserUrl = `https://cdn.playwright.dev/builds/cft/${versions.chromium}/win64/chrome-win64.zip`;
const browser = await cached(browserUrl, `chrome-${versions.chromium}-win64.zip`, chromiumSha256);
const licenseUrl = `https://chromium.googlesource.com/chromium/src/+/${versions.chromium}/LICENSE?format=TEXT`;
const chromiumLicense = await download(licenseUrl, 'chromium-license.b64');

await rm(stage, { recursive: true, force: true });
await mkdir(stage, { recursive: true });
for (const name of ['package.json', 'package-lock.json']) await cp(resolve(root, name), resolve(stage, name));
await run(npm, ['ci', '--omit=dev', '--ignore-scripts', '--strict-ssl=true'], stage);
await rm(resolve(stage, 'node_modules/.bin'), { recursive: true, force: true });
// A build directory can contain stale local files: copy only audited runtime outputs.
for (const name of ['main.mjs', 'main.mjs.map', 'desktop.mjs', 'desktop.mjs.map', 'public/index.html', 'public/web.js', 'public/web.js.map', 'public/web.css',
  'self-test.mjs', 'self-test.mjs.map', ...OCR_FIXTURE_ASSETS.map(name=>'ocr-assets/'+name),
  'resources/tokenizer.json', 'resources/tokenizer_config.json', 'resources/LICENSE', 'resources/README.md', 'resources/provenance.json']) {
  const target = resolve(stage, 'dist', name);
  await mkdir(dirname(target), { recursive: true });
  await cp(resolve(root, 'dist', name), target);
}
await cp(resolve(root, 'PACKAGING.md'), resolve(stage, '사용설명서.md'));
await cp(resolve(root, 'inspector.env.example'), resolve(stage, 'inspector.env.example'));
await writeFile(resolve(stage, 'package.json'), JSON.stringify({ name: pkg.name, version: pkg.version, private: true, type: 'module', main: 'dist/desktop.mjs', dependencies: pkg.dependencies }, null, 2) + '\n');
await rm(resolve(stage, 'package-lock.json'));
await writeFile(resolve(stage, 'THIRD-PARTY-NOTICES.json'), JSON.stringify({ notes: 'License files remain at the recorded production dependency paths. Root repository license is unresolved; this inventory grants no additional license.',
  files: await thirdPartyNotices(resolve(stage, 'node_modules')) }, null, 2) + '\n');
const packages = await packager({ dir: stage, out: release, name: 'Inspektor', executableName: 'Inspektor', platform: 'win32', arch: 'x64',
  electronVersion: versions.electron, electronZipDir: cache, overwrite: true, asar: false, prune: false });
const folder = packages[0];
const resources = resolve(folder, 'resources');
await mkdir(resolve(resources, 'browser'), { recursive: true });
await run('unzip', ['-q', '-o', browser, '-d', resolve(resources, 'browser')]);
const license = Buffer.from(await readFile(chromiumLicense, 'utf8'), 'base64');
if (!license.toString('utf8').includes('Redistribution and use')) throw new Error('Unexpected Chromium LICENSE');
await writeFile(resolve(resources, 'browser/LICENSE'), license);
const pakPath = resolve(resources, 'browser/chrome-win64/resources.pak');
const credits = extractChromiumCredits(await readFile(pakPath));
await writeFile(resolve(resources, 'browser/LICENSES.chromium.html'), credits.html);
await writeFile(resolve(resources, 'browser/provenance.json'), JSON.stringify({ version: versions.chromium, playwrightRevision: versions.chromiumRevision,
  url: browserUrl, sha256: chromiumSha256, hashAuthority: 'Pinned observed official artifact digest; no upstream checksum publication was located',
  licenseUrl, licenseSha256: await sha256(resolve(resources, 'browser/LICENSE')),
  credits: { source: 'chrome-win64/resources.pak in the pinned Windows ZIP', resourceId: credits.resourceId, pakSha256: await sha256(pakPath),
    bytes: credits.html.length, sha256: await sha256(resolve(resources, 'browser/LICENSES.chromium.html')) } }, null, 2) + '\n');
const nodeStage = resolve(release, '.stage-node');
await rm(nodeStage, { recursive: true, force: true });
await run('unzip', ['-q', '-o', node.path, '-d', nodeStage]);
await mkdir(resolve(resources, 'runtime'), { recursive: true });
for (const name of ['node.exe', 'LICENSE']) await cp(resolve(nodeStage, `node-v${versions.node}-win-x64`, name), resolve(resources, 'runtime', name));
await writeFile(resolve(folder, '실행안내.md'), await readFile(resolve(root, 'PACKAGING.md')));
await writeFile(resolve(folder, 'inspector.env.example'), await readFile(resolve(root, 'inspector.env.example')));
const manifest = { schemaVersion: 1, target: 'win32-x64', versions: { ...versions, production: pkg.dependencies }, artifacts: { electron, node,
  chromium: { url: browserUrl, sha256: chromiumSha256, hashAuthority: 'Pinned observed official artifact digest' } },
  verification: { peArchitecture: 'x64 PE32+', windows11Execution: 'NOT_RUN', actualClefInference: 'NOT_RUN', actualOcrInference:'NOT_RUN', selfTestInferenceTransport:'EXPLICIT_SYNTHETIC_HTTP_MOCK', repositoryLicense: 'UNRESOLVED', offlineChromiumCredits: 'EXTRACTED_FROM_MATCHING_WINDOWS_PAK' },
  files: await verifyPackage(folder, { versions: { production: pkg.dependencies } }) };
// Cache locations belong to the build machine, so do not embed them in the release metadata.
delete manifest.artifacts.electron.path; delete manifest.artifacts.node.path;
await writeFile(resolve(release, 'Inspektor-win32-x64.manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
await verifyPackage(folder, manifest);
await rm(resolve(release, 'Inspektor-win32-x64.zip'), { force: true });
await run('zip', ['-q', '-r', 'Inspektor-win32-x64.zip', 'Inspektor-win32-x64', 'Inspektor-win32-x64.manifest.json'], release);

// Source export is a strict app-only allowlist, never a recursive repository/dependency copy.
const source = resolve(release, '.stage-source/inspector');
await rm(dirname(source), { recursive: true, force: true });
await mkdir(source, { recursive: true });
for (const name of ['src', 'scripts', 'test', 'package.json', 'package-lock.json', 'tsconfig.json', 'eslint.config.mjs', 'vitest.config.ts', 'AGENTS.md', 'Dockerfile', 'compose.yaml', '.dockerignore', 'PACKAGING.md', 'inspector.env.example']) {
  await cp(resolve(root, name), resolve(source, name), { recursive: true, dereference: false });
}
await cp(resolve(root, 'README.md'), resolve(source, 'README.md')).catch(error => { if (error.code !== 'ENOENT') throw error; });
const sourceFiles = await inventory(source, { source: true });
for (const file of sourceFiles) {
  const text = await readFile(resolve(source, file.path), 'utf8');
  if (/sk-or-v1-[a-z0-9]{32,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/i.test(text)) throw new Error(`Secret-shaped source content: ${file.path}`);
}
await writeFile(resolve(release, 'inspector-source.manifest.json'), JSON.stringify({ schemaVersion: 1, files: sourceFiles, repositoryLicense: 'UNRESOLVED' }, null, 2) + '\n');
await rm(resolve(release, 'inspector-source.zip'), { force: true });
await run('zip', ['-q', '-r', resolve(release, 'inspector-source.zip'), 'inspector'], dirname(source));
await writeFile(resolve(release, 'SHA256SUMS.txt'), `${await sha256(resolve(release, 'Inspektor-win32-x64.zip'))}  Inspektor-win32-x64.zip\n${await sha256(resolve(release, 'Inspektor-win32-x64.manifest.json'))}  Inspektor-win32-x64.manifest.json\n${await sha256(resolve(release, 'inspector-source.zip'))}  inspector-source.zip\n${await sha256(resolve(release, 'inspector-source.manifest.json'))}  inspector-source.manifest.json\n`);
for (const name of ['.stage-app', '.stage-node', '.stage-source']) await rm(resolve(release, name), { recursive: true, force: true });
console.log(`Windows 폴더와 ZIP 생성·정적 검증 완료: ${relative(root, folder)} (실제 Windows 실행 미검증)`);
