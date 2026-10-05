import { afterEach, expect, it, vi } from 'vitest';
import { mkdtemp, rm, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { InspectorApplication } from '../../src/application/index.js';
import { OutputStoreV2 } from '../../src/output/index.js';
import { positiveClef, mockAnalysisOptions } from './mock-transport.js';
import { assets, owner, imagePage, imageCrawler, imageUrl, ocrResponse, png } from './image-fixture.js';
const roots: string[] = [];
afterEach(async () => { await Promise.all(roots.splice(0).map(root => rm(root, { recursive: true, force: true }))); });
async function root() { const path = await mkdtemp(join(tmpdir(), 'image-app-')); roots.push(path); return path; }
const request = { entryUrl: imageUrl, ocrEnabled: true, externalAnalysisConsent: true } as const;
it('freezes every owner source before CLEF and preserves DOM, image confirmation and failed-source review in exact files', async () => {
  const path = await root(); const first = await assets(path, 'source-first'); const second = await assets(path, 'source-second', 2);
  const images = [owner(first.imageId), owner(second.imageId, '#banner', 'css_background')]; let clefCalls = 0; let ocrCalls = 0;
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: join(path, 'output'),
    crawl: imageCrawler(imagePage(images, true), [{ status: 'captured', assets: first }, { status: 'error', reasonCode: 'IMAGE_DECODE_ERROR', message: 'decode failed', original: second.original, capturedAt: second.capturedAt }],
      index => { if (index === 1) expect(clefCalls).toBe(1); }),
    ocrOptions: { fetch: async (endpoint, init) => { ocrCalls++; expect(endpoint).toBe('https://openrouter.ai/api/v1/chat/completions'); const body = JSON.parse(init!.body as string);
      expect(body.model).toBe('google/gemini-3.8-flash'); expect(body.response_format.json_schema.strict).toBe(true);
      expect(body.messages[1].content[0].image_url.url.startsWith('data:image/png;base64,')).toBe(true); return ocrResponse('readable', '원문 OCR 🧾'); } },
    aiOptions: { fetch: async (endpoint, init) => { clefCalls++; expect(endpoint).toBe('https://openrouter.ai/api/alpha/decisions'); const body = JSON.parse(init!.body as string);
      expect(Object.keys(body.state).sort()).toEqual(['links','normalizedText','rawText']); if(clefCalls === 2) expect(body.state.rawText).toBe('원문 OCR 🧾'); return positiveClef(endpoint, init); } } });
  const run = app.start(request); const terminal = await app.wait(run.runId);
  expect(terminal.state).toBe('partial'); expect(ocrCalls).toBe(1); expect(clefCalls).toBe(2);
  expect(terminal.counts).toMatchObject({ confirmedFindings: 1, extraConfirmedFindings: 1, reviewCandidates: 1 });
  expect(terminal.imageCounts).toEqual({ discovered: 2, captured: 2, ocrCompleted: 1, failed: 1, pending: 0, skipped: 0 });
  expect(terminal.requestCounts).toEqual({ ocr: 1, clef: 2 });
  const review = app.review(run.runId).candidates[0]; expect(review.reason).toBe('OCR_ERROR'); expect(review.evidenceText).toBe('원문 OCR 🧾');
  expect(review.sourceIds).toEqual(images.map(image => image.imageId)); expect(review.sourceTextRanges).toEqual([{ imageId: first.imageId, rawStart: 0, rawEnd: '원문 OCR 🧾'.length }]);
  expect(app.findings(run.runId).findings[0].evidence_text).toBe('원본 글자'); expect(app.extraFindings(run.runId).findings[0].evidence_text).toBe(review.evidenceText);
  expect(app.details(run.runId).details.map(detail => detail.resultFile)).toEqual(['result.json', 'result_extra.json']);
  for (const [file, value] of [['result.json', app.findings(run.runId).findings], ['result_extra.json', app.extraFindings(run.runId).findings]] as const) {
    const bytes = await app.readFile(run.runId, file); expect(bytes[0]).not.toBe(239); expect(JSON.parse(bytes.toString()).findings).toEqual(value);
  }
  expect(JSON.parse((await app.readFile(run.runId, 'ocr.json')).toString())).toEqual(app.ocr(run.runId));
  expect(JSON.parse((await app.readFile(run.runId, 'scan-status.json')).toString()).run).toEqual(terminal);
  expect(await app.readImage(run.runId, app.ocr(run.runId).images[0].input!.assetId)).toEqual(png());
  const links = app.relatedLinks(run.runId); expect(links.candidates.some(candidate => candidate.links[0] === images[0].links[0])).toBe(true);
  links.candidates[0].links.push('mutated'); expect(JSON.stringify(app.relatedLinks(run.runId))).not.toContain('mutated');
});
it('joins multiple readable sources in source-kind order with immutable UTF16 ranges', async () => {
  const path = await root(); const before = await assets(path, 'before'); const img = await assets(path, 'img', 2);
  const images = [owner(before.imageId, '#banner', 'css_before'), owner(img.imageId)]; let calls = 0;
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: join(path, 'output'), crawl: imageCrawler(imagePage(images), [{ status: 'captured', assets: before }, { status: 'captured', assets: img }]),
    ocrOptions: { fetch: async () => ocrResponse('readable', ++calls === 1 ? '앞 🧾' : '이미지') } });
  const run = app.start(request); expect((await app.wait(run.runId)).state).toBe('completed');
  const detail = app.details(run.runId).details[0]; expect(detail.sourceIds).toEqual(['img','before']);
  expect(detail.sourceTextRanges).toEqual([{ imageId: 'img', rawStart: 0, rawEnd: 3 }, { imageId: 'before', rawStart: 4, rawEnd: 8 }]);
  expect(app.extraFindings(run.runId).findings[0].evidence_text).toBe('이미지\n앞 🧾'); expect(app.ocr(run.runId).images[0].text).toBe('앞 🧾');
});
it('shares completed OCR by PNG only within a run and preserves independent asset registrations and owner findings', async () => {
  const path = await root(); const captured = [await assets(path, 'one'), await assets(path, 'two')]; const images = [owner('one', '#one'), owner('two', '#two')]; const transport = vi.fn(async () => ocrResponse());
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: join(path, 'output'), crawl: imageCrawler(imagePage(images), captured.map(value => ({ status: 'captured', assets: value }))), ocrOptions: { fetch: transport } });
  const first = app.start(request); const done = await app.wait(first.runId); expect(done.state).toBe('completed'); expect(done.requestCounts).toEqual({ ocr: 1, clef: 2 });
  const records = app.ocr(first.runId).images; expect(records[1].cacheOf).toBe('one'); expect(records[1].attemptCount).toBe(0); expect(records[0].original!.assetId).not.toBe(records[1].original!.assetId);
  expect(app.extraFindings(first.runId).findings).toHaveLength(2);
  const second = app.start(request); await app.wait(second.runId); expect(transport).toHaveBeenCalledTimes(2); expect(app.get(first.runId)).toEqual(done);
});
it.each(['no_text','partial','unreadable'] as const)('keeps %s reading distinct from a CLEF negative without sending empty text', async status => {
  const path = await root(); const captured = await assets(path, 'reading'); const clef = vi.fn(positiveClef);
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: join(path, 'output'), crawl: imageCrawler(imagePage([owner('reading')]), [{ status: 'captured', assets: captured }]),
    aiOptions: { fetch: clef }, ocrOptions: { fetch: async () => ocrResponse(status, status === 'partial' ? '일부' : '') } });
  const run = app.start(request); const done = await app.wait(run.runId); expect(done.state).toBe(status === 'no_text' ? 'completed' : 'partial'); expect(clef).not.toHaveBeenCalled();
  expect(app.review(run.runId).candidates[0]).toMatchObject({ reason: status === 'no_text' ? 'OCR_NO_TEXT' : 'OCR_UNREADABLE', ai: null, evidenceText: '' });
  expect(app.ocr(run.runId).images[0]).toMatchObject({ status: 'completed', extractionStatus: status, confidence: null });
});
it('OCR off discovers excluded occurrences and acquires/transmits no originals while CLEF still analyzes DOM', async () => {
  const path = await root(); const ocr = vi.fn();
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: path, crawl: imageCrawler(imagePage([owner('excluded')], true), []), ocrOptions: { fetch: ocr } });
  const run = app.start({ ...request, ocrEnabled: false }); const done = await app.wait(run.runId); expect(done.state).toBe('completed'); expect(ocr).not.toHaveBeenCalled();
  expect(done.requestCounts).toEqual({ ocr: 0, clef: 1 }); expect(done.imageCounts).toMatchObject({ discovered: 1, captured: 0, skipped: 1 });
  expect(app.ocr(run.runId).images[0]).toMatchObject({ status: 'not_selected', original: null, input: null, model: null }); expect(app.review(run.runId).candidates).toEqual([]);
  expect(JSON.parse((await app.readFile(run.runId, 'result_extra.json')).toString()).findings).toEqual([]);
});
it('stops at the shared actual OCR cap while retaining a positive and all discovered unrequested occurrences', async () => {
  const path = await root(); const captured = [await assets(path, 'one'), await assets(path, 'two', 2), await assets(path, 'three', 3)];
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: join(path, 'output'), limits: { maxOcrRequests: 1 },
    crawl: imageCrawler(imagePage(captured.map(value => owner(value.imageId, '#' + value.imageId))), captured.map(value => ({ status: 'captured', assets: value }))), ocrOptions: { fetch: async () => ocrResponse() } });
  const run = app.start(request); const done = await app.wait(run.runId); expect(done.state).toBe('partial'); expect(done.requestCounts.ocr).toBe(1); expect(done.counts.extraConfirmedFindings).toBe(1);
  expect(app.ocr(run.runId).images.map(image => image.status)).toEqual(['completed','not_started','not_started']); expect(done.imageCounts.pending).toBe(2);
  expect(app.review(run.runId).candidates).toHaveLength(2); expect(app.ocr(run.runId).images[2].original).toBeNull();
});
it('an image resource limit stays local and an unsupported asset creates no fabricated review', async () => {
  const path = await root(); const captured = await assets(path, 'good');
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: join(path, 'output'), crawl: imageCrawler(imagePage([owner('large','#large'), owner('unsupported','#unsupported'), owner('good','#good')]),
    [{ status: 'error', reasonCode: 'RESOURCE_LIMIT', message: 'bytes limit' }, { status: 'unsupported', reasonCode: 'IMAGE_UNSUPPORTED', message: 'outside scope' }, { status: 'captured', assets: captured }]), ocrOptions: { fetch: async () => ocrResponse() } });
  const run = app.start(request); const done = await app.wait(run.runId); expect(done.state).toBe('partial'); expect(done.counts.extraConfirmedFindings).toBe(1); expect(done.requestCounts.ocr).toBe(1);
  expect(app.review(run.runId).candidates).toHaveLength(1); expect(app.review(run.runId).candidates[0].reason).toBe('NOT_ANALYZED');
  expect(app.ocr(run.runId).images.map(image => image.status)).toEqual(['not_started','unsupported','completed']);
});
it.each(['ocr','clef'] as const)('counts synchronous %s transport cancellation as one actual request and freezes all late responses', async provider => {
  const path = await root(); const captured = await assets(path, 'active'); let resolveLate!: (response: Response) => void; const late = new Promise<Response>(resolve => { resolveLate = resolve; });
  const transport: typeof fetch = () => { void app.cancel(app.activeRunId!); return late; };
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: join(path, 'output'), crawl: imageCrawler(imagePage([owner('active'),owner('pending','#pending')]), [{ status: 'captured', assets: captured }]),
    ocrOptions: { fetch: provider === 'ocr' ? transport : async () => ocrResponse() }, aiOptions: { fetch: provider === 'clef' ? transport : positiveClef } });
  const run = app.start(request); const done = await app.wait(run.runId); expect(done.state).toBe('cancelled'); expect(done.requestCounts[provider]).toBe(1); expect(done.counts.extraConfirmedFindings).toBe(0);
  const before = { run: app.get(run.runId), ocr: app.ocr(run.runId), review: app.review(run.runId), bytes: await app.readFile(run.runId,'ocr.json') };
  resolveLate(provider === 'ocr' ? ocrResponse() : await positiveClef('https://fixed.example')); await new Promise<void>(resolve => setImmediate(resolve));
  expect(app.get(run.runId)).toEqual(before.run); expect(app.ocr(run.runId)).toEqual(before.ocr); expect(app.review(run.runId)).toEqual(before.review); expect(await app.readFile(run.runId,'ocr.json')).toEqual(before.bytes);
  expect(app.ocr(run.runId).images[1].status).toBe('not_started'); if(provider === 'ocr') expect(app.ocr(run.runId).images[0].status).toBe('cancelled');
});
it('pre-request cancellation after asset registration starts no provider and freezes a not_started record', async () => {
  const path = await root(); const captured = await assets(path,'pre-request'); const store = new OutputStoreV2(join(path,'output'));
  const register = store.registerImageAssets.bind(store); vi.spyOn(store,'registerImageAssets').mockImplementation(async (...args) => { const result = await register(...args); void app.cancel(app.activeRunId!); return result; });
  const ocr = vi.fn(async () => ocrResponse()); const app = new InspectorApplication({ ...mockAnalysisOptions, outputStore: store, crawl: imageCrawler(imagePage([owner('pre-request')]), [{ status:'captured',assets:captured }]), ocrOptions:{fetch:ocr} });
  const run=app.start(request); const done=await app.wait(run.runId); expect(done.state).toBe('cancelled'); expect(ocr).not.toHaveBeenCalled(); expect(done.requestCounts).toEqual({ocr:0,clef:0});
  expect(app.ocr(run.runId).images[0]).toMatchObject({status:'not_started',reasonCode:'USER_CANCELLED',attemptCount:0});
});
it('OCR retry consumes actual cap and parser errors stay partial without exposing provider payload or keys', async () => {
  const path=await root(); const captured=await assets(path,'invalid'); let calls=0; const key='integration-private-placeholder';
  const app=new InspectorApplication({outputRoot:join(path,'output'),apiKey:key,crawl:imageCrawler(imagePage([owner('invalid')]),[{status:'captured',assets:captured}]),ocrOptions:{fetch:async()=>{calls++;return calls===1?new Response('',{status:429}):new Response(JSON.stringify({model:'alternate',private:key}));}}});
  const run=app.start(request);const done=await app.wait(run.runId);expect(done.state).toBe('partial');expect(done.requestCounts).toEqual({ocr:2,clef:0});expect(app.ocr(run.runId).images[0].reasonCode).toBe('OCR_RESPONSE_INVALID');
  for(const file of ['ocr.json','scan-status.json','review.json','finding-details.json'] as const) expect((await app.readFile(run.runId,file)).toString()).not.toContain(key);
  expect((await readFile(join(path,'output','runs',run.runId,'manifest.json'),'utf8'))).not.toContain(key);
});
it('integrates real Chromium collection, static PNG acquisition, OCR and CLEF with owner links and saved bytes', async () => {
  const { createServer } = await import('node:http'); const { createHash } = await import('node:crypto');
  const path=await root(); const http=createServer((req,res)=>{
    if(req.url?.endsWith('.png')) { res.writeHead(200,{'Content-Type':'image/png'});res.end(png());return; }
    res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});res.end('<a href="https://destination.example.test/owned"><div id="layers" style="background-image:url(/one.png),url(/two.png);width:20px;height:20px"><img id="graphic" src="/one.png" style="opacity:0"></div></a><p id="text" style="opacity:0">직접 원문</p>');
  });
  await new Promise<void>(resolve=>http.listen(0,'127.0.0.1',resolve)); const address=http.address(); if(!address||typeof address==='string') throw new Error('No listener');
  const entryUrl=`http://127.0.0.1:${address.port}`; const sent: {rawText:string;links:string[]}[]=[];
  try {
    const app=new InspectorApplication({...mockAnalysisOptions,outputRoot:join(path,'output'),crawlOptions:{dynamicWaitMs:0,resourceWaitMs:1000,scrollSteps:0,maxPages:1},ocrOptions:{fetch:async()=>ocrResponse('readable','그림 글자')},
      aiOptions:{fetch:async(endpoint,init)=>{sent.push(JSON.parse(init!.body as string).state);return positiveClef(endpoint,init);}}});
    const run=app.start({entryUrl,ocrEnabled:true,externalAnalysisConsent:true});const done=await app.wait(run.runId);expect(done.errors).toEqual([]);expect(done.state).toBe('completed');expect(done.counts).toMatchObject({confirmedFindings:1,extraConfirmedFindings:2});
    expect(done.imageCounts).toMatchObject({discovered:3,captured:3,ocrCompleted:3,pending:0});
    const imageCandidates=sent.filter(state=>state.rawText.includes('그림'));expect(imageCandidates).toHaveLength(2);expect(imageCandidates.every(state=>JSON.stringify(state.links)===JSON.stringify(['https://destination.example.test/owned']))).toBe(true);
    expect(sent.find(state=>state.rawText==='직접 원문')!.links).toEqual([]);
    const layer=app.extraFindings(run.runId).findings.find(finding=>finding.location==='#layers')!;expect(layer.evidence_text).toBe('그림 글자\n그림 글자');
    for(const record of app.ocr(run.runId).images){const bytes=await app.readImage(run.runId,record.input!.assetId);expect(createHash('sha256').update(bytes).digest('hex')).toBe(record.input!.sha256);expect(record.original!.sha256).toBe(createHash('sha256').update(png()).digest('hex'));}
  } finally {await new Promise<void>(resolve=>{http.close(()=>resolve());http.closeAllConnections();});}
},30000);
it('merges concurrent duplicate occurrence callbacks without repeating acquisition registration or requests', async () => {
  const path=await root();const captured=await assets(path,'duplicate');const metadata=owner('duplicate');const transport=vi.fn(async()=>ocrResponse());
  const base=imageCrawler(imagePage([metadata]),[{status:'captured',assets:captured}]);
  const app=new InspectorApplication({...mockAnalysisOptions,outputRoot:join(path,'output'),ocrOptions:{fetch:transport},crawl:async(entry,options={})=>{
    const original=options.images!.onImage;return base(entry,{...options,images:{...options.images!,onImage:async(image,result)=>{await Promise.all([original(image,result),original(structuredClone(image),structuredClone(result))]);}}});
  }});
  const run=app.start(request);const done=await app.wait(run.runId);expect(done.state).toBe('completed');expect(done.imageCounts.discovered).toBe(1);expect(done.requestCounts).toEqual({ocr:1,clef:1});expect(transport).toHaveBeenCalledTimes(1);
});
it('an OCR request timeout is local, retains failed reading review, and allows another safe image', async () => {
  const path=await root();const captured=[await assets(path,'slow'),await assets(path,'good',2)];let calls=0;
  const app=new InspectorApplication({...mockAnalysisOptions,outputRoot:join(path,'output'),crawl:imageCrawler(imagePage(captured.map(value=>owner(value.imageId,'#'+value.imageId))),captured.map(value=>({status:'captured',assets:value}))),
    ocrOptions:{requestTimeoutMs:10,fetch:async()=>{calls++;if(calls===1)return new Promise<Response>(()=>{});return ocrResponse();}}});
  const run=app.start(request);const done=await app.wait(run.runId);expect(done.state).toBe('partial');expect(done.requestCounts).toEqual({ocr:2,clef:1});expect(done.counts.extraConfirmedFindings).toBe(1);expect(app.ocr(run.runId).images[0].reasonCode).toBe('OCR_TIMEOUT');expect(app.review(run.runId).candidates[0].reason).toBe('OCR_ERROR');
});
it('asset storage failure fails the run and preserves the preceding archive/latest bytes', async () => {
  const path=await root();const captured=await assets(path,'stored');let fail=false;const store=new OutputStoreV2(join(path,'output'),{beforeOperation:operation=>{if(fail&&operation.operation==='write'&&operation.path.includes('/images/'))throw new Error('fixture storage failure');}});
  const app=new InspectorApplication({...mockAnalysisOptions,outputStore:store,crawl:imageCrawler(imagePage([owner('stored')]),[{status:'captured',assets:captured}]),ocrOptions:{fetch:async()=>ocrResponse()}});
  const first=app.start(request);expect((await app.wait(first.runId)).state).toBe('completed');const before=await app.readFile(first.runId,'result_extra.json');const latest=await readFile(join(path,'output','latest.json'));fail=true;
  const second=app.start(request);const done=await app.wait(second.runId);expect(done.state).toBe('failed');expect(done.errors.some(error=>error.code==='STORAGE_ERROR')).toBe(true);expect(done.requestCounts).toEqual({ocr:0,clef:0});
  expect(await app.readFile(first.runId,'result_extra.json')).toEqual(before);expect(await readFile(join(path,'output','latest.json'))).toEqual(latest);
  expect(JSON.parse((await app.readFile(second.runId,'scan-status.json')).toString())).toMatchObject({run:{state:'failed'},resultSaved:false,extraResultSaved:false});
});
