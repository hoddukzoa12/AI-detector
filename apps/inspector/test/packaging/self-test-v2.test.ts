import {it,expect} from 'vitest';
import {mkdtemp,readFile,readdir,rm,writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {runSelfTest} from '../../scripts/self-test.js';
it('explicit mocked production self-test checks DOM25, every image occurrence, menu22 negatives, paired JSON and safe PNGs without touching existing output',async()=>{
 const root=await mkdtemp(join(tmpdir(),'t8-self-v2-'));
 try{
  await writeFile(join(root,'result.json'),'existing-user-result');
  const path=await runSelfTest({mode:'npm',outputDir:root});
  const report=JSON.parse(await readFile(path,'utf8'));
  expect(report.assertions).toBe('PASS');expect(report.inferenceTransport).toBe('EXPLICIT_SYNTHETIC_HTTP_MOCK');expect(report.actualOcrInference).toBe('NOT_RUN');
  expect(report.transportCalls.ocr).toBeGreaterThan(0);expect(report.transportCalls.clef).toBeGreaterThan(0);
  expect(report.runs[0].findings).toBe(25);expect(report.runs[1].findings).toBe(0);expect(report.runs[1].extraFindings).toBe(0);
  expect(report.runs[2].imageOccurrences).toBe(39);expect(report.runs[2].extraFindings).toBeGreaterThan(0);
  expect(report.runs[3].findings).toBe(5);expect(report.menuTitleNegatives).toBe(22);
  expect(await readFile(join(root,'result.json'),'utf8')).toBe('existing-user-result');expect(await readdir(join(root,'self-test'))).toHaveLength(1);
 }finally{await rm(root,{recursive:true,force:true});}
},120000);
