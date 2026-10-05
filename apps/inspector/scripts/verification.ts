/** Independent output/DOM verification shared by explicit mock harnesses; no CLI side effects. */
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import type { Frame, Page } from 'playwright';
import type { FixtureSite, ResolvedFindingTruth } from '../test/fixtures/site.js';

export interface IndependentFinding { id: string; url: string; is_violation: true; location: string; evidence_text: string; technique: 'HOMOGLYPH' | 'JAMO' | 'TRANSPARENT' | 'OFFSCREEN' }
export interface IndependentResult {
  meta: { topic: 'TOPIC'; entry_url: string; started_at: string; finished_at: string; elapsed_sec: number; tool_version?: string };
  findings: IndependentFinding[];
}
function object(value: unknown): asserts value is Record<string, unknown> {
  assert.ok(value !== null && typeof value === 'object' && !Array.isArray(value), 'JSON object required');
}
function exactKeys(value: Record<string, unknown>, required: string[], optional: string[] = []): void {
  assert.ok(required.every(key => Object.hasOwn(value, key)), 'required JSON fields');
  assert.ok(Object.keys(value).every(key => [...required, ...optional].includes(key)), 'only official JSON fields');
}
function text(value: unknown): asserts value is string { assert.ok(typeof value === 'string' && value.length > 0, 'nonempty string required'); }
function url(value: unknown): void { text(value); const parsed = new URL(value); assert.ok(['http:', 'https:'].includes(parsed.protocol) && !parsed.username && !parsed.password, 'public HTTP URL'); }
function iso(value: unknown): void { text(value); assert.match(value, /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/); assert.ok(Number.isFinite(Date.parse(value)), 'ISO timestamp'); assert.equal(new Date(value.slice(0, 10) + 'T00:00:00Z').toISOString().slice(0, 10), value.slice(0, 10), 'valid calendar date'); }
/** Independent official contract: deliberately never calls src/core validation. */
export function independentOfficialResult(bytes: Uint8Array): IndependentResult {
  const buffer = Buffer.from(bytes);
  assert.ok(!(buffer[0] === 0xef && buffer[1] === 0xbb && buffer[2] === 0xbf), 'UTF-8 without BOM');
  const raw = new TextDecoder('utf-8', { fatal: true }).decode(buffer);
  const result: unknown = JSON.parse(raw); object(result); exactKeys(result, ['meta', 'findings']);
  object(result.meta); exactKeys(result.meta, ['topic', 'entry_url', 'started_at', 'finished_at', 'elapsed_sec'], ['tool_version']);
  assert.equal(result.meta.topic, 'TOPIC'); url(result.meta.entry_url); iso(result.meta.started_at); iso(result.meta.finished_at);
  assert.ok(typeof result.meta.elapsed_sec === 'number' && Number.isFinite(result.meta.elapsed_sec) && result.meta.elapsed_sec >= 0);
  assert.ok(Date.parse(result.meta.finished_at as string) >= Date.parse(result.meta.started_at as string));
  if (Object.hasOwn(result.meta, 'tool_version')) text(result.meta.tool_version);
  assert.ok(Array.isArray(result.findings)); const ids = new Set<string>(), owners = new Set<string>();
  for (const finding of result.findings) {
    object(finding); exactKeys(finding, ['id', 'url', 'is_violation', 'location', 'evidence_text', 'technique']);
    text(finding.id); url(finding.url); text(finding.location); assert.equal(typeof finding.evidence_text, 'string'); assert.equal(finding.is_violation, true);
    assert.ok(['HOMOGLYPH', 'JAMO', 'TRANSPARENT', 'OFFSCREEN'].includes(finding.technique as string), 'one of four techniques');
    assert.ok(!ids.has(finding.id), 'unique finding ID'); ids.add(finding.id);
    const identity = JSON.stringify([finding.url, finding.location, finding.technique]); assert.ok(!owners.has(identity), 'URL/full-path/technique deduplication'); owners.add(identity);
  }
  return result as unknown as IndependentResult;
}
export const sha256 = (bytes: Uint8Array): string => createHash('sha256').update(bytes).digest('hex');
export function assertTruth(result: IndependentResult, truths: readonly ResolvedFindingTruth[]): void {
  assert.equal(result.findings.length, truths.length, 'literal independent fixture count');
  for (const truth of truths) assert.equal(result.findings.filter(item => item.url === truth.url && item.location === truth.location && item.evidence_text === truth.rawEvidence && item.technique === truth.technique).length, 1, `${truth.caseId}:${truth.technique} exact raw/visited URL/full path`);
}
/** Uses fixture framePath steps, never splits >>> that may occur inside a quoted selector. No DOM mutation. */
export async function assertTruthLocations(page: Page, fixture: FixtureSite, truths = fixture.expectedFindings): Promise<void> {
  for (const topUrl of new Set(truths.map(truth => truth.url))) {
    await page.goto(topUrl, { waitUntil: 'domcontentloaded' });
    for (const truth of truths.filter(item => item.url === topUrl)) {
      let frame: Frame = page.mainFrame();
      for (const literal of truth.framePath) {
        const selector = literal.replaceAll('{origin}', fixture.origin).replaceAll('{external}', fixture.externalOrigin);
        // CSS [src="absolute"] must match the original relative src through baseURI, without changing it.
        const source = /^iframe\[src="(.*)"\]$/.exec(selector);
        await frame.locator(source ? 'iframe' : selector).first().waitFor({ state: 'attached' });
        const owners = await frame.locator(source ? 'iframe' : selector).elementHandles();
        const matching = [];
        for (const owner of owners) {
          if (!source || await owner.evaluate((node, expected) => new URL((node as Element).getAttribute('src') ?? '', node.baseURI).href === expected, source[1])) matching.push(owner);
        }
        assert.equal(matching.length, 1, `unique iframe owner ${selector}`);
        const child = await matching[0].contentFrame(); assert.ok(child, 'iframe document available'); frame = child;
      }
      const owner = frame.locator(truth.selector); await owner.waitFor({ state: 'attached' }); assert.equal(await owner.count(), 1, `unique element ${truth.location}`);
      assert.equal(await owner.textContent(), truth.rawEvidence, 'unmodified raw DOM text');
    }
  }
}

export interface IndependentExtraResult {meta:IndependentResult['meta']; findings:{id:string;url:string;is_violation:true;location:string;evidence_text:string;technique:'ETC';extra_finding:'IMAGE_AD_OCR'}[]}
/** Independent extra contract, no production serializer/validator reuse. */
export function independentExtraResult(bytes: Uint8Array): IndependentExtraResult {
 const buffer=Buffer.from(bytes); assert.ok(!(buffer[0]===0xef&&buffer[1]===0xbb&&buffer[2]===0xbf),'UTF-8 without BOM');
 const value:unknown=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(buffer));object(value);exactKeys(value,['meta','findings']);
 independentOfficialResult(Buffer.from(JSON.stringify({meta:value.meta,findings:[]})));
 assert.ok(Array.isArray(value.findings)); const ids=new Set<string>(),owners=new Set<string>();
 for(const item of value.findings){object(item);exactKeys(item,['id','url','is_violation','location','evidence_text','technique','extra_finding']);text(item.id);url(item.url);text(item.location);assert.equal(typeof item.evidence_text,'string');assert.equal(item.is_violation,true);assert.equal(item.technique,'ETC');assert.equal(item.extra_finding,'IMAGE_AD_OCR');assert.ok(!ids.has(item.id));ids.add(item.id);const identity=JSON.stringify([item.url,item.location]);assert.ok(!owners.has(identity));owners.add(identity);}
 return value as unknown as IndependentExtraResult;
}
