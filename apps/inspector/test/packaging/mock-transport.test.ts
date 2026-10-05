import { describe, expect, it } from 'vitest';
import { createFixtureTransport } from '../../scripts/mock-transport.js';

describe('explicit deployment fixture HTTP transport', () => {
  it('delegates asset GETs, intercepts fixed provider endpoints and fails unknown PNGs without any paid fallback', async () => {
    let delegated = 0;
    const mock = createFixtureTransport(async () => { delegated++; return new Response('asset'); });
    expect(await (await mock.fetch('http://127.0.0.1:1234/assets/korean.png')).text()).toBe('asset');
    expect(delegated).toBe(1);
    await expect(mock.fetch('https://openrouter.ai/api/v1/chat/completions', { method: 'POST', body: JSON.stringify({ model: 'google/gemini-3.8-flash', messages: [{role:'user',content:[{type:'image_url',image_url:{url:'data:image/png;base64,iVBORw0KGgo='}}]}] }) })).rejects.toThrow('Unknown synthetic PNG');
    expect(delegated).toBe(1); expect(mock.counts()).toEqual({ ocr: 1, clef: 0 });
    await expect(mock.fetch('https://openrouter.ai/api/other')).rejects.toThrow('Unexpected provider endpoint');
    expect(delegated).toBe(1);
  });
  it('uses literal authored labels; a menu title never acquires the unrelated gambling sibling link', async () => {
    const mock = createFixtureTransport(async () => { throw new Error('Network must not run'); });
    for (const [rawText, choice] of [['MEMBER','non_ad'], ['MENU','non_ad'], ['불법 온라인 카지노 가입 배팅 보너스','illegal_ad']]) {
      const result = await (await mock.fetch('https://openrouter.ai/api/alpha/decisions',{ method:'POST',body:JSON.stringify({model:'cloudflare/clef', state:{rawText,normalizedText:rawText,links:[]}}) })).json();
      expect(result.answers.ad_class.choice).toBe(choice);
    }
    await expect(mock.fetch('https://openrouter.ai/api/alpha/decisions',{method:'POST',body:JSON.stringify({model:'cloudflare/clef',state:{rawText:'MEMBER',normalizedText:'MEMBER',links:['http://127.0.0.1:1234/destination']}})})).rejects.toThrow('title does not inherit sibling links');
    expect(mock.counts()).toEqual({ocr:0,clef:4});
  });
});
