import { mockAnalysisOptions } from '../application/mock-transport.js';
import { afterEach, expect, it } from 'vitest';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { request } from 'node:http';
import { startServer, type InspectorServer } from '../../src/server/index.js';
let server: InspectorServer | undefined; let root: string | undefined;
afterEach(async () => { await server?.close(); server = undefined; if(root) await rm(root,{recursive:true,force:true}); });
it('protects API token/origin/host and injects safe bootstrap with CSP', async () => {
  root=await mkdtemp(join(tmpdir(),'server-')); await writeFile(join(root,'index.html'),'<main id="app"></main><script src="/web.js" defer></script>');
  server=await startServer({port:0,publicDir:root, outputRoot:join(root,'output')});
  const auth={Authorization:`Bearer ${server.sessionToken}`};
  expect((await fetch(server.url+'/api/config')).status).toBe(401);
  expect((await fetch(server.url+'/api/config',{headers:auth})).status).toBe(200);
  expect((await fetch(server.url+'/api/config',{headers:{...auth,Origin:'https://foreign.invalid'}})).status).toBe(403);
  expect(await new Promise<number>(resolve => { const req = request(server!.url+'/api/config', { headers: {...auth, Host:'evil.invalid'} }, res => { res.resume(); resolve(res.statusCode!); }); req.end(); })).toBe(403);
  const html=await fetch(server.url); expect(html.headers.get('content-security-policy')).toContain("frame-ancestors 'none'"); expect(await html.text()).toContain('__INSPECTOR_BOOTSTRAP__');
  expect((await fetch(server.url+'/api/runs',{method:'POST',headers:auth,body:'{'})).status).toBe(400);
});
it('uses exact protected artifact routes through a real browser crawl and saved bytes', async () => {
  const { InspectorApplication } = await import('../../src/application/index.js');
  const { startFixtureSite } = await import('../fixtures/site.js');
  const fixture = await startFixtureSite();
  try {
    root = await mkdtemp(join(tmpdir(), 'http-smoke-')); await writeFile(join(root, 'index.html'), '<main id="app"></main><script src="/web.js" defer></script>');
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: join(root, 'output'), crawlOptions: { dynamicWaitMs: 0, resourceWaitMs: 0, scrollSteps: 0 } });
    server = await startServer({ port: 0, publicDir: root, application: app });
    const headers = { Authorization: `Bearer ${server.sessionToken}`, 'Content-Type': 'application/json' };
    const runResponse = await fetch(server.url + '/api/runs', { method: 'POST', headers, body: JSON.stringify({ entryUrl: fixture.urls.types, ocrEnabled: false, externalAnalysisConsent: true }) });
    expect(runResponse.status).toBe(202); const run = await runResponse.json() as { runId: string }; const base = server.url + '/api/runs/' + run.runId;
    expect((await fetch(server.url + '/api/runs', { method: 'POST', headers, body: JSON.stringify({ entryUrl: fixture.urls.types, ocrEnabled: false, externalAnalysisConsent: true }) })).status).toBe(409);
    const terminal = await app.wait(run.runId); expect(terminal.state).toBe('completed');
    expect(await (await fetch(base, { headers })).json()).toEqual(terminal);
    const findings = await (await fetch(base + '/findings', { headers })).json() as { runId: string; findings: unknown[] };
    const details = await (await fetch(base + '/finding-details', { headers })).json() as { details: { evidence: { snapshotId: string } }[] };
    const review = await (await fetch(base + '/review', { headers })).json() as { runId: string };
    expect(findings.runId).toBe(run.runId); expect(review.runId).toBe(run.runId); expect(details.details).toHaveLength(findings.findings.length);
    const resultResponse = await fetch(base + '/files/result.json', { headers }); expect(Buffer.from(await resultResponse.arrayBuffer())).toEqual(await app.readFile(run.runId, 'result.json'));
    const evidenceId = details.details[0].evidence.snapshotId;
    const evidence = await fetch(base + '/evidence/' + evidenceId, { headers }); expect(evidence.status).toBe(200); expect(await evidence.json()).toEqual(expect.objectContaining({ snapshotId: evidenceId, topPageUrl: fixture.urls.types }));
    expect((await fetch(base + '/evidence/unknown_snapshot', { headers })).status).toBe(404);
    expect((await fetch(base + '/files/.env', { headers })).status).toBe(404);
    expect((await fetch(base + '/files/result.json/more', { headers })).status).toBe(404);
    expect((await fetch(base + '/evidence/%2e%2e%2fsecret', { headers })).status).toBe(400);
    expect((await fetch(base + '/cancel', { method: 'POST', headers, body: '{}' })).status).toBe(200);
  } finally { await fixture.stop(); }
}, 30000);
it('rejects invalid and oversized input before creating a run and exposes no key', async () => {
  root = await mkdtemp(join(tmpdir(), 'input-')); server = await startServer({ port: 0, publicDir: root, outputRoot: join(root, 'output'), apiKey: 'test-private-value' });
  const headers = { Authorization: `Bearer ${server.sessionToken}` };
  const send = (data: string) => fetch(server!.url + '/api/runs', { method: 'POST', headers, body: data });
  expect((await send('{')).status).toBe(400); expect((await send(' '.repeat(20000))).status).toBe(400);
  expect((await send(JSON.stringify({ entryUrl: 'file:///secret', ocrEnabled: false, externalAnalysisConsent: true }))).status).toBe(400);
  expect((await send(JSON.stringify({ entryUrl: 'https://public.test', ocrEnabled: false, externalAnalysisConsent: true, apiKey: 'override' }))).status).toBe(400);
  expect(server.application.activeRunId).toBe(null);
  const config = await fetch(server.url + '/api/config', { headers }); expect(await config.text()).not.toContain('test-private-value'); expect(config.headers.has('access-control-allow-origin')).toBe(false);
  expect((await fetch(server.url + '/api/runs/missing', { headers })).status).toBe(404);
});
it('escapes bootstrap strings and denies cross-site root and symlink static escapes', async () => {
  const { symlink } = await import('node:fs/promises');
  root = await mkdtemp(join(tmpdir(), 'escape-')); await writeFile(join(root, 'index.html'), '<script src="/web.js" defer></script>');
  await symlink('/etc/passwd', join(root, 'web.js')); await writeFile(join(root, 'web.css'), 'body{}');
  server = await startServer({ port: 0, publicDir: root, outputRoot: join(root, 'out</script>&\u2028\u2029') });
  const response = await fetch(server.url); const html = await response.text();
  expect(html).toContain('\\u003c/script\\u003e'); expect(html).toContain('\\u0026'); expect(html).toContain('\\u2028'); expect(html).toContain('\\u2029');
  expect(response.headers.get('cache-control')).toBe('no-store'); expect(response.headers.get('content-security-policy')).toContain("script-src 'self' 'nonce-");
  expect((await fetch(server.url, { headers: { 'Sec-Fetch-Site': 'cross-site' } })).status).toBe(403);
  expect((await fetch(server.url + '/web.js')).status).toBe(403); expect((await fetch(server.url + '/web.css')).status).toBe(200);
  expect((await fetch(server.url + '/unknown.js')).status).toBe(404);
  expect((await fetch(server.url + '/api/config?token=' + server.sessionToken)).status).toBe(400);
});
it('active HTTP cancel returns 202 and close waits for cancellation save', async () => {
  const { InspectorApplication } = await import('../../src/application/index.js');
  const { emptyRunCounts } = await import('../../src/core/index.js');
  root = await mkdtemp(join(tmpdir(), 'http-cancel-'));
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: join(root, 'output'), crawl: async (entry, options = {}) => {
    await new Promise<void>(resolve => { if(options.signal!.aborted) resolve(); else options.signal!.addEventListener('abort', () => resolve(), { once: true }); });
    return { state: 'cancelled', pages: [], errors: [], counts: { ...emptyRunCounts(), discoveredPages: 1, pendingPages: 1 }, scope: { hostname: new URL(entry).hostname, framePolicy: 'embedded', skipped: [], unvisitedUrls: [entry] } };
  } });
  server = await startServer({ port: 0, publicDir: root, application: app });
  const headers = { Authorization: `Bearer ${server.sessionToken}` };
  const response = await fetch(server.url + '/api/runs', { method: 'POST', headers, body: JSON.stringify({ entryUrl: 'https://public.test', ocrEnabled: false, externalAnalysisConsent: true }) });
  const run = await response.json() as { runId: string };
  const cancel = await fetch(server.url + '/api/runs/' + run.runId + '/cancel', { method: 'POST', headers, body: '{}' }); expect(cancel.status).toBe(202);
  await server.close(); expect((await app.wait(run.runId)).state).toBe('failed');
  expect(JSON.parse((await app.readFile(run.runId, 'scan-status.json')).toString()).run.state).toBe('failed');
});
it('returns a JSON 400 for a chunked oversized request without starting work', async () => {
  root = await mkdtemp(join(tmpdir(), 'chunked-')); server = await startServer({ port: 0, outputRoot: join(root, 'output') });
  const code = await new Promise<number>((resolve, reject) => {
    const req = request(server!.url + '/api/runs', { method: 'POST', headers: { Authorization: `Bearer ${server!.sessionToken}`, 'Transfer-Encoding': 'chunked' } }, response => { response.resume(); resolve(response.statusCode!); });
    req.once('error', reject); req.write(' '.repeat(17000)); req.end(' ');
  });
  expect(code).toBe(400); expect(server.application.activeRunId).toBe(null);
});
