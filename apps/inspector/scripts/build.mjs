import { build } from 'esbuild';
import { cp, mkdir, access } from 'node:fs/promises';
import { OCR_FIXTURE_ASSETS } from './ocr-fixture-assets.mjs';

await mkdir('dist/public', { recursive: true });
const nodeBuild = { bundle: true, platform: 'node', target: 'node22', format: 'esm', packages: 'external', sourcemap: true };
await build({ ...nodeBuild, entryPoints: ['src/main.ts'], outfile: 'dist/main.mjs' });
await build({ entryPoints: ['src/web/index.ts'], outfile: 'dist/public/web.js', bundle: true, platform: 'browser', target: 'es2022', sourcemap: true });
await cp('src/web/index.html', 'dist/public/index.html');
await cp('src/web/styles.css', 'dist/public/web.css');
await cp('src/classification/resources', 'dist/resources', { recursive: true });
for (const [entry, output] of [['src/desktop/main.ts', 'desktop'], ['scripts/self-test.ts', 'self-test']]) {
  const exists = await access(entry).then(() => true, () => false);
  if (exists) await build({ ...nodeBuild, entryPoints: [entry], outfile: `dist/${output}.mjs` });
}
await mkdir('dist/ocr-assets', { recursive: true });
for (const name of OCR_FIXTURE_ASSETS) await cp(`test/fixtures/ocr-assets/${name}`, `dist/ocr-assets/${name}`);
