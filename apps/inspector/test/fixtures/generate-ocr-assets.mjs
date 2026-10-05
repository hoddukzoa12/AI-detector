/** Offline, synthetic fixture generator. Labels/text are human recipes, never model output. */
import { createHash } from 'node:crypto';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { chromium } from 'playwright';
const directory = new URL('./ocr-assets/', import.meta.url);
const recipes = JSON.parse(await readFile(new URL('recipes.json', directory), 'utf8'));
const escape = value => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
await mkdir(directory, { recursive: true });
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 640, height: 160 }, deviceScaleFactor: 1 });
  for (const item of recipes) {
    await page.setContent(`<!doctype html><html lang="ko"><meta charset="utf-8"><style>html,body{margin:0;width:640px;height:160px}body{display:flex;align-items:center;justify-content:center;background:${item.background};color:${item.foreground};font-family:"Noto Sans CJK KR";font-size:${item.fontSize ?? 30}px;font-weight:400;line-height:1.6;text-align:center;white-space:pre-line}.text{filter:blur(${item.blur ?? 0}px)}.shape{width:100px;height:100px;border-radius:50%;background:${item.foreground}}</style><body>${item.text ? `<div class="text">${escape(item.text)}</div>` : '<div class="shape"></div>'}</body></html>`);
    // eslint-disable-next-line no-undef -- evaluated in Chromium's document
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: new URL(item.file, directory).pathname, animations: 'disabled' });
  }
} finally { await browser.close(); }
await writeFile(new URL('vector.svg', directory), '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="160"><rect width="640" height="160" fill="#fff"/><text x="30" y="95" fill="#000" font-family="Noto Sans CJK KR" font-size="32">공공 도서관 안내</text></svg>\n');
await writeFile(new URL('malformed.png', directory), Buffer.from('89504e470d0a1a0a0000000042524f4b', 'hex'));
const dir = directory.pathname;
execFileSync('convert', [dir + 'korean.png', '-quality', '92', dir + 'korean.jpg']);
execFileSync('convert', [dir + 'general.png', '-quality', '92', dir + 'general.webp']);
execFileSync('python3', ['-c', 'from PIL import Image; import sys; Image.open(sys.argv[1]).save(sys.argv[2], format="AVIF", quality=92)', dir + 'logo.png', dir + 'logo.avif']);
execFileSync('convert', ['-delay', '300', dir + 'korean.png', '-delay', '300', dir + 'logo.png', '-loop', '0', dir + 'animated.gif']);
execFileSync('python3', ['-c', 'from PIL import Image; import sys; image=Image.open(sys.argv[1]); image.seek(0); image.convert("RGBA").save(sys.argv[2])', dir + 'animated.gif', dir + 'animation-first.png']);
const descriptors = [...recipes.map(item => ({ id: item.id, file: item.file, mime: 'image/png' })),
  { id: 'vector', file: 'vector.svg', mime: 'image/svg+xml' },
  { id: 'jpeg', file: 'korean.jpg', mime: 'image/jpeg' },
  { id: 'webp', file: 'general.webp', mime: 'image/webp' },
  { id: 'avif', file: 'logo.avif', mime: 'image/avif' },
  { id: 'animation', file: 'animated.gif', mime: 'image/gif' },
  { id: 'animation-first', file: 'animation-first.png', mime: 'image/png' },
];
const manifest = [];
for (const item of descriptors) {
  const bytes = await readFile(new URL(item.file, directory));
  manifest.push({ ...item, width: 640, height: 160, frameIndex: 0, sha256: createHash('sha256').update(bytes).digest('hex'), byteLength: bytes.length });
}
await writeFile(new URL('manifest.json', directory), JSON.stringify(manifest, null, 2) + '\n');
console.log(`Generated ${manifest.length} synthetic assets; Chromium ${chromium.executablePath()}`);
