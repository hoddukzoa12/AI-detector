/** Reproducible check of a locally built inspector:verify; only creates private synthetic temporary files. */
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
import { mkdtemp, mkdir, chmod, readFile, readdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';
const appRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const env = { ...process.env };
for (const name of ['DOCKER_HOST', 'DOCKER_CONTEXT', 'DOCKER_TLS', 'DOCKER_TLS_VERIFY', 'DOCKER_CERT_PATH']) delete env[name];
async function docker(args, capture = false) {
  return new Promise((res, rej) => {
    const child = spawn('docker', ['--host=unix:///var/run/docker.sock', ...args], { cwd: appRoot, env, stdio: capture ? ['ignore', 'pipe', 'pipe'] : 'inherit' });
    let output = ''; if (capture) { child.stdout.on('data', bytes => { output += bytes.toString(); }); child.stderr.resume(); }
    child.once('error', rej); child.once('exit', code => code === 0 ? res(output.trim()) : rej(new Error(`Docker ${args[0]} exit ${code}`)));
  });
}
const ownLabel=randomUUID();
async function cleanupOwnContainers(){for(const suffix of ['self','web']){const ids=await docker(['ps','-a','--filter',`name=^/inspector-ocr-t8-${suffix}$`,'--filter',`label=inspector.verification.owner=${ownLabel}`,'--format','{{.ID}}'],true);for(const id of ids.split(/\s+/).filter(Boolean))await docker(['rm','--force',id]);}}
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
try {
  assert.equal(process.argv.length, 2, 'docker-check accepts no flags and checks only inspector:verify');
  const imageId = await docker(['image', 'inspect', 'inspector:verify', '--format', '{{.Id}}'], true);
  const temporary = await mkdtemp(resolve(tmpdir(), 'inspector-docker-check-'));
  // Docker's UID 1001 needs traversal; this directory contains synthetic fixture evidence only.
  await chmod(temporary, 0o755);
  const selfOutput = resolve(temporary, 'self-output'), webOutput = resolve(temporary, 'web-output');
  for (const path of [selfOutput, webOutput]) { await mkdir(path); await chmod(path, 0o777); }
  const common = ['run', '--rm', '--label',`inspector.verification.owner=${ownLabel}`, '--cap-drop=ALL', '--security-opt=no-new-privileges', '--init', '--shm-size=1gb', '-e', 'OPENROUTER_API_KEY=', '-e', 'INSPECTOR_OUTPUT_DIR=/app/output'];
  const name = 'inspector-ocr-t8';
  for(const suffix of ['self','web']) { const existing=await docker(['ps','-a','--filter',`name=^/${name}-${suffix}$`,'--format','{{.ID}}'],true);assert.equal(existing,'','deterministic verification name already owned by another run'); }
  const selfCommand = `const {execFileSync}=await import('node:child_process');const fs=await import('node:fs/promises');execFileSync(process.execPath,['dist/self-test.mjs','--mode','docker','--output-dir','/app/output'],{stdio:'inherit'});async function expose(p){for(const e of await fs.readdir(p,{withFileTypes:true})){const f=p+'/'+e.name;if(e.isDirectory()){await fs.chmod(f,0o755);await expose(f)}else if(e.isFile())await fs.chmod(f,0o644)}}await expose('/app/output/self-test');`;
  await docker([...common, '--name', name + '-self', '--mount', `type=bind,src=${selfOutput},dst=/app/output`, 'inspector:verify', 'node', '--input-type=module', '-e', selfCommand]);
  const dirs = await readdir(resolve(selfOutput, 'self-test')); assert.equal(dirs.length, 1);
  const selfReport = JSON.parse(await readFile(resolve(selfOutput, 'self-test', dirs[0], 'self-test-report.json'), 'utf8'));
  assert.equal(selfReport.uid, 1001); assert.equal(selfReport.playwrightVersion, '1.63.0'); assert.equal(selfReport.chromiumVersion, '153.0.8010.12'); assert.equal(selfReport.assertions, 'PASS'); assert.equal(selfReport.mode, 'docker'); assert.equal(selfReport.runs[0].findings, 25); assert.equal(selfReport.runs[1].findings, 0); assert.equal(selfReport.runs[2].imageOccurrences,39);assert.ok(selfReport.runs[2].extraFindings>0);assert.equal(selfReport.runs[3].findings,5);assert.equal(selfReport.inferenceTransport,'EXPLICIT_SYNTHETIC_HTTP_MOCK');
  const isolated = resolve(selfOutput, 'self-test', dirs[0]);
  const selfBytes = await readFile(resolve(isolated, 'runs', selfReport.runs[0].runId, 'result.json')); assert.equal(sha256(selfBytes), selfReport.runs[0].resultSha256);
  const bundle = resolve(temporary, 'docker-web-check.mjs');
  await build({ entryPoints: [resolve(appRoot, 'scripts/docker-smoke.ts')], outfile: bundle, bundle: true, platform: 'node', target: 'node22', format: 'esm', packages: 'external' });
  await chmod(bundle, 0o644);
  const mockBundle=resolve(temporary,'mock-transport.mjs');await build({entryPoints:[resolve(appRoot,'scripts/mock-transport.ts')],outfile:mockBundle,bundle:true,platform:'node',target:'node22',format:'esm',packages:'external'});await chmod(mockBundle,0o644);
  await docker([...common, '--name', name + '-web', '--publish', '127.0.0.1:4173:4173', '--mount', `type=bind,src=${webOutput},dst=/app/output`, '--mount', `type=bind,src=${bundle},dst=/app/dist/docker-web-check.mjs,readonly`, '--mount',`type=bind,src=${mockBundle},dst=/app/dist/mock-transport.mjs,readonly`,'inspector:verify', 'node', 'dist/docker-web-check.mjs']);
  const webReport = JSON.parse(await readFile(resolve(webOutput, 'docker-smoke-report.json'), 'utf8'));
  const webBytes = await readFile(resolve(webOutput,'runs',webReport.runId,'result.json')); const extraBytes=await readFile(resolve(webOutput,'runs',webReport.imageRunId,'result_extra.json'));assert.equal(sha256(extraBytes),webReport.extraResultSha256);assert.equal(webReport.uid,1001);assert.equal(webReport.imageOccurrences,39);assert.ok(webReport.extraFindings>0); assert.equal(sha256(webBytes), webReport.resultSha256); assert.equal(webReport.actualFindings, 25); assert.equal(webReport.uiRenderedFindings, 25); assert.equal(webReport.assertions, 'PASS');
  const reportPath = resolve(appRoot, 'release/verification/ocr-clef/docker-check-report.json'); await mkdir(dirname(reportPath), { recursive: true });
  const report = { schemaVersion: 2, assertions: 'PASS', image: 'inspector:verify', imageId, hostSyntheticOutput: temporary,
    selfTestExit: 0, productionWebExit: 0, uid: 1001, selfTest: selfReport, productionWeb: webReport, hostVolumeHash: 'PASS', actualWindowsExecution: 'NOT_RUN', actualClefInference: 'NOT_RUN', actualOcrInference:'NOT_RUN', inferenceTransport:'EXPLICIT_SYNTHETIC_HTTP_MOCK' };
  await writeFile(reportPath, JSON.stringify(report, null, 2) + '\n'); console.log(`Docker check PASS: ${reportPath}`);
} catch (error) { console.error(error instanceof Error ? error.message : 'Docker check failed'); process.exitCode = 1; }
finally { await cleanupOwnContainers().catch(() => { console.error('Owned verification container cleanup failed');process.exitCode=1; }); }
