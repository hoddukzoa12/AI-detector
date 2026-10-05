import { createServer } from 'node:http';
import { chromium } from 'playwright';
import { expect, it } from 'vitest';
import { crawl } from '../../src/crawler/index.js';
import { detectPage } from '../../src/detection/index.js';

it('실제 수집한 소유자·조상 그라데이션 배경의 선명한 글자를 투명 은닉으로 확정하지 않는다', async () => {
  const rawText = '카지노 가입 지금 방문 보너스';
  const markup = `<!doctype html><html><body><main style="background-color:white">
    <p id="visible-owner" style="color:white;background-color:white;background-image:linear-gradient(black,black)">${rawText}</p>
    <section id="ancestor-gradient" style="background-color:white;background-image:linear-gradient(black,black)">
      <p id="visible-child" style="color:white">${rawText}</p>
    </section>
    <p id="hidden-same-color" style="color:white;background-color:white">${rawText}</p>
    <p id="hidden-opacity" style="color:white;background-color:white;background-image:linear-gradient(black,black);opacity:0">${rawText}</p>
  </main></body></html>`;
  const server = createServer((_request, response) => {
    response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }); response.end(markup);
  });
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const address = server.address(); if (!address || typeof address === 'string') throw new Error('테스트 TCP 주소가 없습니다');
    const collected = await crawl(`http://127.0.0.1:${address.port}/`, {
      executablePath: process.env.INSPECTOR_CHROMIUM_PATH ?? chromium.executablePath(), dynamicWaitMs: 0, resourceWaitMs: 500,
      scrollSteps: 0, maxPages: 1, concurrency: 1,
    });
    expect(collected.state).toBe('completed'); expect(collected.pages).toHaveLength(1);
    const page = collected.pages[0]; const candidates = detectPage(page);
    expect(candidates.filter(candidate => ['#visible-owner', '#visible-child'].includes(candidate.location))).toEqual([]);
    expect(candidates.map(candidate => ({ location: candidate.location, techniques: candidate.techniques }))
      .sort((left, right) => left.location.localeCompare(right.location))).toEqual([
      { location: '#hidden-opacity', techniques: ['TRANSPARENT'] },
      { location: '#hidden-same-color', techniques: ['TRANSPARENT'] },
    ]);
    for (const location of ['#visible-owner', '#visible-child']) {
      const element = page.frames[0].elements.find(element => element.location === location)!;
      expect(element.rawText).toBe(rawText); expect(element.bounds.width).toBeGreaterThan(0); expect(element.bounds.height).toBeGreaterThan(0);
      expect(element.styles[0].css.color).toBe('rgb(255, 255, 255)');
      const background = location === '#visible-owner' ? element.styles[0] : element.styles.find(style => style.elementLocation === '#ancestor-gradient')!;
      expect(background.css['background-image']).toBe('linear-gradient(rgb(0, 0, 0), rgb(0, 0, 0))');
    }
    expect(page.frames[0].html).toContain('background-image:linear-gradient(black,black)');
    expect(page.frames[0].elements.every(element => element.styles.every(style => typeof style.css['background-image'] === 'string'))).toBe(true);
  } finally {
    await new Promise<void>((resolve, reject) => { server.close(error => error ? reject(error) : resolve()); server.closeAllConnections(); });
  }
});
