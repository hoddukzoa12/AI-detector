import { expect, it } from 'vitest';
import { chromium } from 'playwright';
import { captureDocument } from '../../src/dom/index.js';

it('preserves image concealment from owner, ancestor and pseudo styles without hiding scrollable or partially clipped content', async () => {
  const browser = await chromium.launch({ executablePath: process.env.INSPECTOR_CHROMIUM_PATH ?? chromium.executablePath() });
  try {
    const page = await browser.newPage({ viewport: { width: 800, height: 600 } });
    // All asset requests are intercepted: this test observes DOM/CSS, without acquisition or external traffic.
    await page.route('**/*', route => route.abort());
    await page.setContent(`<style>
      body{margin:0;width:2200px;height:2200px}
      .asset{display:block;width:20px;height:20px;background-image:url("https://asset.invalid/image.png")}
      #left{position:fixed;left:-1000px;top:0}#top{position:fixed;left:0;top:-1000px}
      #right{position:fixed;left:1000px;top:0}#bottom{position:fixed;left:0;top:1000px}
      #right-offset{position:fixed;right:-1000px;top:0}#bottom-offset{position:fixed;left:0;bottom:-1000px}
      #fixed-visible{position:fixed;left:100px;top:100px}#fixed-partial{position:fixed;left:790px;top:590px}
      #ancestor-right{position:fixed;left:1000px;top:0}#ancestor-bottom{position:fixed;left:0;top:1000px}
      #clipped,#ancestor-clipped{clip-path:inset(50%)}
      #rect-clipped,#ancestor-rect{position:absolute;clip:rect(0px,0px,0px,0px)}
      #partial{clip-path:inset(25%)}#partial-rect{position:absolute;clip:rect(0px,10px,10px,0px)}
      #scroll-below{position:absolute;top:1800px}#scroll-right{position:absolute;left:1800px;top:0}
      #scroll-origin{position:absolute;left:0;top:0}#font-zero{font-size:0}#font-one{font-size:1px}
      #none{display:none}#hidden{visibility:hidden}#transparent{opacity:0}#small{width:1px;height:1px}
      #pseudo-fixed,#pseudo-clipped,#pseudo-partial{width:20px;height:20px}
      #pseudo-fixed::before,#pseudo-clipped::after,#pseudo-partial::before{content:"";display:block;width:20px;height:20px;background-image:url("https://asset.invalid/pseudo.png")}
      #pseudo-fixed::before{position:fixed;left:1000px;top:0}
      #pseudo-clipped::after{clip-path:inset(50%)}#pseudo-partial::before{clip-path:inset(25%)}
      #pseudo-bottom{width:20px;height:20px}#pseudo-bottom::after{content:"";width:20px;height:20px;position:fixed;left:0;bottom:-1000px;background-image:url("https://asset.invalid/pseudo.png")}
      #transformed-container{position:absolute;left:1000px;top:1600px;transform:translateX(0)}#transformed-fixed{position:fixed;left:0;top:0}
    </style>
    <div id="left" class="asset"></div><div id="top" class="asset"></div><div id="right" class="asset"></div><div id="bottom" class="asset"></div>
    <div id="right-offset" class="asset"></div><div id="bottom-offset" class="asset"></div><div id="fixed-visible" class="asset"></div><div id="fixed-partial" class="asset"></div>
    <div id="ancestor-right"><div id="child-right" class="asset"></div></div><div id="ancestor-bottom"><div id="child-bottom" class="asset"></div></div>
    <div id="clipped" class="asset"></div><div id="ancestor-clipped"><div id="child-clipped" class="asset"></div></div>
    <div id="rect-clipped" class="asset"></div><div id="ancestor-rect"><div id="child-rect" class="asset"></div></div>
    <div id="partial" class="asset"></div><div id="partial-rect" class="asset"></div>
    <div id="scroll-below" class="asset"></div><div id="scroll-right" class="asset"></div><div id="scroll-origin" class="asset"></div>
    <img id="font-zero" class="asset" src="https://asset.invalid/img.png"><img id="font-one" class="asset" src="https://asset.invalid/img.png">
    <div id="none" class="asset"></div><div id="hidden" class="asset"></div><div id="transparent" class="asset"></div><div id="small" class="asset"></div>
    <div id="ancestor-none" style="display:none"><div id="child-none" class="asset"></div></div>
    <div id="ancestor-hidden" style="visibility:hidden"><div id="child-hidden" class="asset"></div></div>
    <div id="ancestor-transparent" style="opacity:0"><div id="child-transparent" class="asset"></div></div>
    <div id="pseudo-fixed"></div><div id="pseudo-clipped"></div><div id="pseudo-partial"></div><div id="pseudo-bottom"></div>
    <div id="transformed-container"><div id="transformed-fixed" class="asset"></div></div>`);
    const before = await page.content();
    const observedStyles = () => page.locator('[id]').evaluateAll(elements => elements.map(element => {
      const properties = ['display', 'visibility', 'opacity', 'font-size', 'position', 'left', 'top', 'right', 'bottom', 'width', 'height', 'clip', 'clip-path', 'transform', 'background-image'];
      return { id: element.id, styles: [null, '::before', '::after'].map(pseudo => {
        const style = getComputedStyle(element, pseudo);
        return Object.fromEntries(properties.map(property => [property, style.getPropertyValue(property)]));
      }) };
    }));
    const stylesBefore = await observedStyles();
    const options = { framePath: [], maxElements: 1000, maxHtmlBytes: 1000000, captureImages: true };
    const data = await page.evaluate(captureDocument, options);
    for (const id of ['left', 'top', 'right', 'bottom', 'right-offset', 'bottom-offset', 'child-right', 'child-bottom', 'clipped', 'child-clipped', 'rect-clipped', 'child-rect', 'none', 'hidden', 'small', 'child-none', 'child-hidden', 'pseudo-fixed', 'pseudo-bottom', 'pseudo-clipped']) {
      const images = data.images.filter(image => image.location === '#' + id);
      expect(images.length, id).toBeGreaterThan(0);
      for (const image of images) expect.soft(image.concealment, id).toContain('OFFSCREEN');
    }
    for (const id of ['transparent', 'child-transparent']) expect(data.images.find(image => image.location === '#' + id)!.concealment, id).toEqual(['TRANSPARENT']);
    for (const id of ['partial', 'partial-rect', 'fixed-visible', 'fixed-partial', 'transformed-fixed', 'scroll-below', 'scroll-right', 'scroll-origin', 'font-zero', 'font-one', 'pseudo-partial']) {
      const images = data.images.filter(image => image.location === '#' + id);
      expect(images.length, id).toBeGreaterThan(0);
      for (const image of images) expect(image.concealment, id).toEqual([]);
    }
    expect(data.images.find(image => image.location === '#child-clipped')!.styles.find(style => style.elementLocation === '#ancestor-clipped')!.css['clip-path']).toBe('inset(50%)');
    expect(data.images.find(image => image.location === '#pseudo-fixed')!.styles[0]!.css.position).toBe('fixed');
    await page.evaluate(() => scrollTo(1000, 1000));
    const scrolled = await page.evaluate(captureDocument, options);
    expect(scrolled.viewport).toMatchObject({ scrollX: 1000, scrollY: 1000 });
    expect.soft(scrolled.images.find(image => image.location === '#scroll-origin')!.concealment).toEqual([]);
    expect.soft(scrolled.images.find(image => image.location === '#scroll-below')!.concealment).toEqual([]);
    expect.soft(scrolled.images.find(image => image.location === '#scroll-right')!.concealment).toEqual([]);
    expect(scrolled.images.find(image => image.location === '#fixed-visible')!.concealment).toEqual([]);
    expect(scrolled.images.find(image => image.location === '#fixed-partial')!.concealment).toEqual([]);
    expect(scrolled.images.find(image => image.location === '#transformed-fixed')!.concealment).toEqual([]);
    expect(scrolled.images.find(image => image.location === '#right')!.concealment).toContain('OFFSCREEN');
    expect(await page.content()).toBe(before);
    expect(await observedStyles()).toEqual(stylesBefore);
  } finally { await browser.close(); }
}, 60000);

it('distinguishes actual fixed containing blocks from viewport-fixed images using computed ancestor CSS', async () => {
  const cases = [
    ['transform:translateX(0px)', true], ['filter:blur(0px)', true], ['perspective:100px', true],
    ['contain:layout', true], ['contain:paint', true], ['contain:strict', true], ['contain:content', true],
    ['will-change:transform', true], ['will-change:filter', true], ['will-change:perspective', true],
    ['content-visibility:auto', true], ['backdrop-filter:blur(0px)', true],
    ['transform:none', false], ['filter:none', false], ['perspective:none', false], ['contain:none', false],
    ['contain:size', false], ['contain:style', false], ['will-change:auto', false], ['will-change:opacity', false],
    ['backdrop-filter:none', false],
  ] as const;
  const browser = await chromium.launch({ executablePath: process.env.INSPECTOR_CHROMIUM_PATH ?? chromium.executablePath() });
  try {
    const page = await browser.newPage({ viewport: { width: 800, height: 600 } });
    await page.route('**/*', route => route.abort());
    await page.setContent(`<style>
      body{margin:0;width:3200px;height:2200px}
      .container{position:absolute;left:0;top:1600px;width:1200px;height:100px}
      .asset,.pseudo::before{position:fixed;left:1000px;top:0;width:20px;height:20px;background-image:url("https://asset.invalid/image.png")}
      .pseudo{width:20px;height:20px}.pseudo::before{content:"";background-color:red}
    </style>` + cases.map(([css], index) => `<div id="container-${index}" class="container" style="${css}"><div id="child-${index}" class="asset"></div><div id="pseudo-${index}" class="pseudo"></div></div>`).join(''));
    const htmlBefore = await page.content();
    const options = { framePath: [], maxElements: 1000, maxHtmlBytes: 1000000, captureImages: true };
    const data = await page.evaluate(captureDocument, options);
    expect(data.images).toHaveLength(cases.length * 2);
    for (const [index, [css, containingBlock]] of cases.entries()) {
      const image = data.images.find(image => image.location === '#child-' + index)!;
      // These positions are measured in Chromium, independently of concealment classification.
      expect(image.bounds, css).toEqual({ x: 1000, y: containingBlock ? 1600 : 0, width: 20, height: 20 });
      expect.soft(image.concealment, css).toEqual(containingBlock ? [] : ['OFFSCREEN']);
      expect.soft(data.images.find(image => image.location === '#pseudo-' + index)!.concealment, css + ' pseudo').toEqual(containingBlock ? [] : ['OFFSCREEN']);
    }
    await page.evaluate(() => scrollTo(1000, 1600));
    const scrolled = await page.evaluate(captureDocument, options);
    expect(scrolled.viewport).toMatchObject({ scrollX: 1000, scrollY: 1600 });
    for (const [index, [css, containingBlock]] of cases.entries()) {
      const image = scrolled.images.find(image => image.location === '#child-' + index)!;
      expect(image.bounds, css).toEqual({ x: containingBlock ? 0 : 1000, y: 0, width: 20, height: 20 });
      expect.soft(image.concealment, css + ' scrolled').toEqual(containingBlock ? [] : ['OFFSCREEN']);
      expect.soft(scrolled.images.find(image => image.location === '#pseudo-' + index)!.concealment, css + ' scrolled pseudo').toEqual(containingBlock ? [] : ['OFFSCREEN']);
    }
    expect(await page.content()).toBe(htmlBefore);
  } finally { await browser.close(); }
}, 60000);

it('keeps ignored rect clips and box-adjusted visible fixed pseudos unconcealed', async () => {
  const browser = await chromium.launch({ executablePath: process.env.INSPECTOR_CHROMIUM_PATH ?? chromium.executablePath() });
  try {
    const page = await browser.newPage({ viewport: { width: 800, height: 600 } });
    await page.route('**/*', route => route.abort());
    await page.setContent(`<style>
      .asset{width:20px;height:20px;background-image:url("https://asset.invalid/image.png")}
      #static,#relative{clip:rect(0px,0px,0px,0px)}#relative{position:relative}
      #margin-owner,#padding-owner,#border-owner{width:20px;height:20px}
      #margin-owner::before,#padding-owner::before,#border-owner::before{content:"";position:fixed;width:20px;height:20px;background-color:red;background-image:url("https://asset.invalid/pseudo.png")}
      #margin-owner::before{left:1000px;top:300px;margin-left:-1000px}
      #padding-owner::before{left:-100px;top:350px;padding-left:150px}
      #border-owner::before{left:-100px;top:400px;border-left:150px solid red}
    </style><div id="static" class="asset"></div><div id="relative" class="asset"></div>
    <div id="margin-owner"></div><div id="padding-owner"></div><div id="border-owner"></div>`);
    // Hit testing proves the fixed pseudo boxes are actually visible even though their offsets alone look outside.
    const hits = await page.evaluate(() => [[10, 310], [10, 360], [10, 410]].map(([x, y]) => document.elementFromPoint(x!, y!)?.id));
    expect(hits).toEqual(['margin-owner', 'padding-owner', 'border-owner']);
    const boundsBefore = await page.locator('[id]').evaluateAll(elements => elements.map(element => {
      const { x, y, width, height } = element.getBoundingClientRect();
      return { id: element.id, bounds: { x, y, width, height } };
    }));
    const htmlBefore = await page.content();
    const data = await page.evaluate(captureDocument, { framePath: [], maxElements: 100, maxHtmlBytes: 100000, captureImages: true });
    expect(data.images).toHaveLength(5);
    for (const image of data.images) {
      expect.soft(image.concealment, image.location).toEqual([]);
      expect(image.bounds).toEqual(boundsBefore.find(owner => '#' + owner.id === image.location)!.bounds);
    }
    expect(data.images.find(image => image.location === '#static')!.styles[0]!.css.clip).toBe('rect(0px, 0px, 0px, 0px)');
    expect(await page.content()).toBe(htmlBefore);
    expect(await page.evaluate(() => [[10, 310], [10, 360], [10, 410]].map(([x, y]) => document.elementFromPoint(x!, y!)?.id))).toEqual(hits);
  } finally { await browser.close(); }
}, 60000);
