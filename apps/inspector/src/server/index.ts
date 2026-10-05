/** Local HTTP boundary: session authentication, origin/Host checks and registered artifact routes. */
import { randomBytes, timingSafeEqual } from 'node:crypto';
import { createServer, type IncomingMessage, type ServerResponse } from 'node:http';
import { readFile, realpath } from 'node:fs/promises';
import { resolve, relative, isAbsolute } from 'node:path';
import { InspectorApplication, loadRuntimeConfig, type RuntimeConfig, type RuntimeMode } from '../application/index.js';
import { ContractError, isTerminalState, validateStartRunRequestV2, type ApiErrorCode } from '../core/index.js';
import { OUTPUT_FILE_NAMES_V2, type OutputFileNameV2 } from '../output/index.js';
export interface StartServerOptions {
  config?: RuntimeConfig; application?: InspectorApplication; mode?: RuntimeMode; cwd?: string; exePath?: string;
  host?: string; port?: number; publicDir?: string; outputRoot?: string; apiKey?: string; executablePath?: string;
}
export interface InspectorServer { url: string; port: number; sessionToken: string; application: InspectorApplication; close(): Promise<void> }
const statuses: Record<ApiErrorCode, number> = { INVALID_URL: 400, INVALID_CONFIG: 400, INVALID_REQUEST: 400,
  UNAUTHORIZED: 401, FORBIDDEN: 403, NOT_FOUND: 404, ACTIVE_RUN: 409 };
function json(response: ServerResponse, status: number, value: unknown): void {
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' }); response.end(JSON.stringify(value));
}
function reject(code: ApiErrorCode, message: string): never { throw new ContractError(code, message); }
function identifier(value: string): string {
  let decoded: string; try { decoded = decodeURIComponent(value); } catch { return reject('INVALID_REQUEST', 'Invalid identifier'); }
  if (!/^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$/.test(decoded)) reject('INVALID_REQUEST', 'Invalid identifier'); return decoded;
}
async function body(request: IncomingMessage): Promise<unknown> {
  const length = request.headers['content-length'];
  if (length && (!/^\d+$/.test(length) || Number(length) > 16384)) { request.resume(); reject('INVALID_REQUEST', 'Request body too large'); }
  let size = 0; const chunks: Buffer[] = [];
  for await (const chunk of request.iterator({ destroyOnReturn: false })) {
    const bytes = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk as Uint8Array); size += bytes.length;
    if (size > 16384) { request.resume(); reject('INVALID_REQUEST', 'Request body too large'); } chunks.push(bytes);
  }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')) as unknown; }
  catch { return reject('INVALID_REQUEST', 'Invalid JSON body'); }
}
function escapedJson(value: unknown): string { return JSON.stringify(value).replace(/[<>&\u2028\u2029]/g, char => `\\u${char.charCodeAt(0).toString(16).padStart(4, '0')}`); }
function sameToken(header: string | undefined, token: string): boolean {
  const expected = Buffer.from(`Bearer ${token}`), actual = Buffer.from(header ?? ''); return expected.length === actual.length && timingSafeEqual(expected, actual);
}
/** Returns a private token only to the Node caller and the same-origin bootstrap HTML. */
export async function startServer(options: StartServerOptions = {}): Promise<InspectorServer> {
  const config = options.config ?? await loadRuntimeConfig({ mode: options.mode, cwd: options.cwd, exePath: options.exePath });
  const host = options.host ?? config.host; const port = options.port ?? config.port;
  if (!['127.0.0.1', 'localhost', '::1', '0.0.0.0'].includes(host) || (host === '0.0.0.0' && config.mode !== 'docker')) reject('INVALID_CONFIG', 'Invalid bind host');
  if (!Number.isInteger(port) || port < 0 || port > 65535) reject('INVALID_CONFIG', 'Invalid port');
  const app = options.application ?? new InspectorApplication({ outputRoot: options.outputRoot ?? config.outputRoot,
    apiKey: options.apiKey ?? config.apiKey, executablePath: options.executablePath ?? config.executablePath, limits: config.limits });
  const publicDir = resolve(options.publicDir ?? resolve(options.cwd ?? process.cwd(), 'dist/public'));
  const token = randomBytes(32).toString('base64url'); let actualPort = 0; let closing = false;
  const acceptedHosts = () => new Set([`127.0.0.1:${actualPort}`, `localhost:${actualPort}`, `[::1]:${actualPort}`]);
  function checkOrigin(request: IncomingMessage): void {
    const requestHost = request.headers.host;
    if (!requestHost || !acceptedHosts().has(requestHost.toLowerCase())) reject('FORBIDDEN', 'Unrecognized Host');
    const origin = request.headers.origin;
    if (origin !== undefined) {
      let parsed: URL; try { parsed = new URL(origin); } catch { return reject('FORBIDDEN', 'Origin is not allowed'); }
      if (parsed.origin !== origin || parsed.protocol !== 'http:' || !acceptedHosts().has(parsed.host.toLowerCase()) || parsed.host.toLowerCase() !== requestHost.toLowerCase()) reject('FORBIDDEN', 'Origin is not allowed');
    }
    if (request.headers['sec-fetch-site'] === 'cross-site') reject('FORBIDDEN', 'Cross-site request is not allowed');
  }
  async function staticBytes(name: 'index.html' | 'web.js' | 'web.css'): Promise<Buffer> {
    let root: string, path: string;
    try { root = await realpath(publicDir); path = await realpath(resolve(publicDir, name)); }
    catch { return reject('NOT_FOUND', 'Static file unavailable'); }
    const within = relative(root, path);
    if (within.startsWith('..') || isAbsolute(within)) reject('FORBIDDEN', 'Static file path is not allowed');
    return readFile(path);
  }
  async function handle(request: IncomingMessage, response: ServerResponse): Promise<void> {
    try {
      checkOrigin(request);
      if (closing) reject('FORBIDDEN', 'Server is closing');
      const raw = request.url ?? '';
      if (!raw.startsWith('/') || raw.startsWith('//') || raw.includes('?') || raw.includes('#') || raw.includes('\\') || raw.split('/').some(part => part === '.' || part === '..')) reject('INVALID_REQUEST', 'Invalid route');
      const method = request.method ?? 'GET';
      if (raw.startsWith('/api/')) {
        if (!sameToken(request.headers.authorization, token)) reject('UNAUTHORIZED', 'Session authentication required');
        if (raw === '/api/config' && method === 'GET') { json(response, 200, app.config); return; }
        if (raw === '/api/runs' && method === 'POST') { const input = await body(request); validateStartRunRequestV2(input); json(response, 202, app.start(input)); return; }
        const parts = /^\/api\/runs\/([^/]+)(?:\/(cancel|findings|extra-findings|finding-details|review|ocr|related-links|files|evidence|images)(?:\/([^/]+))?)?$/.exec(raw);
        if (!parts) reject('NOT_FOUND', 'Route not found');
        const runId = identifier(parts[1]); const action = parts[2]; const child = parts[3];
        if (!action && method === 'GET') { json(response, 200, app.get(runId)); return; }
        if (action === 'cancel' && !child && method === 'POST') {
          const input = await body(request);
          if (!input || typeof input !== 'object' || Array.isArray(input) || Object.keys(input).length) reject('INVALID_REQUEST', 'Cancel body must be {}');
          const snapshot = await app.cancel(runId); json(response, isTerminalState(snapshot.state) ? 200 : 202, snapshot); return;
        }
        if (method !== 'GET') reject('NOT_FOUND', 'Route not found');
        if (action === 'findings' && !child) { json(response, 200, app.findings(runId)); return; }
        if (action === 'finding-details' && !child) { json(response, 200, app.details(runId)); return; }
        if (action === 'review' && !child) { json(response, 200, app.review(runId)); return; }
        if (action === 'extra-findings' && !child) { json(response, 200, app.extraFindings(runId)); return; }
        if (action === 'ocr' && !child) { json(response, 200, app.ocr(runId)); return; }
        if (action === 'related-links' && !child) { json(response, 200, app.relatedLinks(runId)); return; }
        if (action === 'images' && child) { const png = await app.readImage(runId, identifier(child)); response.writeHead(200, { 'Content-Type': 'image/png', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' }); response.end(png); return; }
        let bytes: Buffer;
        if (action === 'files' && child && OUTPUT_FILE_NAMES_V2.includes(child as OutputFileNameV2)) bytes = await app.readFile(runId, child as OutputFileNameV2);
        else if (action === 'evidence' && child) bytes = await app.readEvidence(runId, identifier(child));
        else return reject('NOT_FOUND', 'Route not found');
        response.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' }); response.end(bytes); return;
      }
      if (method !== 'GET' || !['/', '/web.js', '/web.css'].includes(raw)) reject('NOT_FOUND', 'Route not found');
      const nonce = randomBytes(18).toString('base64url');
      const csp = `default-src 'none'; script-src 'self' 'nonce-${nonce}'; style-src 'self'; connect-src 'self'; img-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'; object-src 'none'`;
      let bytes: Buffer;
      if (raw === '/') {
        const html = (await staticBytes('index.html')).toString('utf8');
        const script = /<script\s+src="\/web\.js"\s+defer><\/script>/;
        if (!script.test(html)) reject('INVALID_CONFIG', 'Invalid web bootstrap template');
        const bootstrap = `<script nonce="${nonce}">window.__INSPECTOR_BOOTSTRAP__=${escapedJson({ sessionToken: token, config: app.config })};</script><script nonce="${nonce}" src="/web.js" defer></script>`;
        bytes = Buffer.from(html.replace(script, () => bootstrap));
      } else bytes = await staticBytes(raw === '/web.js' ? 'web.js' : 'web.css');
      response.writeHead(200, { 'Content-Type': raw === '/' ? 'text/html; charset=utf-8' : raw === '/web.js' ? 'text/javascript; charset=utf-8' : 'text/css; charset=utf-8',
        'Content-Security-Policy': csp, 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'no-referrer' }); response.end(bytes);
    } catch (error) {
      if (response.headersSent) { response.destroy(); return; }
      if (error instanceof ContractError) json(response, statuses[error.code], { error: { code: error.code, message: error.message } });
      else json(response, 404, { error: { code: 'NOT_FOUND', message: 'Registered artifact unavailable' } });
    }
  }
  const server = createServer((request, response) => { void handle(request, response); });
  server.requestTimeout = 15000; server.headersTimeout = 10000;
  await new Promise<void>((res, rej) => { server.once('error', rej); server.listen(port, host, () => { server.removeListener('error', rej); res(); }); });
  const address = server.address(); if (!address || typeof address === 'string') { server.close(); throw new ContractError('INVALID_CONFIG', 'Unable to bind TCP listener'); }
  actualPort = address.port;
  const url = `http://${host === '::1' ? '[::1]' : host === '0.0.0.0' ? '127.0.0.1' : host}:${actualPort}`;
  let closePromise: Promise<void> | undefined;
  return { url, port: actualPort, sessionToken: token, application: app, close() {
    closePromise ??= (async () => {
      closing = true;
      await app.close();
      await new Promise<void>((res, rej) => { server.close(error => error ? rej(error) : res()); server.closeAllConnections(); });
    })(); return closePromise;
  } };
}
