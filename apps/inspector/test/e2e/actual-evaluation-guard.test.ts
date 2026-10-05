import { expect, it } from 'vitest';
import { ACTUAL_LIMITS, characterDifference, guardedTransport } from './actual-evaluation.js';
import { OCR_ENDPOINT } from '../../src/ocr/index.js';
import { CLEF_ENDPOINT } from '../../src/classification/index.js';
it('whole-stage guard burns all attempts across sessions, failures and parallel reservations without reset', async () => {
  const state = { ocr:0,clef:0 }; let starts=0; const snapshots:{ocr:number;clef:number}[]=[];
  const delegate:typeof fetch = async () => { starts++; throw new Error('synthetic transport failure'); };
  const transport=guardedTransport(delegate,state,s=>snapshots.push(s));
  for(const endpoint of [OCR_ENDPOINT,CLEF_ENDPOINT]) {
    const limit=endpoint===OCR_ENDPOINT?ACTUAL_LIMITS.ocr:ACTUAL_LIMITS.clef;
    await Promise.all(Array.from({length:limit},()=>transport(endpoint,{method:'POST',redirect:'error'}).catch(()=>{})));
    expect(()=>transport(endpoint,{method:'POST',redirect:'error'})).toThrow('EVALUATION_BUDGET_EXHAUSTED');
  }
  expect(starts).toBe(24);expect(state).toEqual({ocr:8,clef:16});expect(snapshots).toHaveLength(24);
  const later=guardedTransport(delegate,state,()=>{});expect(()=>later(OCR_ENDPOINT,{method:'POST',redirect:'error'})).toThrow();expect(starts).toBe(24);
  expect(()=>transport('https://openrouter.ai/other',{method:'POST',redirect:'error'})).toThrow('EVALUATION_ENDPOINT_REJECTED');
});
it('failed durable reservation prevents transport and Unicode comparison uses independently authored characters', () => {
  let calls=0;const transport=guardedTransport(async()=>{calls++;return new Response();},{ocr:0,clef:0},()=>{throw new Error('synthetic disk failure');});
  expect(()=>transport(OCR_ENDPOINT,{method:'POST',redirect:'error'})).toThrow();expect(calls).toBe(0);
  expect(characterDifference('한글\nA😀','한굴\nB😀')).toBe(2);expect(characterDifference('','😀')).toBe(1);
});
it('explicit CLI key-missing stage writes safe NOT_RUN proof and rejects ledger reuse before any transport', async () => {
  const {mkdtemp,readFile,rm}=await import('node:fs/promises');const {resolve}=await import('node:path');const {tmpdir}=await import('node:os');const {spawn}=await import('node:child_process');
  const root=await mkdtemp(resolve(tmpdir(),'t9-eval-guard-')); const report=resolve(root,'report');
  const invoke=()=>new Promise<number|null>((res,rej)=>{const child=spawn(process.execPath,['--import','tsx','test/e2e/actual-evaluation.ts','--execute-authorized-once','--config-directory',root,report],{env:{...process.env,OPENROUTER_API_KEY:''},stdio:'ignore'});child.once('error',rej);child.once('exit',res);});
  try {expect(await invoke()).toBe(0);const bytes=await readFile(resolve(report,'actual-evaluation.json'),'utf8');expect(JSON.parse(bytes)).toMatchObject({status:'NOT_RUN',reason:'KEY_NOT_CONFIGURED',actualNetworkStarts:{ocr:0,clef:0},observations:[]});expect(await invoke()).toBe(1);expect(await readFile(resolve(report,'actual-evaluation.json'),'utf8')).toBe(bytes);} finally {await rm(root,{recursive:true,force:true});}
});
