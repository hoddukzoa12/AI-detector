import { mkdtemp, rm, writeFile, mkdir, cp } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import { describe, it, expect } from 'vitest';
import { assertPeX64, inventory, verifyPackage, verifyFixtureAssets } from '../../scripts/packaging-lib.mjs';

describe('release audit rejects unsafe/incomplete artifacts', () => {
  it('rejects a non-PE runtime and x86 architecture', async () => {
    const root = await mkdtemp(resolve(tmpdir(), 'inspector-pe-'));
    try {
      const runtime = resolve(root, 'node.exe');
      await writeFile(runtime, 'not an executable');
      await expect(assertPeX64(runtime)).rejects.toThrow('Not a PE');
      const invalid = Buffer.alloc(128); invalid.write('MZ'); invalid.writeUInt32LE(64, 0x3c);
      invalid.writeUInt32LE(0x00004550, 64); invalid.writeUInt16LE(0x14c, 68); invalid.writeUInt16LE(0x10b, 88);
      await writeFile(runtime, invalid);
      await expect(assertPeX64(runtime)).rejects.toThrow('Expected Windows x64');
    } finally { await rm(root, { recursive: true, force: true }); }
  });
  it('rejects missing executables, leaked environment files and output folders', async () => {
    const root = await mkdtemp(resolve(tmpdir(), 'inspector-audit-'));
    try {
      await expect(verifyPackage(root, { versions: { production: {} } })).rejects.toThrow('Missing release requirement');
      await writeFile(resolve(root, '.env'), 'OPENROUTER_API_KEY=');
      await expect(inventory(root)).rejects.toThrow('Private path');
      await rm(resolve(root, '.env'));
      await mkdir(resolve(root, 'output')); await writeFile(resolve(root, 'output/result.json'), '{}');
      await expect(inventory(root)).rejects.toThrow('Private path');
    } finally { await rm(root, { recursive: true, force: true }); }
  });
});

it('requires exact checked-in OCR assets and rejects extra tools, omitted notice and hash corruption',async()=>{
 const root=await mkdtemp(resolve(tmpdir(),'t8-assets-'));
 try{
  await cp(new URL('../fixtures/ocr-assets/',import.meta.url),root,{recursive:true});
  await expect(verifyFixtureAssets(root)).resolves.toHaveLength(19);
  await writeFile(resolve(root,'generator.py'),'not deployed');await expect(verifyFixtureAssets(root)).rejects.toThrow('Unexpected or missing');await rm(resolve(root,'generator.py'));
  await writeFile(resolve(root,'korean.png'),'corrupt');await expect(verifyFixtureAssets(root)).rejects.toThrow('bytes differ');
  await rm(resolve(root,'FONT-NOTICE.txt'));await expect(verifyFixtureAssets(root)).rejects.toThrow('Unexpected or missing');
 }finally{await rm(root,{recursive:true,force:true});}
});
