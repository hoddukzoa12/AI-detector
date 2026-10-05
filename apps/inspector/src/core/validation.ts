import { AI_CHOICES, API_ERROR_CODES, CLEF_MODEL, ERROR_CODES, RUN_STATES, TECHNIQUES, type ApiErrorCode,
  type OfficialResult, type RunSnapshot, type ReviewFile, type FindingDetailsFile,
  type EvidenceSnapshot, type ScanStatusFile, type AiAnalysis, type StartRunRequest, type ApiErrorResponse,
  type PublicConfig, type FindingsResponse } from './types.js';
import { classifyAiAnalysis } from './ai.js';

export class ContractError extends Error {
  constructor(public readonly code: ApiErrorCode, message: string) { super(`${code}: ${message}`); this.name = 'ContractError'; }
}
export function validateEntryUrl(value: unknown): string {
  if (typeof value !== 'string' || value.trim() !== value || !/^https?:\/\//i.test(value)) {
    throw new ContractError('INVALID_URL', 'An absolute HTTP(S) URL is required');
  }
  let parsed: URL;
  try { parsed = new URL(value); } catch { throw new ContractError('INVALID_URL', 'Invalid URL'); }
  if (!parsed.hostname || parsed.username || parsed.password || !['http:', 'https:'].includes(parsed.protocol)) {
    throw new ContractError('INVALID_URL', 'Credential URLs and non-HTTP(S) protocols are not allowed');
  }
  return value;
}
type Obj = Record<string, unknown>;
function fail(path: string, expected: string): never { throw new ContractError('INVALID_REQUEST', `${path}: ${expected}`); }
function object(value: unknown, path: string, required: string[], optional: string[] = []): Obj {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) fail(path, 'object required');
  const result = value as Obj;
  for (const key of required) if (!Object.hasOwn(result, key)) fail(`${path}.${key}`, 'field required');
  for (const key of Object.keys(result)) if (![...required, ...optional].includes(key)) fail(`${path}.${key}`, 'unexpected field');
  return result;
}
function string(value: unknown, path: string, allowEmpty = false): asserts value is string {
  if (typeof value !== 'string' || (!allowEmpty && !value.length)) fail(path, 'string required');
}
function number(value: unknown, path: string, min = 0, max = Infinity, integer = false): asserts value is number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max ||
    (integer && !Number.isInteger(value))) fail(path, 'finite number in range required');
}
function literal(value: unknown, path: string, allowed: readonly unknown[]): void {
  if (!allowed.includes(value)) fail(path, 'unsupported value');
}
function array(value: unknown, path: string): unknown[] { if (!Array.isArray(value)) fail(path, 'array required'); return value; }
function unique(values: unknown[], path: string): void { if (new Set(values).size !== values.length) fail(path, 'duplicates forbidden'); }
function date(value: unknown, path: string): void {
  string(value, path);
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(value) || !Number.isFinite(Date.parse(value)))
    fail(path, 'ISO 8601 timestamp required');
  const year = Number(value.slice(0, 4)), month = Number(value.slice(5, 7)), day = Number(value.slice(8, 10));
  const hours = Number(value.slice(11, 13)), minutes = Number(value.slice(14, 16)), seconds = Number(value.slice(17, 19));
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  if (month < 1 || month > 12 || day < 1 || day > lastDay || hours > 23 || minutes > 59 || seconds > 59)
    fail(path, 'valid calendar timestamp required');
}
function url(value: unknown, path: string): void { try { validateEntryUrl(value); } catch { fail(path, 'absolute credential-free HTTP(S) URL required'); } }
function nullableString(value: unknown, path: string): void { if (value !== null) string(value, path); }
function path(value: unknown, at: string): void {
  if (value === null) return;
  string(value, at);
  if (value.includes('\\') || value.startsWith('/') || /^[a-z]:/i.test(value) || value.split('/').some(p => p === '..' || p === '.' || p === ''))
    fail(at, 'relative output path without traversal required');
}
function sha(value: unknown, at: string): void { if (value !== null && (typeof value !== 'string' || !/^[a-f0-9]{64}$/.test(value))) fail(at, 'SHA-256 hex required'); }
function evidence(value: unknown, at: string): void {
  const e = object(value, at, ['snapshotId', 'path', 'sha256']); string(e.snapshotId, `${at}.snapshotId`);
  path(e.path, `${at}.path`); sha(e.sha256, `${at}.sha256`);
  if ((e.path === null) !== (e.sha256 === null)) fail(at, 'path and hash must be present together');
}
function probabilities(value: unknown, at: string): void {
  const p = object(value, at, [...AI_CHOICES]);
  let sum = 0; for (const key of AI_CHOICES) { number(p[key], `${at}.${key}`, 0, 1); sum += p[key]; }
  if (Math.abs(sum - 1) > .001 + Number.EPSILON) fail(at, 'probabilities must sum to one');
}
function boundary(text: string, offset: number): boolean {
  if (offset <= 0 || offset >= text.length) return true;
  const prior = text.charCodeAt(offset - 1), next = text.charCodeAt(offset);
  return !(prior >= 0xd800 && prior <= 0xdbff && next >= 0xdc00 && next <= 0xdfff);
}
/** Raw offsets refer to UTF-16 half-open indices; overlap between chunks is allowed. */
export function validateAiAnalysis(value: unknown, rawText?: string, terminal = false): void {
  const a = object(value, 'ai', ['model', 'summaryChunkId', 'choice', 'probabilities', 'confidence', 'chunks']);
  literal(a.model, 'ai.model', [CLEF_MODEL]); nullableString(a.summaryChunkId, 'ai.summaryChunkId');
  const chunks = array(a.chunks, 'ai.chunks'); const ids: unknown[] = [];
  for (const [i, item] of chunks.entries()) {
    const at = `ai.chunks[${i}]`, c = object(item, at, ['chunkId', 'rawStart', 'rawEnd', 'status', 'choice', 'probabilities', 'confidence', 'reasonCode']);
    string(c.chunkId, `${at}.chunkId`); ids.push(c.chunkId);
    number(c.rawStart, `${at}.rawStart`, 0, Infinity, true); number(c.rawEnd, `${at}.rawEnd`, c.rawStart, Infinity, true);
    if (rawText !== undefined && (c.rawEnd > rawText.length || !boundary(rawText, c.rawStart) || !boundary(rawText, c.rawEnd))) fail(at, 'invalid raw text range');
    literal(c.status, `${at}.status`, ['pending', 'running', 'completed', 'error', 'not_started', 'cancelled']);
    if (terminal && ['pending', 'running'].includes(c.status as string)) fail(at, 'active chunks forbidden in a terminal run');
    if (c.status === 'completed') {
      literal(c.choice, `${at}.choice`, AI_CHOICES); probabilities(c.probabilities, `${at}.probabilities`);
      const values = c.probabilities as Record<string, number>;
      if (values[c.choice as string] !== Math.max(...Object.values(values)))
        fail(`${at}.choice`, 'must belong to the highest-probability choices');
      number(c.confidence, `${at}.confidence`, 0, 1); literal(c.reasonCode, `${at}.reasonCode`, [null]);
    } else {
      for (const key of ['choice', 'probabilities', 'confidence']) literal(c[key], `${at}.${key}`, [null]);
      literal(c.reasonCode, `${at}.reasonCode`, [null, 'AI_HTTP_ERROR', 'AI_RESPONSE_INVALID', 'AI_TIMEOUT', 'USER_CANCELLED', 'TIME_LIMIT', 'RESOURCE_LIMIT']);
      if (c.status === 'error' && !['AI_HTTP_ERROR', 'AI_RESPONSE_INVALID', 'AI_TIMEOUT'].includes(c.reasonCode as string)) fail(at, 'error chunk requires an AI error code');
    }
  }
  unique(ids, 'ai.chunks.chunkId');
  // Summary selection is verified below by the same deterministic, non-aggregate contract.
  const completed = chunks.filter(item => (item as Obj).status === 'completed') as Obj[];
  const ordered = [...completed].sort((x, y) => (x.rawStart as number) - (y.rawStart as number) || (x.chunkId as string).localeCompare(y.chunkId as string));
  const positive = ordered.filter(c => c.choice === 'illegal_ad' && ((c.probabilities as Obj).illegal_ad as number) >= .8);
  positive.sort((x, y) => ((y.probabilities as Obj).illegal_ad as number) - ((x.probabilities as Obj).illegal_ad as number) ||
    (x.rawStart as number) - (y.rawStart as number) || (x.chunkId as string).localeCompare(y.chunkId as string));
  const selected = positive[0] ?? ordered.find(c => c.choice === 'uncertain' || (c.probabilities as Record<string, number>)[c.choice as string] < .8) ?? ordered[0];
  if (a.summaryChunkId !== (selected?.chunkId ?? null)) fail('ai.summaryChunkId', 'must identify the selected real chunk');
  for (const key of ['choice', 'confidence']) if (a[key] !== (selected?.[key] ?? null)) fail(`ai.${key}`, 'must copy summary chunk');
  if (!selected) literal(a.probabilities, 'ai.probabilities', [null]);
  else {
    probabilities(a.probabilities, 'ai.probabilities');
    for (const key of AI_CHOICES) if ((a.probabilities as Obj)[key] !== (selected.probabilities as Obj)[key]) fail('ai.probabilities', 'must copy summary chunk');
  }
}

export function validateOfficialResult(value: unknown): asserts value is OfficialResult {
  const r = object(value, 'result', ['meta', 'findings']);
  const m = object(r.meta, 'result.meta', ['topic', 'entry_url', 'started_at', 'finished_at', 'elapsed_sec'], ['tool_version']);
  literal(m.topic, 'meta.topic', ['TOPIC']); url(m.entry_url, 'meta.entry_url'); date(m.started_at, 'meta.started_at'); date(m.finished_at, 'meta.finished_at');
  if (Date.parse(m.finished_at as string) < Date.parse(m.started_at as string)) fail('meta.finished_at', 'cannot precede start');
  number(m.elapsed_sec, 'meta.elapsed_sec'); if (Object.hasOwn(m, 'tool_version')) string(m.tool_version, 'meta.tool_version');
  const ids: unknown[] = [], keys: string[] = [];
  for (const [i, item] of array(r.findings, 'findings').entries()) {
    const at = `findings[${i}]`, f = object(item, at, ['id', 'url', 'is_violation', 'location', 'evidence_text', 'technique']);
    string(f.id, `${at}.id`); ids.push(f.id); url(f.url, `${at}.url`); literal(f.is_violation, `${at}.is_violation`, [true]);
    string(f.location, `${at}.location`); string(f.evidence_text, `${at}.evidence_text`, true); literal(f.technique, `${at}.technique`, TECHNIQUES);
    keys.push(JSON.stringify([f.url, f.location, f.technique]));
  }
  unique(ids, 'findings.id'); unique(keys, 'findings.url+location+technique');
}
export function validateRunSnapshot(value: unknown): asserts value is RunSnapshot {
  const r = object(value, 'run', ['runId', 'entryUrl', 'startedAt', 'state', 'finishedAt', 'elapsedSec', 'aiEnabled', 'model', 'counts', 'activeUrls', 'errors']);
  string(r.runId, 'run.runId'); url(r.entryUrl, 'run.entryUrl'); date(r.startedAt, 'run.startedAt'); literal(r.state, 'run.state', RUN_STATES);
  number(r.elapsedSec, 'run.elapsedSec'); literal(r.aiEnabled, 'run.aiEnabled', [true, false]);
  literal(r.model, 'run.model', [r.aiEnabled ? CLEF_MODEL : null]);
  if (['running', 'stopping'].includes(r.state as string)) literal(r.finishedAt, 'run.finishedAt', [null]);
  else { date(r.finishedAt, 'run.finishedAt'); if (Date.parse(r.finishedAt as string) < Date.parse(r.startedAt as string)) fail('run.finishedAt', 'cannot precede start'); }
  const counts = object(r.counts, 'run.counts', ['discoveredPages', 'scannedPages', 'failedPages', 'skippedPages', 'pendingPages', 'confirmedFindings', 'reviewCandidates']);
  for (const [key, val] of Object.entries(counts)) number(val, `run.counts.${key}`, 0, Infinity, true);
  for (const item of array(r.activeUrls, 'run.activeUrls')) url(item, 'run.activeUrls[]');
  for (const [i, item] of array(r.errors, 'run.errors').entries()) {
    const at = `run.errors[${i}]`, e = object(item, at, ['scope', 'code', 'url', 'candidateId', 'message']);
    literal(e.scope, `${at}.scope`, ['page', 'frame', 'ai', 'storage', 'runtime', 'limit']); literal(e.code, `${at}.code`, ERROR_CODES);
    if (e.url !== null) url(e.url, `${at}.url`); nullableString(e.candidateId, `${at}.candidateId`); string(e.message, `${at}.message`);
  }
}
export function validateReviewFile(value: unknown, terminal = false): asserts value is ReviewFile {
  const r = object(value, 'review', ['schemaVersion', 'runId', 'candidates']); literal(r.schemaVersion, 'review.schemaVersion', [1]); string(r.runId, 'review.runId');
  const ids: unknown[] = [];
  for (const [i, item] of array(r.candidates, 'review.candidates').entries()) {
    const at = `review.candidates[${i}]`, c = object(item, at, ['candidateId', 'url', 'location', 'evidenceText', 'techniques', 'reason', 'ai', 'evidence']);
    string(c.candidateId, `${at}.candidateId`); ids.push(c.candidateId); url(c.url, `${at}.url`); string(c.location, `${at}.location`); string(c.evidenceText, `${at}.evidenceText`, true);
    const techniques = array(c.techniques, `${at}.techniques`); if (!techniques.length) fail(at, 'at least one technique required');
    techniques.forEach(t => literal(t, `${at}.techniques[]`, TECHNIQUES)); unique(techniques, `${at}.techniques`);
    literal(c.reason, `${at}.reason`, ['UNCERTAIN', 'AI_ERROR', 'LOCAL_UNCERTAIN', 'NOT_ANALYZED']);
    if (c.ai !== null) {
      validateAiAnalysis(c.ai, c.evidenceText, terminal);
      const decision = classifyAiAnalysis(c.ai as AiAnalysis);
      if (!decision.review || c.reason !== decision.reason) fail(`${at}.reason`, 'must reflect AI error/unfinished/uncertain precedence');
    } else if (c.reason !== 'LOCAL_UNCERTAIN' && c.reason !== 'NOT_ANALYZED')
      fail(`${at}.reason`, 'local review requires LOCAL_UNCERTAIN or NOT_ANALYZED');
    evidence(c.evidence, `${at}.evidence`);
  }
  unique(ids, 'review.candidateId');
}
export function validateFindingDetailsFile(value: unknown, result?: OfficialResult, terminal = false): asserts value is FindingDetailsFile {
  const d = object(value, 'findingDetails', ['schemaVersion', 'runId', 'details']); literal(d.schemaVersion, 'findingDetails.schemaVersion', [1]); string(d.runId, 'findingDetails.runId');
  const ids: unknown[] = [];
  for (const [i, item] of array(d.details, 'findingDetails.details').entries()) {
    const at = `details[${i}]`, f = object(item, at, ['findingId', 'candidateId', 'decisionSource', 'ruleIds', 'ai', 'evidence']);
    string(f.findingId, `${at}.findingId`); ids.push(f.findingId); string(f.candidateId, `${at}.candidateId`); literal(f.decisionSource, `${at}.decisionSource`, ['local', 'clef']);
    const rules = array(f.ruleIds, `${at}.ruleIds`); rules.forEach(v => string(v, `${at}.ruleIds[]`)); unique(rules, `${at}.ruleIds`);
    if (f.decisionSource === 'clef') { if (rules.length || f.ai === null) fail(at, 'CLEF details require AI and empty ruleIds'); }
    else literal(f.ai, `${at}.ai`, [null]);
    const finding = result?.findings.find(v => v.id === f.findingId);
    if (f.ai !== null) {
      validateAiAnalysis(f.ai, finding?.evidence_text, terminal);
      if (!classifyAiAnalysis(f.ai as AiAnalysis).confirmed)
        fail(`${at}.ai`, 'CLEF confirmed detail requires a decisive positive chunk');
    }
    evidence(f.evidence, `${at}.evidence`);
  }
  unique(ids, 'details.findingId');
  if (result) { validateOfficialResult(result); if (ids.length !== result.findings.length || result.findings.some(f => !ids.includes(f.id))) fail('details', 'exactly one matching detail per finding required'); }
}
function bounds(value: unknown, at: string): void {
  const b = object(value, at, ['x', 'y', 'width', 'height']); number(b.x, `${at}.x`, -Infinity); number(b.y, `${at}.y`, -Infinity);
  number(b.width, `${at}.width`); number(b.height, `${at}.height`);
}
export function validateEvidenceSnapshot(value: unknown): asserts value is EvidenceSnapshot {
  const s = object(value, 'snapshot', ['snapshotId', 'topPageUrl', 'frameUrl', 'framePath', 'capturedAt', 'html', 'elements']);
  string(s.snapshotId, 'snapshot.snapshotId'); url(s.topPageUrl, 'snapshot.topPageUrl'); string(s.frameUrl, 'snapshot.frameUrl');
  for (const p of array(s.framePath, 'snapshot.framePath')) string(p, 'snapshot.framePath[]'); date(s.capturedAt, 'snapshot.capturedAt'); string(s.html, 'snapshot.html', true);
  for (const [i, item] of array(s.elements, 'snapshot.elements').entries()) {
    const at = `snapshot.elements[${i}]`, e = object(item, at, ['location', 'rawText', 'styles']); string(e.location, `${at}.location`); string(e.rawText, `${at}.rawText`, true);
    for (const [j, item] of array(e.styles, `${at}.styles`).entries()) {
      const st = `${at}.styles[${j}]`, style = object(item, st, ['elementLocation', 'css', 'bounds']); string(style.elementLocation, `${st}.elementLocation`);
      if (!style.css || typeof style.css !== 'object' || Array.isArray(style.css)) fail(`${st}.css`, 'string map required');
      for (const v of Object.values(style.css as Obj)) string(v, `${st}.css[]`, true); bounds(style.bounds, `${st}.bounds`);
    }
  }
}
export function validateScanStatusFile(value: unknown): asserts value is ScanStatusFile {
  const s = object(value, 'scanStatus', ['schemaVersion', 'run', 'scope', 'files', 'resultSaved']); literal(s.schemaVersion, 'scanStatus.schemaVersion', [1]); validateRunSnapshot(s.run);
  const scope = object(s.scope, 'scanStatus.scope', ['hostname', 'framePolicy', 'skipped', 'unvisitedUrls']); string(scope.hostname, 'scope.hostname'); literal(scope.framePolicy, 'scope.framePolicy', ['embedded']);
  for (const item of array(scope.skipped, 'scope.skipped')) { const entry = object(item, 'scope.skipped[]', ['url', 'reasonCode']); url(entry.url, 'scope.skipped[].url'); literal(entry.reasonCode, 'scope.skipped[].reasonCode', ERROR_CODES); }
  for (const item of array(scope.unvisitedUrls, 'scope.unvisitedUrls')) url(item, 'scope.unvisitedUrls[]');
  const files = object(s.files, 'scanStatus.files', ['resultPath', 'reviewPath', 'findingDetailsPath', 'evidenceDir', 'resultSha256']);
  for (const key of ['resultPath', 'reviewPath', 'findingDetailsPath', 'evidenceDir']) path(files[key], `files.${key}`); sha(files.resultSha256, 'files.resultSha256');
  literal(s.resultSaved, 'scanStatus.resultSaved', [true, false]);
  if (s.resultSaved && (files.resultPath === null || files.resultSha256 === null)) fail('scanStatus', 'saved result requires actual path and hash');
}
export function validateStartRunRequest(value: unknown): asserts value is StartRunRequest {
  const r = object(value, 'startRequest', ['entryUrl', 'aiEnabled']); validateEntryUrl(r.entryUrl);
  literal(r.aiEnabled, 'startRequest.aiEnabled', [true, false]);
}
export function validatePublicConfig(value: unknown): asserts value is PublicConfig {
  const c = object(value, 'config', ['aiConfigured', 'model', 'outputRoot']); literal(c.aiConfigured, 'config.aiConfigured', [true, false]);
  literal(c.model, 'config.model', [CLEF_MODEL]); string(c.outputRoot, 'config.outputRoot');
}
export function validateApiErrorResponse(value: unknown): asserts value is ApiErrorResponse {
  const r = object(value, 'response', ['error']), e = object(r.error, 'response.error', ['code', 'message']);
  literal(e.code, 'response.error.code', API_ERROR_CODES); string(e.message, 'response.error.message');
}
export function validateFindingsResponse(value: unknown): asserts value is FindingsResponse {
  const r = object(value, 'response', ['runId', 'findings']); string(r.runId, 'response.runId');
  validateOfficialResult({ meta: { topic: 'TOPIC', entry_url: 'https://validation.invalid/',
    started_at: '2026-01-01T00:00:00Z', finished_at: '2026-01-01T00:00:00Z', elapsed_sec: 0 }, findings: r.findings });
}
