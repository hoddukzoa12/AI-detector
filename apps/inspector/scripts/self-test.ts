/** Explicit mocked HTTP deployment self-check. Runtime dependencies only; no test runner or production schema validator. */
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { mkdir, readFile, realpath, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';
import { sanitizeErrorMessage } from '../src/core/index.js';
import { InspectorApplication, loadRuntimeConfig, type RuntimeMode } from '../src/application/index.js';
import { assertTruth, assertTruthLocations, independentOfficialResult, sha256 } from './verification.js';
import { crawl } from '../src/crawler/index.js';
import { startOcrFixtureSite } from '../test/fixtures/ocr-site.js';
import { assetTruth, imageTruth, menuTruth } from '../test/fixtures/ocr-truth.js';
import { createFixtureTransport, FIXTURE_API_KEY } from './mock-transport.js';
import { independentExtraResult } from './verification.js';
import { startFixtureSite } from '../test/fixtures/site.js';

interface SelfTestOptions { mode: RuntimeMode; exePath?: string; chromiumPath?: string; outputDir?: string }
export function parseSelfTestArgs(args: string[]): SelfTestOptions {
  const values = new Map<string, string>(); const allowed = ['--mode', '--exe-path', '--chromium-path', '--output-dir'];
  for (let i = 0; i < args.length; i += 2) {
    assert.ok(allowed.includes(args[i]) && !values.has(args[i]), 'unknown or duplicate self-test flag');
    assert.ok(args[i + 1] && !args[i + 1].startsWith('--'), 'self-test flag needs a value'); values.set(args[i], args[i + 1]);
  }
  const mode = values.get('--mode') ?? process.env.INSPECTOR_RUNTIME ?? 'npm'; assert.ok(['npm', 'docker', 'desktop'].includes(mode), 'valid runtime mode');
  if (mode === 'desktop') assert.ok(values.get('--exe-path') && values.get('--chromium-path'), 'desktop requires actual GUI exe and bundled Chromium paths');
  if (mode !== 'desktop') assert.ok(!values.has('--exe-path'), '--exe-path requires desktop mode');
  return { mode: mode as RuntimeMode, exePath: values.get('--exe-path'), chromiumPath: values.get('--chromium-path'), outputDir: values.get('--output-dir') };
}
export async function runSelfTest(options: SelfTestOptions): Promise<string> {
  const config = await loadRuntimeConfig({ mode: options.mode, exePath: options.exePath });
  const outputRoot = resolve(options.outputDir ?? config.outputRoot);
  const isolated = resolve(outputRoot, 'self-test', `${new Date().toISOString().replace(/[:.]/g, '-')}-${randomUUID()}`);
  await mkdir(isolated, { recursive: true });
  const executablePath = options.chromiumPath ?? config.executablePath ?? chromium.executablePath();
  const fixture = await startFixtureSite(); const images = await startOcrFixtureSite();
  const mock = createFixtureTransport();
  const app = new InspectorApplication({ outputRoot: isolated, apiKey: FIXTURE_API_KEY, executablePath, limits:config.limits,
    crawlOptions: { dynamicWaitMs: 150, resourceWaitMs: 150, scrollSteps: 1, scrollWaitMs: 10, navigationTimeoutMs: 1500 },
    // Explicit read-only fixture instrumentation only: real collection and actual scratch hashes remain authoritative.
    crawl: (entry, options={}) => crawl(entry, {...options, images:options.images ? {...options.images,onImage:async(owner,value)=>{mock.observeAssets(value);await options.images!.onImage(owner,value);}}:undefined}),
    aiOptions:{fetch:mock.fetch},ocrOptions:{fetch:mock.fetch} });
  let browser: Awaited<ReturnType<typeof chromium.launch>> | undefined;
  try {
    const run = app.start({ entryUrl: fixture.urls.entry, ocrEnabled: false, externalAnalysisConsent: true }); const finished = await app.wait(run.runId);
    assert.equal(finished.state, 'partial', 'failed page/frame distinguished from complete zero');
    const bytes = await app.readFile(run.runId, 'result.json'), result = independentOfficialResult(bytes); assertTruth(result, fixture.expectedFindings);
    assert.equal(result.meta.entry_url, fixture.urls.entry); assert.equal(result.meta.finished_at, finished.finishedAt);
    const status = JSON.parse((await app.readFile(run.runId, 'scan-status.json')).toString());
    assert.equal(status.files.resultSha256, sha256(bytes)); assert.equal(status.resultSaved, true);
    assert.ok(Math.abs(result.meta.elapsed_sec - (Date.parse(result.meta.finished_at) - Date.parse(result.meta.started_at)) / 1000) < .002, 'fixture elapsed agrees with timestamps');
    const manifest = JSON.parse(await readFile(resolve(isolated, 'runs', run.runId, 'manifest.json'), 'utf8'));
    for (const name of ['result.json', 'result_extra.json', 'scan-status.json', 'review.json', 'finding-details.json', 'ocr.json']) {
      const archiveBytes = await readFile(resolve(isolated, 'runs', run.runId, name));
      assert.deepEqual(archiveBytes, await readFile(resolve(isolated, name)), 'canonical/archive bytes agree');
      assert.deepEqual(archiveBytes, await app.readFile(run.runId, name as 'result.json' | 'result_extra.json' | 'scan-status.json' | 'review.json' | 'finding-details.json' | 'ocr.json'));
      assert.equal(sha256(archiveBytes), manifest.files[name], 'manifest hash matches actual bytes');
      assert.ok(config.apiKey.length < 16 || !archiveBytes.toString().includes(config.apiKey), 'credential-shaped key excluded from files');
    }
    assert.ok(status.run.errors.some((error: { code: string }) => error.code === 'FRAME_UNAVAILABLE'));
    assert.ok(status.scope.skipped.some((item: { reasonCode: string }) => item.reasonCode === 'LOGIN_REQUIRED'));
    for (const detail of app.details(run.runId).details) {
      const evidence = await app.readEvidence(run.runId, detail.evidence.snapshotId);
      assert.equal(detail.evidence.sha256, sha256(evidence)); assert.equal(detail.decisionSource, 'clef'); assert.deepEqual(detail.ruleIds,[]);
    }
    browser = await chromium.launch({ executablePath, headless: true });
    const page = await browser.newPage(); await assertTruthLocations(page, fixture);
    const emptyRun = app.start({ entryUrl: fixture.urls.negatives, ocrEnabled: false, externalAnalysisConsent: true }); const emptyFinished = await app.wait(emptyRun.runId);
    assert.equal(emptyFinished.state, 'completed'); const emptyBytes = await app.readFile(emptyRun.runId, 'result.json'); assertTruth(independentOfficialResult(emptyBytes), []);
    const emptyExtra = independentExtraResult(await app.readFile(emptyRun.runId,'result_extra.json')); assert.equal(emptyExtra.findings.length,0);
    const imageRun=app.start({entryUrl:images.urls.images,ocrEnabled:true,externalAnalysisConsent:true}); const imageFinished=await app.wait(imageRun.runId);
    assert.equal(imageFinished.state,'partial','unreadable OCR or inaccessible linked pages remain partial');
    const imageOfficial=independentOfficialResult(await app.readFile(imageRun.runId,'result.json')); assert.equal(imageOfficial.findings.length,1,'direct DOM text distinct from image text');
    const extraBytes=await app.readFile(imageRun.runId,'result_extra.json'); const extra=independentExtraResult(extraBytes); const ocr=app.ocr(imageRun.runId);
    assert.equal(ocr.images.length,imageTruth.length,'all independent image occurrences');
    const expectedOwners=new Map<string,string>();
    for(const truth of imageTruth){
      const occurrence=ocr.images.find(image=>image.location.endsWith(truth.selector)&&image.framePath.length===truth.framePath.length&&image.framePath.every((path,index)=>(path.includes(truth.framePath[index].replace('iframe#','#'))||(truth.framePath[index]==='iframe#external'&&path.includes(images.externalOrigin+'/frames/external'))||(truth.framePath[index]==='iframe#nested'&&path.includes(images.externalOrigin+'/frames/nested'))))&&image.sourceKind===truth.sourceKind&&image.sourceIndex===truth.sourceIndex);
      assert.ok(occurrence,`independent occurrence ${truth.id}`); const asset=assetTruth.find(asset=>asset.id===truth.assetId)!;
      assert.equal(occurrence.original?.sha256,asset.sha256);assert.ok(occurrence.original?.path);const originalBytes=await readFile(resolve(isolated,occurrence.original.path));assert.equal(sha256(originalBytes),asset.sha256);assert.equal(originalBytes.length,asset.byteLength);assert.equal(occurrence.text,asset.text);assert.equal(occurrence.extractionStatus,asset.extractionStatus);assert.equal(occurrence.confidence,null);
      assert.ok(occurrence.input?.assetId);const png=await app.readImage(imageRun.runId,occurrence.input.assetId);assert.equal(sha256(png),occurrence.input.sha256);assert.ok(png.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])));
      if(asset.label==='illegal_ad')expectedOwners.set(occurrence.location,'');
      if(truth.concealment)assert.ok(occurrence.concealment.includes(truth.concealment));
    }
    assert.equal(extra.findings.length,expectedOwners.size,'positive owner count from independent labels');
    for(const finding of extra.findings){assert.ok(expectedOwners.has(finding.location),'no logo/cover/general/news/notice positives');const detail=app.details(imageRun.runId).details.find(item=>item.findingId===finding.id)!;assert.equal(detail.resultFile,'result_extra.json');assert.equal(detail.sourceType,'image_ocr');assert.deepEqual(detail.ruleIds,[]);assert.equal(detail.decisionSource,'clef');assert.equal(detail.sourceIds.length,ocr.images.filter(item=>item.location===finding.location).length);for(const range of detail.sourceTextRanges){const image=ocr.images.find(item=>item.imageId===range.imageId)!;assert.equal(finding.evidence_text.slice(range.rawStart,range.rawEnd),image.text);}}
    const ids=new Set([...imageOfficial.findings,...extra.findings].map(item=>item.id));assert.equal(ids.size,imageOfficial.findings.length+extra.findings.length);
    assert.ok(ocr.images.some(image=>image.cacheOf!==null),'same PNG different owners reuse mock OCR');assert.ok(app.review(imageRun.runId).candidates.some(item=>item.reason==='OCR_NO_TEXT'));assert.ok(app.review(imageRun.runId).candidates.some(item=>item.reason==='OCR_UNREADABLE'));
    const imageStatus=JSON.parse((await app.readFile(imageRun.runId,'scan-status.json')).toString());assert.equal(imageStatus.extraResultSaved,true);assert.equal(imageStatus.files.extraResultSha256,sha256(extraBytes));
    for(const name of ['result.json','result_extra.json','scan-status.json','review.json','finding-details.json','ocr.json'] as const){const value=await app.readFile(imageRun.runId,name);assert.deepEqual(value,await readFile(resolve(isolated,'runs',imageRun.runId,name)));assert.ok(!value.toString().includes(FIXTURE_API_KEY));}
    const imageManifest=JSON.parse(await readFile(resolve(isolated,'runs',imageRun.runId,'manifest.json'),'utf8'));for(const [name,hash] of Object.entries(imageManifest.files)){assert.equal(sha256(await readFile(resolve(isolated,'runs',imageRun.runId,name))),hash,'image archive manifest matches every actual JSON file');}
    const menuRun=app.start({entryUrl:images.urls.menu,ocrEnabled:false,externalAnalysisConsent:true});const menuFinished=await app.wait(menuRun.runId);const menu=independentOfficialResult(await app.readFile(menuRun.runId,'result.json'));
    assert.ok(!menuFinished.errors.some(error=>error.scope==='ai'),'mocked menu classifications all completed with correct owner links');
    assert.equal(menu.findings.length,5);for(const truth of menuTruth){const matches=menu.findings.filter(item=>item.location.endsWith(truth.selector));assert.equal(matches.length,truth.label==='illegal_ad'?1:0);if(matches.length){assert.equal(matches[0].evidence_text,truth.rawText);assert.equal(matches[0].technique,truth.technique);}}
    assert.ok(mock.counts().ocr>0&&mock.counts().clef>0);
    assert.ok(images.requests.every(item=>['GET','HEAD'].includes(item.method)));assert.ok(!images.requests.some(item=>item.origin==='external'&&item.path==='/outside'));

    assert.ok(fixture.requests.every(item => ['GET', 'HEAD'].includes(item.method)), 'no login/form/POST');
    assert.ok(!fixture.requests.some(item => item.origin === 'external' && item.path === '/outside'), 'external links excluded');
    assert.ok(!fixture.requests.some(item => item.path === '/login'), 'login not visited');
    const reportPath = resolve(isolated, 'self-test-report.json');
    const report = { schemaVersion: 2, assertions: 'PASS', platform: process.platform, arch: process.arch, nodeVersion: process.version,
      uid: process.getuid?.() ?? null, playwrightVersion: (createRequire(import.meta.url)('playwright/package.json') as { version: string }).version,
      mode: options.mode, executableReference: options.exePath ?? null, chromiumPath: executablePath, chromiumVersion: browser.version(),
      outputRoot, isolatedOutput: isolated, aiEnabled: true, inferenceTransport:'EXPLICIT_SYNTHETIC_HTTP_MOCK', transportCalls:mock.counts(), actualOcrInference:'NOT_RUN', actualClefInference: 'NOT_RUN', repositoryLicense:'UNRESOLVED', menuTitleNegatives:22,
      actualWindowsGuiExecution: 'NOT_RUN', runs: [{ runId: run.runId, state: finished.state, findings: result.findings.length, resultSha256: sha256(bytes) },
        { runId: emptyRun.runId, state: emptyFinished.state, findings: 0, extraFindings:0, resultSha256: sha256(emptyBytes) },
        {runId:imageRun.runId,state:imageFinished.state,findings:imageOfficial.findings.length,extraFindings:extra.findings.length,imageOccurrences:ocr.images.length,resultSha256:imageStatus.files.resultSha256,extraResultSha256:sha256(extraBytes)},
        {runId:menuRun.runId,state:menuFinished.state,findings:menu.findings.length,extraFindings:0}], rawAndFrameUniqueness: 'PASS' };
    const reportBytes = JSON.stringify(report, null, 2) + '\n'; assert.ok(config.apiKey.length < 16 || !reportBytes.includes(config.apiKey), 'credential-shaped key excluded from report');
    await writeFile(reportPath, reportBytes, { flag: 'wx', mode: 0o600 });
    // The positive run archive stays byte-identical after the second run; root result is inside isolated only.
    assert.deepEqual(await readFile(resolve(isolated, 'runs', run.runId, 'result.json')), bytes);
    return reportPath;
  } catch (error) {
    const message = sanitizeErrorMessage(error instanceof Error ? error.message : 'Deployment assertion failed', [config.apiKey]);
    await writeFile(resolve(isolated, 'self-test-report.json'), JSON.stringify({ schemaVersion: 2, assertions: 'FAIL', platform: process.platform, mode: options.mode, aiEnabled: true, inferenceTransport:'EXPLICIT_SYNTHETIC_HTTP_MOCK', error: message }, null, 2) + '\n', { flag: 'wx', mode: 0o600 }).catch(() => {});
    // The original cause may contain credentials; retain only its sanitized message.
    // eslint-disable-next-line preserve-caught-error
    throw new Error(message);
  } finally { await app.close(); await browser?.close(); await fixture.stop(); await images.stop(); }
}
if (process.argv[1] && await realpath(resolve(process.argv[1])).catch(() => '') === fileURLToPath(import.meta.url)) {
  try { console.log(`Self-test PASS: ${await runSelfTest(parseSelfTestArgs(process.argv.slice(2)))}`); }
  catch (error) { console.error(`Self-test FAIL: ${error instanceof Error ? error.message : 'Deployment assertion failed'}`); process.exitCode = 1; }
}
