import { mkdir, readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const app = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = await readFile(resolve(app, '../../docs/submission/proposal.md'), 'utf8');
const escape = text => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
const pages = source.split('<!-- page -->').map(page => page.trim().split(/\n\s*\n/).map(block => {
  if (block.startsWith('# ')) return `<h1>${escape(block.slice(2))}</h1>`;
  return `<p>${escape(block)}</p>`;
}).join(''));
if (pages.length < 5 || pages.length > 10) throw new Error('기획서 페이지 수는 5~10이어야 합니다.');
const browser = await chromium.launch({ headless: true, ...(process.env.INSPECTOR_CHROMIUM_PATH ? { executablePath: process.env.INSPECTOR_CHROMIUM_PATH } : {}) });
try {
  const page = await browser.newPage();
  await page.setContent(`<meta charset="utf-8"><style>@page{size:A4;margin:0}*{box-sizing:border-box}body{margin:0;font-family:"Noto Sans CJK KR",sans-serif;color:#172538}article{height:297mm;padding:22mm 21mm;break-after:page;position:relative}article:last-child{break-after:auto}h1{font-size:21pt;line-height:1.4;margin:0 0 13mm}p{font-size:11pt;line-height:1.9;margin:0 0 7mm;word-break:keep-all}footer{position:absolute;bottom:14mm;right:21mm;font-size:9pt;color:#657386}</style>${pages.map((body, i) => `<article><main>${body}</main><footer>${i + 1} / ${pages.length}</footer></article>`).join('')}`);
  await page.evaluate('document.fonts.ready');
  const overflow = await page.locator('article').evaluateAll(items => items.some(item => item.querySelector('main').getBoundingClientRect().bottom > item.getBoundingClientRect().bottom - 80));
  if (overflow) throw new Error('기획서 내용이 페이지의 인쇄 영역을 넘습니다.');
  const output = resolve(app, 'release/docs/기획서.pdf');
  await mkdir(dirname(output), { recursive: true });
  await page.pdf({ path: output, format: 'A4', printBackground: true });
  console.log(`기획서 ${pages.length}쪽 생성: ${output}`);
} finally { await browser.close(); }
