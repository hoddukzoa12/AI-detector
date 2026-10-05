import assert from 'node:assert/strict';
import {stopDeploymentChild} from '../../scripts/child-process.js';
import {afterEach,it,expect} from 'vitest';
import {mkdtemp,readFile,rm,mkdir} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {spawn,type ChildProcess} from 'node:child_process';
import {setTimeout as delay} from 'node:timers/promises';
import {build} from 'esbuild';
import {chromium,type Browser,type Page} from 'playwright';
import {startFixtureSite,type FixtureSite} from '../fixtures/site.js';
import {startOcrFixtureSite,type OcrFixtureSite} from '../fixtures/ocr-site.js';
import type {RunSnapshotV2,FindingDetailsFileV2,ScanStatusFileV2,OcrFile} from '../../src/core/index.js';
import {FIXTURE_API_KEY,prepareFixtureInputs,writeFixturePreload} from '../../scripts/mock-transport.js';
import {assertTruth,assertTruthLocations,independentOfficialResult,independentExtraResult,sha256} from '../../scripts/verification.js';
let root='',child:ChildProcess|undefined,browser:Browser|undefined,fixture:FixtureSite|undefined,images:OcrFixtureSite|undefined;
afterEach(async()=>{await browser?.close();browser=undefined;if(child)await stopDeploymentChild(child);child=undefined;await fixture?.stop();fixture=undefined;await images?.stop();images=undefined;if(root)await rm(root,{recursive:true,force:true});});
async function deployment(){
 root=await mkdtemp(resolve(tmpdir(),'inspector-deployment-v2-'));fixture=await startFixtureSite();images=await startOcrFixtureSite();
 const inputs=await prepareFixtureInputs(images.urls.images,chromium.executablePath());
 const module=resolve('dist/mock-transport.mjs');await build({entryPoints:['scripts/mock-transport.ts'],outfile:module,bundle:true,platform:'node',target:'node22',format:'esm',packages:'external'});
 const preload=resolve(root,'explicit-fixture.mjs');await writeFixturePreload(preload,inputs,resolve(root,'transport.json'),pathToFileURL(module).href);
 const origin=await new Promise<string>((res,rej)=>{
  child=spawn(process.execPath,['--import',preload,'dist/main.mjs'],{env:{...process.env,INSPECTOR_RUNTIME:'npm',INSPECTOR_PORT:'0',INSPECTOR_HOST:'127.0.0.1',INSPECTOR_OUTPUT_DIR:root,INSPECTOR_CHROMIUM_PATH:chromium.executablePath(),OPENROUTER_API_KEY:FIXTURE_API_KEY},stdio:['ignore','pipe','pipe']});
  let output='';const timer=setTimeout(()=>rej(new Error('Production startup timeout')),10000);child.once('error',e=>{clearTimeout(timer);rej(e);});child.once('exit',code=>{clearTimeout(timer);rej(new Error(`Production entry exit ${code}`));});child.stdout!.on('data',bytes=>{output+=bytes.toString();const match=/http:\/\/127\.0\.0\.1:\d+/.exec(output);if(match){clearTimeout(timer);res(match[0]);}});child.stderr!.resume();
 });
 browser=await chromium.launch({headless:true});const page=await browser.newPage({acceptDownloads:true});const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));await page.goto(origin);await page.locator('#external-consent').check();await page.waitForFunction(()=>!(document.querySelector('[data-action="start"]')as HTMLButtonElement).disabled);
 const token=await page.evaluate(()=>(window as unknown as{__INSPECTOR_BOOTSTRAP__:{sessionToken:string}}).__INSPECTOR_BOOTSTRAP__.sessionToken);
 const api=(path:string,body?:unknown)=>fetch(origin+path,{method:body===undefined?'GET':'POST',headers:{Authorization:`Bearer ${token}`,Origin:origin,'Content-Type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)})});assert.equal(errors.length,0);assert.ok(!(await page.content()).includes(FIXTURE_API_KEY));return{page,origin,api};
}
async function waitRun(api:(path:string)=>Promise<Response>,id:string,predicate:(run:RunSnapshotV2)=>boolean){const deadline=Date.now()+60000;while(Date.now()<deadline){const run=await(await api(`/api/runs/${id}`)).json()as RunSnapshotV2;if(predicate(run))return run;await delay(100);}throw new Error('Production run timeout');}
const terminal=(run:RunSnapshotV2)=>['completed','partial','cancelled','failed'].includes(run.state);
async function startUi(page:Page,url:string,ocr=false){await page.locator('#entry-url').fill(url);await page.locator('#ocr-enabled').setChecked(ocr);const pending=page.waitForResponse(r=>r.url().endsWith('/api/runs')&&r.request().method()==='POST');await page.getByRole('button',{name:'점검 시작',exact:true}).click();const response=await pending;expect(response.status()).toBe(202);return(await response.json()as RunSnapshotV2).runId;}
it('built npm production UI requires consent, preserves DOM25, four plus two JSON downloads and safe registered OCR PNGs',async()=>{
 const{page,origin,api}=await deployment();const site=fixture!;
 expect(await page.locator('#ocr-enabled').isChecked()).toBe(false);expect(await page.locator('#ai-enabled').count()).toBe(0);
 expect((await fetch(origin+'/api/config')).status).toBe(401);expect((await api('/api/config')).status).toBe(200);expect((await api('/api/runs',{entryUrl:site.urls.entry,ocrEnabled:false})).status).toBe(400);expect((await api('/api/runs',{entryUrl:site.urls.entry,aiEnabled:false})).status).toBe(400);
 const id=await startUi(page,site.urls.entry);expect((await api('/api/runs',{entryUrl:site.urls.entry,ocrEnabled:false,externalAnalysisConsent:true})).status).toBe(409);
 const run=await waitRun(api,id,terminal);expect(run.state).toBe('partial');expect(run.counts.confirmedFindings).toBe(25);
 const bytes=Buffer.from(await(await api(`/api/runs/${id}/files/result.json`)).arrayBuffer());assertTruth(independentOfficialResult(bytes),site.expectedFindings);await page.waitForFunction(()=>document.querySelector('.badge.partial')&&document.querySelectorAll('tbody tr').length===25);
 const details=await(await api(`/api/runs/${id}/finding-details`)).json()as FindingDetailsFileV2;expect(details.details).toHaveLength(25);
 for(const detail of details.details){expect(detail.decisionSource).toBe('clef');expect(detail.ruleIds).toEqual([]);expect(detail.ai.model).toBe('cloudflare/clef');const value=Buffer.from(await(await api(`/api/runs/${id}/evidence/${detail.evidence.snapshotId}`)).arrayBuffer());expect(sha256(value)).toBe(detail.evidence.sha256);}
 for(const name of ['result.json','result_extra.json','scan-status.json','review.json','finding-details.json','ocr.json']){const delivered=Buffer.from(await(await api(`/api/runs/${id}/files/${name}`)).arrayBuffer());expect(delivered).toEqual(await readFile(resolve(root,'runs',id,name)));expect(delivered.toString()).not.toContain(FIXTURE_API_KEY);const event=page.waitForEvent('download');await page.getByRole('button',{name:`${name} 다운로드`,exact:true}).click();expect(await readFile((await(await event).path())!)).toEqual(delivered);}
 const truthPage=await browser!.newPage();await assertTruthLocations(truthPage,site);await truthPage.close();expect(site.requests.every(r=>['GET','HEAD'].includes(r.method))).toBe(true);expect(site.requests.some(r=>r.path==='/login'||r.origin==='external'&&r.path==='/outside')).toBe(false);
 const imageId=await startUi(page,images!.urls.images,true);const imageRun=await waitRun(api,imageId,terminal);expect(imageRun.state).toBe('partial');expect(imageRun.counts.extraConfirmedFindings).toBeGreaterThan(0);
 const ocr=await(await api(`/api/runs/${imageId}/ocr`)).json()as OcrFile;expect(ocr.images).toHaveLength(39);const extra=independentExtraResult(Buffer.from(await(await api(`/api/runs/${imageId}/files/result_extra.json`)).arrayBuffer()));expect(extra.findings.length).toBe(imageRun.counts.extraConfirmedFindings);
 const image=ocr.images.find(item=>item.input)!;const response=await api(`/api/runs/${imageId}/images/${image.input!.assetId}`);expect(response.headers.get('content-type')).toBe('image/png');expect(response.headers.get('x-content-type-options')).toBe('nosniff');expect(sha256(Buffer.from(await response.arrayBuffer()))).toBe(image.input!.sha256);expect((await api(`/api/runs/${imageId}/images/${image.original!.assetId}`)).status).toBe(404);
 await page.waitForFunction(()=>document.querySelector('.badge.partial'));await page.getByRole('button',{name:/^이미지 상세/}).first().click();await page.locator('dialog img').waitFor({state:'visible'});expect(await page.locator('dialog img').getAttribute('src')).toMatch(/^blob:/);await page.getByRole('button',{name:'닫기',exact:true}).click();
 await mkdir('release/verification/ocr-clef',{recursive:true});await page.screenshot({path:'release/verification/ocr-clef/npm-v2-screen.png',fullPage:true});
 const counts=JSON.parse(await readFile(resolve(root,'transport.json'),'utf8'));expect(counts.ocr).toBe(imageRun.requestCounts.ocr);expect(counts.clef).toBeGreaterThan(0);
 expect(sha256(await readFile(resolve(root,'runs',id,'result.json')))).toBe(sha256(bytes));
},120000);
it('production UI cancellation saves confirmed CLEF positives and unfinished scope, retaining both result files',async()=>{
 const{page,api}=await deployment();const id=await startUi(page,fixture!.urls.entry);await waitRun(api,id,run=>run.counts.confirmedFindings>=17&&run.counts.pendingPages>0);
 const response=page.waitForResponse(r=>r.url().endsWith(`/api/runs/${id}/cancel`));await page.getByRole('button',{name:'점검 중지',exact:true}).click();expect((await response).status()).toBe(202);const run=await waitRun(api,id,terminal);expect(run.state).toBe('cancelled');
 const status=await(await api(`/api/runs/${id}/files/scan-status.json`)).json()as ScanStatusFileV2;expect(status.resultSaved).toBe(true);expect(status.extraResultSaved).toBe(true);expect(status.scope.unvisitedUrls.length).toBeGreaterThan(0);
 const result=independentOfficialResult(Buffer.from(await(await api(`/api/runs/${id}/files/result.json`)).arrayBuffer()));expect(result.findings.length).toBeGreaterThanOrEqual(17);for(const finding of result.findings)expect(fixture!.expectedFindings.some(truth=>truth.url===finding.url&&truth.location===finding.location&&truth.rawEvidence===finding.evidence_text&&truth.technique===finding.technique)).toBe(true);
 await page.waitForFunction(()=>document.querySelector('.badge.cancelled'));expect(JSON.parse(await readFile(resolve(root,'transport.json'),'utf8')).clef).toBe(run.requestCounts.clef);
},120000);
