/** Explicit mocked HTTP smoke INSIDE the built image, with the real production entry and UI. */
import assert from 'node:assert/strict';
import {stopDeploymentChild} from './child-process.js';
import {readFile,writeFile,readdir,chmod,mkdir} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {request} from 'node:http';
import {resolve} from 'node:path';
import {setTimeout as delay} from 'node:timers/promises';
import {chromium,type Browser} from 'playwright';
import {startFixtureSite} from '../test/fixtures/site.js';
import {startOcrFixtureSite} from '../test/fixtures/ocr-site.js';
import {independentOfficialResult,independentExtraResult,assertTruth,sha256} from './verification.js';
import {FIXTURE_API_KEY,prepareFixtureInputs,writeFixturePreload} from './mock-transport.js';
import {isTerminalState,type RunSnapshotV2,type OcrFile} from '../src/core/index.js';
const output='/app/output',origin='http://127.0.0.1:4173';
const fixture=await startFixtureSite(),images=await startOcrFixtureSite();
let child:ReturnType<typeof spawn>|undefined,browser:Browser|undefined,failed=false;
async function expose(path:string):Promise<void>{for(const item of await readdir(path,{withFileTypes:true})){const full=resolve(path,item.name);if(item.isDirectory()){await chmod(full,0o755);await expose(full);}else if(item.isFile())await chmod(full,0o644);}}
try{
 const inputs=await prepareFixtureInputs(images.urls.images);const preload=resolve(output,'fixture-preload.mjs'),counter=resolve(output,'transport-counts.json');
 await writeFixturePreload(preload,inputs,counter,'file:///app/dist/mock-transport.mjs');
 child=spawn(process.execPath,['--import',preload,'dist/main.mjs'],{cwd:'/app',env:{...process.env,OPENROUTER_API_KEY:FIXTURE_API_KEY},stdio:['ignore','pipe','pipe']});child.stdout!.resume();child.stderr!.resume();
 let html='';for(let n=0;n<100;n++){try{const response=await fetch(origin);if(response.ok){html=await response.text();break;}}catch{/*startup*/}await delay(100);}
 assert.ok(html.includes('공개 웹사이트'));assert.ok(!html.includes(FIXTURE_API_KEY));const bootstrap=/window\.__INSPECTOR_BOOTSTRAP__=(\{.*?\});<\/script>/.exec(html);assert.ok(bootstrap);const token=(JSON.parse(bootstrap[1])as{sessionToken:string}).sessionToken;
 const api=async(path:string,value?:unknown)=>{const response=await fetch(origin+path,{method:value===undefined?'GET':'POST',headers:{Authorization:`Bearer ${token}`,Origin:origin,...(value===undefined?{}:{'Content-Type':'application/json'})},...(value===undefined?{}:{body:JSON.stringify(value)})});assert.ok(response.ok,`Authenticated API ${path}: ${response.status}`);return response;};
 assert.equal((await fetch(origin+'/api/config')).status,401);const badHost=await new Promise<number>(res=>{const http=request(origin,{headers:{Host:'outside.invalid:4173'}},response=>{response.resume();res(response.statusCode??0);});http.end();});assert.equal(badHost,403);
 const config=await(await api('/api/config')).json()as{outputRoot:string;aiConfigured:boolean;aiRequired:boolean};assert.equal(config.outputRoot,output);assert.equal(config.aiRequired,true);assert.equal(config.aiConfigured,true);
 browser=await chromium.launch({headless:true});const ui=await browser.newPage({acceptDownloads:true});await ui.goto(origin);assert.equal(await ui.locator('#ocr-enabled').isChecked(),false);assert.equal(await ui.getByRole('button',{name:'점검 시작',exact:true}).isDisabled(),true);await ui.locator('#external-consent').check();
 const start=async(url:string,ocr=false)=>{await ui.locator('#entry-url').fill(url);await ui.locator('#ocr-enabled').setChecked(ocr);const pending=ui.waitForResponse(r=>r.url().endsWith('/api/runs')&&r.request().method()==='POST');await ui.getByRole('button',{name:'점검 시작',exact:true}).click();const response=await pending;assert.equal(response.status(),202);let run=await response.json()as RunSnapshotV2;const deadline=Date.now()+120000;while(!isTerminalState(run.state)&&Date.now()<deadline){await delay(100);run=await(await api(`/api/runs/${run.runId}`)).json()as RunSnapshotV2;}assert.ok(isTerminalState(run.state));return run;};
 const run=await start(fixture.urls.entry);assert.equal(run.state,'partial');const bytes=await readFile(resolve(output,'result.json'));const result=independentOfficialResult(bytes);assertTruth(result,fixture.expectedFindings);await ui.waitForFunction(()=>document.querySelector('.badge.partial')&&document.querySelectorAll('tbody tr').length===25);const uiRenderedFindings=await ui.locator('tbody tr').count();assert.equal(uiRenderedFindings,25);
 for(const name of ['result.json','result_extra.json','scan-status.json','review.json','finding-details.json','ocr.json']){const delivered=Buffer.from(await(await api(`/api/runs/${run.runId}/files/${name}`)).arrayBuffer());assert.deepEqual(delivered,await readFile(resolve(output,'runs',run.runId,name)));assert.ok(!delivered.toString().includes(FIXTURE_API_KEY));const pending=ui.waitForEvent('download');await ui.getByRole('button',{name:`${name} 다운로드`,exact:true}).click();assert.deepEqual(await readFile((await(await pending).path())!),delivered);}
 const imageRun=await start(images.urls.images,true);assert.equal(imageRun.state,'partial');const extraBytes=await readFile(resolve(output,'result_extra.json'));const extra=independentExtraResult(extraBytes);assert.ok(extra.findings.length>0);const ocr=await(await api(`/api/runs/${imageRun.runId}/ocr`)).json()as OcrFile;assert.equal(ocr.images.length,39);
 const image=ocr.images.find(item=>item.input)!;const png=await api(`/api/runs/${imageRun.runId}/images/${image.input!.assetId}`);assert.equal(png.headers.get('content-type'),'image/png');assert.equal(png.headers.get('x-content-type-options'),'nosniff');assert.equal(sha256(Buffer.from(await png.arrayBuffer())),image.input!.sha256);
 await ui.waitForFunction(()=>document.querySelector('.badge.partial'));await ui.getByRole('button',{name:/^이미지 상세/}).first().click();await ui.locator('dialog img').waitFor({state:'visible'});assert.ok((await ui.locator('dialog img').getAttribute('src'))?.startsWith('blob:'));await ui.getByRole('button',{name:'닫기',exact:true}).click();
 for(const site of [fixture,images])assert.ok(site.requests.every(item=>['GET','HEAD'].includes(item.method)));assert.ok(!fixture.requests.some(item=>item.origin==='external'&&item.path==='/outside'));assert.deepEqual(await readFile(resolve(output,'runs',run.runId,'result.json')),bytes);
 const counts=JSON.parse(await readFile(counter,'utf8'));assert.equal(counts.ocr,imageRun.requestCounts.ocr);assert.ok(counts.clef>0);
 const status=JSON.parse(await readFile(resolve(output,'scan-status.json'),'utf8'));assert.equal(status.resultSaved,true);assert.equal(status.extraResultSaved,true);assert.equal(status.files.extraResultSha256,sha256(extraBytes));
 await mkdir(resolve(output,'screens'),{recursive:true});await ui.screenshot({path:resolve(output,'screens/docker-ocr.png'),fullPage:true});
 await writeFile(resolve(output,'docker-smoke-report.json'),JSON.stringify({schemaVersion:2,assertions:'PASS',uid:process.getuid?.()??null,runId:run.runId,state:run.state,expectedFindings:25,actualFindings:result.findings.length,uiRenderedFindings,resultSha256:sha256(bytes),imageRunId:imageRun.runId,extraFindings:extra.findings.length,extraResultSha256:sha256(extraBytes),imageOccurrences:ocr.images.length,registeredPngAndSixDownloads:'PASS',outputRoot:output,aiEnabled:true,inferenceTransport:'EXPLICIT_SYNTHETIC_HTTP_MOCK',transportCalls:counts,actualOcrInference:'NOT_RUN',actualClefInference:'NOT_RUN',actualWindowsExecution:'NOT_RUN'},null,2)+'\n',{mode:0o600});
 console.log(`Docker production UI/PNG/download/paired JSON PASS: DOM ${result.findings.length}, images ${extra.findings.length}`);
}catch(error){failed=true;console.error(error instanceof Error?error.message:'Docker smoke failure');}
finally{await browser?.close();if(child)await stopDeploymentChild(child);await fixture.stop();await images.stop();await expose(output);if(failed)process.exitCode=1;}
