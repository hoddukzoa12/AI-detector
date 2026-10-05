import { createServer, type Server } from 'node:http';
import { readFile } from 'node:fs/promises';
import { assetTruth } from './ocr-truth.js';

export interface OcrFixtureRequest { origin: 'main' | 'external'; method: string; path: string }
export interface OcrFixtureSite {
  origin: string; externalOrigin: string;
  urls: { images: string; menu: string; exceptions: string };
  requests: OcrFixtureRequest[];
  stop(): Promise<void>;
}
const document = (body: string, style = '') => `<!doctype html><html lang="ko"><head><meta charset="utf-8"><title>Independent OCR fixture</title><style>body{font-family:"Noto Sans CJK KR"}img{width:320px;height:80px}.surface{width:320px;height:80px}#pseudo::before,#pseudo::after,#multi::before,#multi::after{content:"";display:block;width:320px;height:80px;background-size:contain}#pseudo::before,#multi::before{background-image:url('/assets/general.png')}#pseudo::after,#multi::after{background-image:url('/assets/notice.png')}${style}</style></head><body>${body}</body></html>`;
const attribute = (value: string) => value.replaceAll('&', '&amp;').replaceAll('"', '&quot;');
function listen(server: Server, host: string): Promise<string> {
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, host, () => {
      server.removeListener('error', reject);
      const address = server.address();
      if (!address || typeof address === 'string') { reject(new Error('TCP address required')); return; }
      resolve(`http://${host === '::' ? 'localhost' : host}:${address.port}`);
    });
  });
}
function close(server: Server): Promise<void> {
  return new Promise((resolve, reject) => {
    server.close(error => error ? reject(error) : resolve()); server.closeAllConnections();
  });
}
/** Local ephemeral servers only. External hostname is distinct and requests remain observable. */
export async function startOcrFixtureSite(): Promise<OcrFixtureSite> {
  const requests: OcrFixtureRequest[] = [];
  const assets = new Map(await Promise.all(assetTruth.map(async item => [item.file, { bytes: await readFile(new URL(`./ocr-assets/${item.file}`, import.meta.url)), mime: item.mime }] as const)));
  const malformed = await readFile(new URL('./ocr-assets/malformed.png', import.meta.url));
  const documents = new Map<string, string>();
  const handler = (origin: OcrFixtureRequest['origin']) => createServer((request, response) => {
    const path = request.url ?? '/'; const method = request.method ?? 'GET';
    requests.push({ origin, path, method });
    if (!['GET', 'HEAD'].includes(method)) { response.writeHead(405, { allow: 'GET, HEAD' }).end(); return; }
    if (path === '/exceptions/unavailable.png') { response.writeHead(503).end(); return; }
    if (path === '/exceptions/decode.png') { response.writeHead(200, { 'content-type': 'image/png' }).end(method === 'HEAD' ? undefined : malformed); return; }
    const asset = path.startsWith('/assets/') ? assets.get(path.slice('/assets/'.length)) : undefined;
    if (asset) { response.writeHead(200, { 'content-type': asset.mime, 'cache-control': 'no-store', 'access-control-allow-origin': '*' }).end(method === 'HEAD' ? undefined : asset.bytes); return; }
    const html = documents.get(`${origin}:${path}`);
    if (!html) { response.writeHead(404).end('No fixture'); return; }
    response.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' }).end(method === 'HEAD' ? undefined : html);
  });
  const main = handler('main'); const external = handler('external');
  let origin: string; let externalOrigin: string;
  try { origin = await listen(main, '127.0.0.1'); externalOrigin = await listen(external, '::'); }
  catch (error) { if (main.listening) await close(main); if (external.listening) await close(external); throw error; }
  const image = (id: string, file: string, extra = '') => `<img id="${id}" src="/assets/${file}" alt="" ${extra}>`;
  documents.set('main:/images', document(`
    ${['korean','english','logo','cover','general','article','notice','no-text','unreadable'].map(id => image(id, id + '.png')).join('')}
    <picture><source media="(min-width:1px)" srcset="/assets/korean.png 1x"><img id="selected" src="/assets/logo.png" alt=""></picture>
    <div id="layers" class="surface" style="background-image:url('/assets/korean.png'),linear-gradient(red,blue),url('/assets/english.png')"></div>
    <div id="pseudo" class="surface"></div><img id="data" alt=""><img id="blob" alt="">
    ${image('svg','vector.svg')}${image('animation','animated.gif')}${image('jpeg','korean.jpg')}${image('webp','general.webp')}${image('avif','logo.avif')}
    ${image('transparent','korean.png','style="opacity:0"')}${image('hidden','english.png','style="display:none"')}${image('outside-image','korean.png','style="position:absolute;left:-9999px"')}
    ${image('same-a','korean.png')}${image('same-b','korean.png')}<a href="/destination">${image('linked','korean.png')}</a>
    ${image('multi','korean.png','style="background-image:url(\'/assets/english.png\')"')}
    <div id="mixed" class="surface" style="opacity:0;background-image:url('/assets/korean.png')">불법 온라인 카지노 가입 배팅 보너스</div>
    <img id="external-asset" src="${externalOrigin}/assets/english.png" alt="">
    <iframe id="shared-a" src="/frames/shared"></iframe><iframe id="shared-b" src="/frames/shared"></iframe>
    <iframe id="external" src="${externalOrigin}/frames/external"></iframe>
    <iframe id="inline" srcdoc="${attribute(document(image('frame-image','logo.png')))}"></iframe><iframe id="blank"></iframe>
    <a href="${externalOrigin}/outside">Excluded external navigation</a>
    <script>(async()=>{
      const png=await(await fetch('/assets/korean.png')).blob();
      const reader=new FileReader();await new Promise(resolve=>{reader.onload=resolve;reader.readAsDataURL(png)});document.querySelector('#data').src=reader.result;
      document.querySelector('#blob').src=URL.createObjectURL(await(await fetch('/assets/english.png')).blob());
      const frame=document.querySelector('#blank');frame.contentDocument.body.innerHTML='<img id="frame-image" src="${origin}/assets/cover.png" alt="">';
      await Promise.all(Array.from(document.images).map(image=>image.decode().catch(()=>{})));document.body.dataset.ready='true';
    })()</script>`));
  documents.set('main:/exceptions', document('<img id="decode-failure" src="/exceptions/decode.png"><img id="missing-image" src="/exceptions/missing.png"><img id="unavailable-image" src="/exceptions/unavailable.png">'));
  documents.set('main:/frames/shared', document(image('frame-image','korean.png')));
  documents.set('external:/frames/external', document(`${image('frame-image','english.png')}<iframe id="nested" src="./nested"></iframe><a href="/outside">Not a visit target</a>`));
  documents.set('external:/frames/nested', document(image('frame-image','notice.png')));
  const text = '불법 온라인 카지노 가입 배팅 보너스';
  const menus = Array.from({ length: 11 }, (_, index) => `<aside id="sidebar-${index}" style="display:none"><h5 class="sidebar-title" id="member-${index}">MEMBER</h5><a href="/register">회원가입</a><h5 class="sidebar-title" id="menu-${index}">MENU</h5><a href="/destination">토토</a><a href="/contact">문의</a></aside>`).join('');
  documents.set('main:/menu', document(`${menus}<a href="/destination"><span id="nearby-ad" style="opacity:0">${text}</span></a><a href="/destination"><div id="direct-parent" style="opacity:0">${text}<span id="direct-child">${text}</span></div></a><a href="/destination"><div id="tiny-parent" style="font-size:0">${text}<span id="tiny-child">${text}</span></div></a><div id="aggregate"><span>일반 안내</span></div>`));
  let stopped = false;
  return { origin, externalOrigin, urls: { images: origin + '/images', menu: origin + '/menu', exceptions: origin + '/exceptions' }, requests,
    async stop() { if (stopped) return; stopped = true; await Promise.all([close(main), close(external)]); },
  };
}
