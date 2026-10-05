import { describe, expect, it } from 'vitest';
import type { CollectedElement, CollectedFrame, CollectedPage } from '../../src/core/types.js';
import { analyzeText, detectPage, normalizeText } from '../../src/detection/index.js';
import { findingTruth, negativeTruth } from '../fixtures/truth.js';

const bounds = { x: 12, y: 12, width: 500, height: 24 };
function element(location: string, rawText: string, css: Record<string, string> = {}): CollectedElement {
  return { location, rawText, links: [], tagName: 'P', attributes: {}, contextText: '',
    accessibility: { role: null, ariaHidden: null, ariaLabel: null }, bounds: { ...bounds }, documentBounds: { ...bounds },
    styles: [{ elementLocation: location, css: { color: 'rgb(0, 0, 0)', 'background-color': 'rgba(0, 0, 0, 0)', opacity: '1', 'font-size': '16px', display: 'block', position: 'static', ...css }, bounds: { ...bounds } }] };
}
function frame(elements: CollectedElement[], framePath: string[] = []): CollectedFrame {
  return { frameUrl: 'https://frame.example/document', framePath, html: '', elements,
    viewport: { width: 1024, height: 768, scrollX: 0, scrollY: 0 }, documentSize: { width: 1024, height: 6000 }, snapshotId: 'snap-1', capturedAt: '2026-10-04T00:00:00Z' };
}
function page(elements: CollectedElement[]): CollectedPage {
  return { url: 'https://public.example/cases/types?entry=1', frames: [frame(elements)], discoveredUrls: [], capturedAt: '2026-10-04T00:00:00Z' };
}
const ad = '온라인 카지노 가입 배팅 보너스 받으세요';

// This style table is hand-authored from the fixture markup, independent of production rules.
const fixtureCss: Record<string, Record<string, string>> = {
  opacity: { opacity: '0' }, transparent: { color: 'rgba(0, 0, 0, 0)' },
  'same-color': { color: 'rgb(255, 255, 255)', 'background-color': 'rgb(255, 255, 255)' },
  'zero-font': { 'font-size': '0px' }, 'one-font': { 'font-size': '1px' },
  'display-none': { display: 'none' }, 'left-outside': { position: 'absolute', left: '-9999px' },
  'long-tail': { opacity: '0' }, combined: { opacity: '0', 'font-size': '0px' },
  'duplicate-a': { opacity: '0' }, 'duplicate-b': { opacity: '0' },
};

describe('DOM-confirmed concealment and independent fixture truth', () => {
  it('matches all four techniques, preserves long-tail raw evidence and duplicate locations', () => {
    const truths = findingTruth.filter(item => item.pagePath === '/cases/types');
    const owners = [...new Set(truths.map(item => item.caseId))].map(caseId => {
      const truth = truths.find(item => item.caseId === caseId)!;
      const owner = element(truth.selector, truth.rawEvidence, fixtureCss[caseId]);
      if (caseId === 'ancestor') owner.styles.push({ elementLocation: 'section', css: { opacity: '0' }, bounds });
      return owner;
    });
    const input = page(owners);
    const original = structuredClone(input);
    const candidates = detectPage(input);
    const actual = candidates.flatMap(candidate => candidate.techniques.map(technique => ({
      selector: candidate.location, rawEvidence: candidate.rawText, technique,
    })));
    expect(actual).toEqual(truths.map(item => ({ selector: item.selector, rawEvidence: item.rawEvidence, technique: item.technique })));
    expect(candidates.every(item => item.sourceType === 'dom_text' && item.observationIds.length > 0)).toBe(true);
    expect(candidates.every(item => !('localDecision' in item) && !('ruleIds' in item))).toBe(true);
    expect(new Set(candidates.map(item => item.candidateId)).size).toBe(candidates.length);
    expect(input).toEqual(original);
  });

  it('keeps CSS accessibility observations and ordinary below-fold content out', () => {
    const owners = negativeTruth.map(item => element(item.selector, item.rawEvidence));
    owners[3].styles[0].css = { position: 'absolute', left: '-9999px', 'font-size': '1px' };
    owners[3].attributes = { href: '#content' }; owners[3].tagName = 'A';
    owners[4].bounds.y = 2400; owners[4].documentBounds.y = 2400;
    const result = detectPage(page(owners));
    expect(result.map(item => [item.location, item.techniques])).toEqual([['#accessibility', ['OFFSCREEN']]]);
  });

  it('normalizes disguised words separately while preserving ordinary numbers and Unicode boundaries', () => {
    expect(normalizeText('cаsinо cas1n0 ㅋㅏㅈㅣㄴㅗ 카지노')).toBe('casino casino 카지노 카지노');
    expect(normalizeText('2026년 예산 1000원 010-1234-5678 abc1 1st')).toBe('2026년 예산 1000원 010-1234-5678 abc1 1st');
    expect(normalizeText('ㅎㅏㄴㄱㅡㄹ ㄱㅏㄴㅏ ㄱㅏㄱ ㅋ + ㅏ ㅋ ㅏ')).toBe('한글 가나 각 ㅋ + ㅏ ㅋ ㅏ');
    expect(normalizeText('각 ᄀ ᅡ ㅏ ㄱ ㅘ')).toBe('각 ᄀ ᅡ ㅏ ㄱ ㅘ');
    expect(detectPage(page([element('#number', 'cas100 가입 2026 배팅')]))).toEqual([]);
  });

  it('uses inherited opacity but owner foreground and effective ancestor background', () => {
    const hidden = element('#hidden', ad);
    hidden.styles.push({ elementLocation: '#parent', css: { opacity: '0' }, bounds });
    const same = element('#same', ad, { color: '#fff' });
    same.styles.push({ elementLocation: '#parent', css: { 'background-color': '#fff' }, bounds });
    const different = element('#different', ad, { color: '#000' });
    different.styles.push({ elementLocation: '#parent', css: { color: '#fff', 'background-color': '#fff' }, bounds });
    expect(detectPage(page([hidden, same, different])).map(item => item.location)).toEqual(['#hidden', '#same']);
  });

  it('uses document coordinates to distinguish scrolled content from abnormal positioning', () => {
    const above = element('#above', ad, { position: 'static' });
    above.bounds.y = -100; above.documentBounds.y = 20;
    const below = element('#below', ad); below.bounds.y = 3000; below.documentBounds.y = 3000;
    const hidden = element('#hidden', ad, { position: 'absolute' });
    hidden.bounds.x = -10000; hidden.documentBounds.x = -10000;
    const input = page([above, below, hidden]); input.frames[0].viewport.scrollY = 120;
    expect(detectPage(input).map(item => item.location)).toEqual(['#hidden']);
  });

  it('observes all hidden text without advertising, education, reporting or accessibility keyword filtering', () => {
    const owners = [
      element('#news', '경찰 보도: "cаsinо 가입 배팅 보너스" 광고를 단속했습니다.', { opacity: '0' }),
      element('#warning', '불법 카지노 가입 배팅 보너스를 홍보하는 링크를 클릭하지 마세요.', { opacity: '0' }),
      element('#lesson', '한글 수업: ㅋㅏㅈㅣㄴㅗ 자모 설명', { opacity: '0' }),
      element('#general', '서점 신간 가입 이벤트 홍보', { opacity: '0' }),
      element('#keyword', '카지노', { opacity: '0' }),
      element('#ambiguous', '카지노 광고 상담 안내', { opacity: '0' }),
      element('#css', '단순 문장', { opacity: '0' }),
      element('#adult', '성인 영상 가입 보너스 지금 접속 https://adult.invalid', { opacity: '0' }),
    ];
    const candidates = detectPage(page(owners));
    expect(candidates.map(item => item.location)).toEqual(owners.map(item => item.location));
    expect(candidates.every(item => item.observationIds.length > 0)).toBe(true);
    expect(candidates.every(item => !('localDecision' in item) && !('ruleIds' in item))).toBe(true);
  });

  it('retains top URL, separate frame URL, complete iframe identity and stable owner IDs', () => {
    const input = page([]);
    input.frames = [
      frame([element('iframe#a >>> iframe#nested >>> #ad', ad, { opacity: '0' })], ['iframe#a', 'iframe#nested']),
      frame([element('iframe#b >>> iframe#nested >>> #ad', ad, { opacity: '0' })], ['iframe#b', 'iframe#nested']),
    ];
    const result = detectPage(input);
    expect(result.map(item => item.location)).toEqual(['iframe#a >>> iframe#nested >>> #ad', 'iframe#b >>> iframe#nested >>> #ad']);
    expect(result.every(item => item.url === input.url && item.frameUrl === input.frames[0].frameUrl)).toBe(true);
    expect(result[0].evidence).toEqual({ snapshotId: 'snap-1', path: null, sha256: null });
    expect(result[0].candidateId).not.toBe(result[1].candidateId);
    expect(detectPage(input)).toEqual(result);
  });

  it('composes attached Jamo and compound compatibility vowels/finals without crossing punctuation', () => {
    expect(normalizeText('복원ㅋㅏㅈㅣㄴㅗ가입')).toBe('복원카지노가입');
    expect(normalizeText('ㄱㅗㅏ ㄱㅏㄹㄱ ㄱㅏㄹㄱㅏ ㄱㅏ!ㄴㅏ')).toBe('과 갉 갈가 가!나');
    const analysis = analyzeText('원문 cas1n0 ㅋㅏㅈㅣㄴㅗ');
    expect(analysis.changes.map(item => [item.raw, item.restored, item.start, item.end])).toEqual([['cas1n0', 'casino', 3, 9], ['ㅋㅏㅈㅣㄴㅗ', '카지노', 10, 16]]);
  });

  it('does not mistake an ordinary Cyrillic-language word for mixed-script camouflage', () => {
    expect(detectPage(page([element('#russian', 'Россия 2026')]))).toEqual([]);
  });

  it('ignores parent context and preserves uncertain style observation diagnostics', () => {
    const owner = element('#local', 'cаsinо');
    owner.contextText = '가입하고 보너스 받으세요'; owner.links = ['https://casino.invalid'];
    const clipping = element('#clip', ad, { clip: 'rect(0px, 0px, 0px, 0px)', position: 'absolute' });
    const visibility = element('#visibility', ad, { visibility: 'hidden' });
    const input = page([owner, clipping, visibility]);
    const candidates = detectPage(input);
    expect(candidates.map(item => item.rawText)).toEqual([owner.rawText, clipping.rawText, visibility.rawText]);
    expect(candidates[0].links).toEqual(owner.links);
    expect(candidates.slice(1).every(item => item.observationIds.includes('STYLE_AMBIGUOUS_CONCEALMENT'))).toBe(true);
    owner.contextText = '기사 교육 접근성';
    expect(detectPage(input)).toEqual(candidates);
  });

  it('requires equal rendered colors, rather than assuming nearly transparent text is invisible', () => {
    const faint = element('#faint', ad, { color: 'rgba(0, 0, 0, 0.001)', 'background-color': '#fff' });
    expect(detectPage(page([faint]))).toEqual([]);
  });
});
