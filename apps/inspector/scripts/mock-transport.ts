/** Explicit synthetic HTTP transport for deployment verification only. Never installed by a product entry. */
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { writeFile } from 'node:fs/promises';
import { crawl, type ImageAcquisitionResult } from '../src/crawler/index.js';
import { findingTruth, negativeTruth } from '../test/fixtures/truth.js';
import { assetTruth, imageTruth, menuTruth } from '../test/fixtures/ocr-truth.js';
export const FIXTURE_API_KEY = 'synthetic-deployment-http-placeholder';
const OCR_ENDPOINT = 'https://openrouter.ai/api/v1/chat/completions';
const CLEF_ENDPOINT = 'https://openrouter.ai/api/alpha/decisions';
export interface FixtureExtraction { status: 'readable' | 'no_text' | 'unreadable'; text: string }
export type FixtureInputs = Record<string, FixtureExtraction>;
export interface FixtureTransport {
  fetch: typeof fetch; inputs: FixtureInputs;
  observeAssets(result: ImageAcquisitionResult): void;
  counts(): { ocr: number; clef: number };
}
const owners = new Map<string, typeof imageTruth[number][]>();
for (const item of imageTruth) { const key = JSON.stringify([item.framePath, item.selector]); owners.set(key, [...(owners.get(key) ?? []), item]); }
const combined = [...owners.values()].map(items => {
  const readable = items.map(item => assetTruth.find(asset => asset.id === item.assetId)!).filter(asset => asset.extractionStatus === 'readable');
  return { text: readable.map(asset => asset.text).join('\n'), label: readable.some(asset => asset.label === 'illegal_ad') ? 'illegal_ad' : readable.some(asset => asset.label === 'general_ad') ? 'general_ad' : 'non_ad' };
});
/** Literal labels and authored raw fragments only: no production normalizer, detector or keyword classifier. */
function fixtureChoice(text: string): string {
  if (negativeTruth.some(item => item.rawEvidence === text) || menuTruth.some(item => item.rawText === text && item.label === 'non_ad')) return 'non_ad';
  if (menuTruth.some(item => item.rawText === text && item.label === 'illegal_ad') || findingTruth.some(item => item.rawEvidence === text)) return 'illegal_ad';
  const value = combined.find(item => item.text === text); if (value) return value.label;
  // The independent long fixture may be split by the real tokenizer. Each mock fragment inherits its authored fixture label.
  if (text && findingTruth.some(item => item.caseId === 'long-tail' && item.rawEvidence.includes(text))) return 'illegal_ad';
  return 'non_ad'; // Additional synthetic fixture navigation/accessibility text, never a product fallback.
}
export function createFixtureTransport(delegate: typeof fetch = fetch, inputs: FixtureInputs = {}, onCounts?: (counts: {ocr:number;clef:number}) => void): FixtureTransport {
  let ocr = 0, clef = 0;
  const counts = () => ({ocr,clef});
  return { inputs, counts,
    observeAssets(result) {
      if (result.status !== 'captured') return;
      const truth = assetTruth.find(asset => asset.sha256 === result.assets.original.sha256);
      assert.ok(truth, 'Unknown synthetic original image');
      const value = { status: truth.extractionStatus, text: truth.text };
      const previous = inputs[result.assets.input.sha256]; if (previous) assert.deepEqual(previous, value, 'same PNG has consistent human-authored truth');
      inputs[result.assets.input.sha256] = value;
    },
    fetch: async (input, init) => {
      const endpoint = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
      if (![OCR_ENDPOINT,CLEF_ENDPOINT].includes(endpoint)) {
        assert.notEqual(new URL(endpoint).hostname, 'openrouter.ai', 'Unexpected provider endpoint');
        return delegate(input,init);
      }
      if (endpoint === OCR_ENDPOINT) ocr++; else clef++; onCounts?.(counts());
      assert.equal(init?.method, 'POST'); assert.equal(typeof init?.body, 'string');
      const body = JSON.parse(init!.body as string);
      if (endpoint === OCR_ENDPOINT) {
        assert.equal(body.model,'google/gemini-3.8-flash');
        const content = body.messages.find((message: {role:string}) => message.role === 'user').content;
        const data = content.find((item: {type:string}) => item.type === 'image_url').image_url.url as string;
        assert.ok(data.startsWith('data:image/png;base64,'), 'PNG-only model input');
        const bytes = Buffer.from(data.slice('data:image/png;base64,'.length),'base64');
        assert.ok(bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])), 'actual PNG input');
        const truth = inputs[createHash('sha256').update(bytes).digest('hex')]; assert.ok(truth, 'Unknown synthetic PNG');
        assert.equal(body.response_format.type,'json_schema'); assert.equal(body.response_format.json_schema.strict,true);
        return Response.json({model:'google/gemini-3.8-flash',choices:[{index:0,finish_reason:'stop',message:{role:'assistant',content:JSON.stringify(truth)}}],usage:{prompt_tokens:20,completion_tokens:6,total_tokens:26}});
      }
      assert.equal(body.model,'cloudflare/clef'); assert.equal(typeof body.state.rawText,'string');
      if (['MEMBER','MENU'].includes(body.state.rawText)) assert.deepEqual(body.state.links, [], 'title does not inherit sibling links');
      const choice = fixtureChoice(body.state.rawText);
      return Response.json({model:'cloudflare/clef',answers:{ad_class:{type:'choice',choice,confidence:.9,probabilities:Object.fromEntries(['illegal_ad','general_ad','non_ad','uncertain'].map(key=>[key,key===choice?.94:.02]))}},usage:{input_tokens:17,output_tokens:4,cost:0}});
    },
  };
}
/** Read-only preflight correlation for a child process: acquired original hash -> measured PNG hash -> authored text.
 * Does not infer labels from detector output and does not modify application/collector behavior. */
export async function prepareFixtureInputs(url: string, executablePath?: string): Promise<FixtureInputs> {
  const mock = createFixtureTransport();
  const result = await crawl(url, { executablePath, maxPages:1, dynamicWaitMs:150, resourceWaitMs:150, scrollSteps:0, navigationTimeoutMs:10000,
    images:{enabled:true,onImage:(_owner,value)=>mock.observeAssets(value)}});
  assert.equal(result.counts.scannedPages,1,'fixture preflight captured one page');
  assert.equal(Object.keys(mock.inputs).length > 0,true,'fixture preflight mapped actual PNG bytes');
  return mock.inputs;
}
export async function writeFixturePreload(path: string, inputs: FixtureInputs, counterPath: string, moduleUrl: string): Promise<void> {
  // This entry contains the explicitly injected synthetic transport, never a key, header, PNG data or provider response log.
  await writeFile(path, `import {readFileSync,writeFileSync} from 'node:fs';\nimport {createFixtureTransport} from ${JSON.stringify(moduleUrl)};\nconst inputs=JSON.parse(readFileSync(${JSON.stringify(path+'.inputs.json')},'utf8'));\nconst target=${JSON.stringify(counterPath)};\nconst original=globalThis.fetch;\nconst mock=createFixtureTransport(original,inputs,c=>writeFileSync(target,JSON.stringify(c)));\nwriteFileSync(target,JSON.stringify(mock.counts()));\nglobalThis.fetch=mock.fetch;\n`,{mode:0o600});
  await writeFile(path+'.inputs.json', JSON.stringify(inputs),{mode:0o600});
}
