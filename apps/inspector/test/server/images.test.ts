import { afterEach, expect, it } from 'vitest';
import { mkdtemp, rm, writeFile, symlink, unlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { InspectorApplication } from '../../src/application/index.js';
import { startServer, type InspectorServer } from '../../src/server/index.js';
import { assets, imageCrawler, imagePage, imageUrl, ocrResponse, owner, png } from '../application/image-fixture.js';
import { mockAnalysisOptions, positiveClef } from '../application/mock-transport.js';
let server: InspectorServer | undefined; const roots: string[] = [];
afterEach(async () => { await server?.close(); server = undefined; await Promise.all(roots.splice(0).map(root => rm(root, { recursive: true, force: true }))); });
async function root() { const path = await mkdtemp(join(tmpdir(), 'png-api-')); roots.push(path); return path; }
it('authenticates active and archived PNGs, verifies hash/path/symlink, and rejects original or cross-run assets', async () => {
  const path = await root(); const captured = await assets(path, 'source');
  let entered!: () => void; const running = new Promise<void>(resolve => { entered = resolve; }); let release!: () => void; const gate = new Promise<void>(resolve => { release = resolve; });
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: join(path,'output'), crawl: imageCrawler(imagePage([owner('source')]), [{status:'captured',assets:captured}]),
    ocrOptions: { fetch: async () => ocrResponse() }, aiOptions: { fetch: async (...args) => { entered(); await gate; return positiveClef(...args); } } });
  server = await startServer({ application: app, cwd: path, port: 0, publicDir: path }); const headers = { Authorization: `Bearer ${server.sessionToken}` };
  try {
    const response = await fetch(server.url+'/api/runs', { method:'POST', headers, body:JSON.stringify({entryUrl:imageUrl,ocrEnabled:true,externalAnalysisConsent:true}) });
    expect(response.status).toBe(202); const { runId } = await response.json() as {runId:string}; await running;
    const base = server.url+'/api/runs/'+runId; const record=app.ocr(runId).images[0]; const route=base+'/images/'+record.input!.assetId;
    expect((await fetch(route)).status).toBe(401); expect((await fetch(route,{headers:{...headers,Origin:'https://foreign.example'}})).status).toBe(403);
    const active=await fetch(route,{headers}); expect(active.status).toBe(200); expect(active.headers.get('content-type')).toBe('image/png'); expect(active.headers.get('x-content-type-options')).toBe('nosniff'); expect(Buffer.from(await active.arrayBuffer())).toEqual(png());
    expect((await fetch(base+'/images/'+record.original!.assetId,{headers})).status).toBe(404); expect((await fetch(base+'/images/%2e%2e%2fsecret',{headers})).status).toBe(400);
    expect((await fetch(base+'/images/unknown',{headers})).status).toBe(404); expect((await fetch(base+'/images/'+record.input!.assetId+'?url=https://foreign.example',{headers})).status).toBe(400);
    release(); expect((await app.wait(runId)).state).toBe('completed');
    for(const [routeName,file] of [['ocr','ocr.json'],['extra-findings','result_extra.json']] as const) {
      const json=await (await fetch(base+'/'+routeName,{headers})).json(); const saved=JSON.parse((await app.readFile(runId,file)).toString());
      expect(routeName==='ocr'?json:(json as {findings:unknown}).findings).toEqual(routeName==='ocr'?saved:saved.findings);
      expect((await fetch(base+'/files/'+file,{headers})).status).toBe(200);
    }
    expect(await (await fetch(base+'/related-links',{headers})).json()).toEqual(app.relatedLinks(runId));
    const archive=await fetch(route,{headers}); expect(Buffer.from(await archive.arrayBuffer())).toEqual(png());
    const second=app.start({entryUrl:imageUrl,ocrEnabled:true,externalAnalysisConsent:true}); await app.wait(second.runId);
    expect((await fetch(server.url+'/api/runs/'+second.runId+'/images/'+record.input!.assetId,{headers})).status).toBe(404);
    const registeredPath=join(path,'output',record.input!.path!); await writeFile(registeredPath,Buffer.concat([png(),Buffer.from([0])])); expect((await fetch(route,{headers})).status).toBe(404);
    await unlink(registeredPath); await symlink(captured.input.scratchPath,registeredPath); expect((await fetch(route,{headers})).status).toBe(404);
    await unlink(registeredPath); await writeFile(registeredPath,png()); expect((await fetch(route,{headers})).status).toBe(200);
  } finally { release(); }
});
it('rejects legacy/consent/extra provider inputs and missing keys before creating runs', async () => {
  const path=await root(); server=await startServer({cwd:path,port:0,outputRoot:join(path,'output'),apiKey:''});
  const headers={Authorization:`Bearer ${server.sessionToken}`}; const send=(input:unknown)=>fetch(server!.url+'/api/runs',{method:'POST',headers,body:JSON.stringify(input)});
  for(const input of [{entryUrl:imageUrl,aiEnabled:false},{entryUrl:imageUrl,ocrEnabled:false},{entryUrl:imageUrl,ocrEnabled:false,externalAnalysisConsent:false},{entryUrl:imageUrl,ocrEnabled:false,externalAnalysisConsent:true,endpoint:'https://override.example'}]) {
    const response=await send(input); expect(response.status).toBe(400); expect(await response.json()).toMatchObject({error:{code:'INVALID_REQUEST'}});
  }
  const response=await send({entryUrl:imageUrl,ocrEnabled:false,externalAnalysisConsent:true}); expect(response.status).toBe(400); expect(await response.json()).toMatchObject({error:{code:'INVALID_CONFIG'}});
  expect(server.application.activeRunId).toBeNull();
  const config=await (await fetch(server.url+'/api/config',{headers})).json(); expect(config).toMatchObject({aiRequired:true,ocrModel:'google/gemini-3.8-flash'}); expect(Object.keys(config)).not.toContain('apiKey');
});
