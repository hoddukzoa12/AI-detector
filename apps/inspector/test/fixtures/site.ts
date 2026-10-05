import { createServer, type IncomingMessage, type Server, type ServerResponse } from 'node:http';
import { findingTruth, negativeTruth, type FindingTruth } from './truth.js';

export interface FixtureRequest { origin: 'main' | 'external'; method: string; path: string }
export interface ResolvedFindingTruth extends FindingTruth { url: string; location: string }
export interface FixtureSite {
  origin: string;
  externalOrigin: string;
  urls: Record<'entry' | 'types' | 'negatives' | 'frames' | 'queryOne' | 'queryTwo' | 'redirect' | 'login' | 'failure' | 'write' | 'loading' | 'never' | 'dynamic', string>;
  expectedFindings: ResolvedFindingTruth[];
  negativeCases: typeof negativeTruth;
  requests: FixtureRequest[];
  stop(): Promise<void>;
}

function page(body: string, title = 'Inspection fixture'): string {
  return `<!doctype html><html lang="ko"><head><meta charset="utf-8"><title>${title}</title></head><body>${body}</body></html>`;
}
function escapeAttribute(value: string): string { return value.replaceAll('&', '&amp;').replaceAll('"', '&quot;'); }
function listen(server: Server, host: string): Promise<string> {
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, host, () => {
      server.removeListener('error', reject);
      const address = server.address();
      if (!address || typeof address === 'string') { reject(new Error('Fixture needs TCP address')); return; }
      resolve(`http://${host === '::' ? 'localhost' : host}:${address.port}`);
    });
  });
}
function close(server: Server): Promise<void> {
  return new Promise((resolve, reject) => {
    server.close(error => error ? reject(error) : resolve());
    server.closeAllConnections();
  });
}

/** Binds only ephemeral test ports; external hostname differs even though both origins are local. */
export async function startFixtureSite(): Promise<FixtureSite> {
  const requests: FixtureRequest[] = [];
  let origin = '';
  let externalOrigin = '';
  const documents = new Map<string, string>();
  const handler = (kind: 'main' | 'external') => (request: IncomingMessage, response: ServerResponse) => {
    const path = request.url ?? '/';
    requests.push({ origin: kind, method: request.method ?? 'GET', path });
    if (!['GET', 'HEAD'].includes(request.method ?? 'GET')) {
      response.writeHead(405, { 'content-type': 'text/plain', allow: 'GET, HEAD' }).end('Fixture write prevented'); return;
    }
    if (path === '/never') return; // Intentionally unresolved: cancellation/limits must handle it.
    if (path === '/redirect') { response.writeHead(302, { location: externalOrigin + '/outside' }).end(); return; }
    if (path === '/failure') { response.writeHead(503, { 'content-type': 'text/plain' }).end('Deliberate navigation failure'); return; }
    const html = documents.get(`${kind}:${path}`);
    if (html === undefined) { response.writeHead(404).end('Fixture page not found'); return; }
    response.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
    response.end(request.method === 'HEAD' ? undefined : html);
  };
  const mainServer = createServer(handler('main'));
  const externalServer = createServer(handler('external'));
  try {
    origin = await listen(mainServer, '127.0.0.1');
    externalOrigin = await listen(externalServer, '::');
  } catch (error) {
    if (mainServer.listening) await close(mainServer);
    if (externalServer.listening) await close(externalServer);
    throw error;
  }
  const text = (caseId: string) => {
    const item = findingTruth.find(item => item.caseId === caseId);
    if (!item) throw new Error(`Missing fixture truth: ${caseId}`);
    return item.rawEvidence;
  };
  // Explicit markup, not a production-derived transform. Each raw fixture string is preserved.
  documents.set('main:/cases/types', page(`
    <p id="homo-cyrillic">${text('homo-cyrillic')}</p>
    <p id="homo-number">${text('homo-number')}</p>
    <p id="jamo">${text('jamo')}</p><p id="jamo-modern">${text('jamo-modern')}</p>
    <p id="opacity" style="opacity:0">${text('opacity')}</p>
    <p id="transparent" style="color:transparent">${text('transparent')}</p>
    <p id="same-color" style="color:rgb(255,255,255);background-color:rgb(255,255,255)">${text('same-color')}</p>
    <section style="opacity:0"><p id="ancestor-child">${text('ancestor')}</p></section>
    <p id="zero-font" style="font-size:0">${text('zero-font')}</p>
    <p id="one-font" style="font-size:1px">${text('one-font')}</p>
    <p id="display-none" style="display:none">${text('display-none')}</p>
    <p id="left-outside" style="position:absolute;left:-9999px">${text('left-outside')}</p>
    <p id="long-tail" style="opacity:0">${text('long-tail')}</p>
    <p id="combined" style="opacity:0;font-size:0">${text('combined')}</p>
    <p id="duplicate-a" style="opacity:0">${text('duplicate-a')}</p><p id="duplicate-b" style="opacity:0">${text('duplicate-b')}</p>`));
  documents.set('main:/cases/negatives', page(`
    <p id="news">${negativeTruth[0].rawEvidence}</p><p id="numbers">${negativeTruth[1].rawEvidence}</p>
    <p id="jamo-explanation">${negativeTruth[2].rawEvidence}</p>
    <a id="accessibility" href="#below-fold" style="position:absolute;left:-9999px;font-size:1px">${negativeTruth[3].rawEvidence}</a>
    <div style="height:2200px">정상적인 긴 페이지</div><p id="below-fold">${negativeTruth[4].rawEvidence}</p>`));
  documents.set('main:/query?id=1', page(`<p id="query-one" style="opacity:0">${text('query-one')}</p>`));
  documents.set('main:/query?id=2', page(`<p id="query-two" style="opacity:0">${text('query-two')}</p>`));
  documents.set('main:/cases/frames', page(`
    <iframe src="${externalOrigin}/frames/external" title="external"></iframe>
    <iframe src="../frames/relative" title="relative"></iframe>
    <iframe id="shared-a" src="/frames/shared" title="shared a"></iframe>
    <iframe id="shared-b" src="/frames/shared" title="shared b"></iframe>
    <iframe id="unavailable-frame" src="/failure" title="unavailable"></iframe>
    <iframe id="inline-frame" title="srcdoc" srcdoc="${escapeAttribute(page(`<p id="srcdoc-ad" style="opacity:0">${text('frame-srcdoc')}</p>`))}"></iframe>`));
  documents.set('external:/frames/external', page(`<p id="external-ad" style="opacity:0">${text('frame-external')}</p><iframe src="./nested" title="nested"></iframe><a href="/outside">Do not crawl external link</a>`));
  documents.set('external:/frames/nested', page(`<p id="nested-ad" style="display:none">${text('frame-nested')}</p>`));
  documents.set('main:/frames/relative', page(`<p id="relative-ad" style="opacity:0">${text('frame-relative')}</p>`));
  documents.set('main:/frames/shared', page(`<p id="shared-ad" style="opacity:0">${text('frame-shared-a')}</p>`));
  documents.set('external:/outside', page('<p>External page must not be crawled</p>'));
  documents.set('main:/login', page('<form action="/write" method="post"><label>Password<input type="password" name="password"></label><button>Log in</button></form>', '로그인'));
  documents.set('main:/write', page('<form action="/write" method="post"><input name="message"><button>Write</button></form><script>fetch("/write",{method:"POST",body:"must-be-blocked"}).catch(()=>{});</script>'));
  documents.set('main:/loading', page('<p id="loading-content">The DOM is available while one resource stays pending.</p><script>fetch("/never").catch(()=>{});</script>'));
  documents.set('main:/dynamic', page('<p>Dynamic public content</p><script>setTimeout(()=>{const a=document.createElement("a");a.id="dynamic-link";a.href="/query?id=2";a.textContent="Dynamic query page";document.body.append(a)},50);</script>'));
  documents.set('main:/', page(`
    <a href="/cases/types">Four types</a><a href="/cases/negatives">Negative cases</a><a href="/cases/frames">Frames</a>
    <a href="/query?id=1">Query one</a><a href="/query?id=2">Query two</a><a href="/query?id=1">Duplicate link</a>
    <a href="/redirect">External redirect</a><a href="${externalOrigin}/outside">External link</a>
    <a href="/login">Login</a><a href="/failure">Access failure</a><a href="/write">Write guard</a>
    <a href="/loading">Never-ending resource</a><a href="/dynamic">Dynamic link</a>`));
  const urls = {
    entry: origin + '/', types: origin + '/cases/types', negatives: origin + '/cases/negatives', frames: origin + '/cases/frames',
    queryOne: origin + '/query?id=1', queryTwo: origin + '/query?id=2', redirect: origin + '/redirect', login: origin + '/login',
    failure: origin + '/failure', write: origin + '/write', loading: origin + '/loading', never: origin + '/never', dynamic: origin + '/dynamic',
  };
  const expectedFindings = findingTruth.map(item => ({
    ...item, url: origin + item.pagePath,
    location: [...item.framePath.map(step => step.replaceAll('{origin}', origin).replaceAll('{external}', externalOrigin)), item.selector].join(' >>> '),
  }));
  let stopped = false;
  return { origin, externalOrigin, urls, expectedFindings, negativeCases: negativeTruth, requests,
    async stop() { if (stopped) return; stopped = true; await Promise.all([close(mainServer), close(externalServer)]); },
  };
}
