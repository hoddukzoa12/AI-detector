/** Hand-authored ground truth: never imports a production detector or derives labels from CSS. */
export type FixtureTechnique = 'HOMOGLYPH' | 'JAMO' | 'TRANSPARENT' | 'OFFSCREEN';
export interface FindingTruth {
  caseId: string;
  pagePath: string;
  framePath: string[];
  selector: string;
  rawEvidence: string;
  technique: FixtureTechnique;
}
export interface NegativeTruth { caseId: string; selector: string; rawEvidence: string; rationale: string }

export const longTailText = '공개 게시판의 정상적인 안내 문장입니다. '.repeat(35) + '불법 온라인 카지노 가입하고 배팅 보너스 받으세요 https://casino.invalid';
export const findingTruth: readonly FindingTruth[] = [
  { caseId: 'homo-cyrillic', pagePath: '/cases/types', framePath: [], selector: '#homo-cyrillic', rawEvidence: '온라인 cаsinо 가입 배팅 보너스 https://casino.invalid', technique: 'HOMOGLYPH' },
  { caseId: 'homo-number', pagePath: '/cases/types', framePath: [], selector: '#homo-number', rawEvidence: '불법 cas1n0 가입 배팅 보너스 https://casino.invalid', technique: 'HOMOGLYPH' },
  { caseId: 'jamo', pagePath: '/cases/types', framePath: [], selector: '#jamo', rawEvidence: 'ㅋㅏㅈㅣㄴㅗ 가입하고 배팅 보너스 받으세요 https://casino.invalid', technique: 'JAMO' },
  { caseId: 'jamo-modern', pagePath: '/cases/types', framePath: [], selector: '#jamo-modern', rawEvidence: '카지노 가입하고 배팅 보너스 받으세요 https://casino.invalid', technique: 'JAMO' },
  { caseId: 'opacity', pagePath: '/cases/types', framePath: [], selector: '#opacity', rawEvidence: '온라인 카지노 가입 배팅 보너스 opacity', technique: 'TRANSPARENT' },
  { caseId: 'transparent', pagePath: '/cases/types', framePath: [], selector: '#transparent', rawEvidence: '온라인 카지노 가입 배팅 보너스 transparent', technique: 'TRANSPARENT' },
  { caseId: 'same-color', pagePath: '/cases/types', framePath: [], selector: '#same-color', rawEvidence: '온라인 카지노 가입 배팅 보너스 same-color', technique: 'TRANSPARENT' },
  { caseId: 'ancestor', pagePath: '/cases/types', framePath: [], selector: '#ancestor-child', rawEvidence: '온라인 카지노 가입 배팅 보너스 ancestor', technique: 'TRANSPARENT' },
  { caseId: 'zero-font', pagePath: '/cases/types', framePath: [], selector: '#zero-font', rawEvidence: '온라인 카지노 가입 배팅 보너스 zero-font', technique: 'OFFSCREEN' },
  { caseId: 'one-font', pagePath: '/cases/types', framePath: [], selector: '#one-font', rawEvidence: '온라인 카지노 가입 배팅 보너스 one-font', technique: 'OFFSCREEN' },
  { caseId: 'display-none', pagePath: '/cases/types', framePath: [], selector: '#display-none', rawEvidence: '온라인 카지노 가입 배팅 보너스 display-none', technique: 'OFFSCREEN' },
  { caseId: 'left-outside', pagePath: '/cases/types', framePath: [], selector: '#left-outside', rawEvidence: '온라인 카지노 가입 배팅 보너스 left-outside', technique: 'OFFSCREEN' },
  { caseId: 'long-tail', pagePath: '/cases/types', framePath: [], selector: '#long-tail', rawEvidence: longTailText, technique: 'TRANSPARENT' },
  { caseId: 'combined', pagePath: '/cases/types', framePath: [], selector: '#combined', rawEvidence: '온라인 카지노 가입 배팅 보너스 복수 기법', technique: 'TRANSPARENT' },
  { caseId: 'combined', pagePath: '/cases/types', framePath: [], selector: '#combined', rawEvidence: '온라인 카지노 가입 배팅 보너스 복수 기법', technique: 'OFFSCREEN' },
  { caseId: 'duplicate-a', pagePath: '/cases/types', framePath: [], selector: '#duplicate-a', rawEvidence: '온라인 카지노 가입 배팅 보너스 중복 문구', technique: 'TRANSPARENT' },
  { caseId: 'duplicate-b', pagePath: '/cases/types', framePath: [], selector: '#duplicate-b', rawEvidence: '온라인 카지노 가입 배팅 보너스 중복 문구', technique: 'TRANSPARENT' },
  { caseId: 'query-one', pagePath: '/query?id=1', framePath: [], selector: '#query-one', rawEvidence: '온라인 카지노 가입 배팅 보너스 query-one', technique: 'TRANSPARENT' },
  { caseId: 'query-two', pagePath: '/query?id=2', framePath: [], selector: '#query-two', rawEvidence: '온라인 카지노 가입 배팅 보너스 query-two', technique: 'TRANSPARENT' },
  { caseId: 'frame-external', pagePath: '/cases/frames', framePath: ['iframe[src="{external}/frames/external"]'], selector: '#external-ad', rawEvidence: '온라인 카지노 가입 배팅 보너스 external-frame', technique: 'TRANSPARENT' },
  { caseId: 'frame-nested', pagePath: '/cases/frames', framePath: ['iframe[src="{external}/frames/external"]', 'iframe[src="{external}/frames/nested"]'], selector: '#nested-ad', rawEvidence: '온라인 카지노 가입 배팅 보너스 nested-frame', technique: 'OFFSCREEN' },
  { caseId: 'frame-relative', pagePath: '/cases/frames', framePath: ['iframe[src="{origin}/frames/relative"]'], selector: '#relative-ad', rawEvidence: '온라인 카지노 가입 배팅 보너스 relative-frame', technique: 'TRANSPARENT' },
  { caseId: 'frame-shared-a', pagePath: '/cases/frames', framePath: ['iframe#shared-a'], selector: '#shared-ad', rawEvidence: '온라인 카지노 가입 배팅 보너스 shared-frame', technique: 'TRANSPARENT' },
  { caseId: 'frame-shared-b', pagePath: '/cases/frames', framePath: ['iframe#shared-b'], selector: '#shared-ad', rawEvidence: '온라인 카지노 가입 배팅 보너스 shared-frame', technique: 'TRANSPARENT' },
  { caseId: 'frame-srcdoc', pagePath: '/cases/frames', framePath: ['iframe#inline-frame'], selector: '#srcdoc-ad', rawEvidence: '온라인 카지노 가입 배팅 보너스 srcdoc-frame', technique: 'TRANSPARENT' },
];

export const negativeTruth: readonly NegativeTruth[] = [
  { caseId: 'news', selector: '#news', rawEvidence: '경찰이 불법 카지노 광고와 도박 사이트를 단속했다는 보도입니다.', rationale: 'Reporting about illegal advertisements is not solicitation.' },
  { caseId: 'numbers', selector: '#numbers', rawEvidence: '2026년 예산은 1000원, 문의 전화는 010-1234-5678입니다.', rationale: 'Ordinary numerals are not a disguised advertising keyword.' },
  { caseId: 'jamo-explanation', selector: '#jamo-explanation', rawEvidence: '한글 수업: ㅋ + ㅏ = 카, ㅈ + ㅣ = 지. 자모를 설명합니다.', rationale: 'Teaching Jamo is not illegal advertising.' },
  { caseId: 'accessibility', selector: '#accessibility', rawEvidence: '메뉴 바로가기: 키보드 이용자는 Enter를 누르세요.', rationale: 'Visually hidden accessibility assistance is legitimate.' },
  { caseId: 'below-fold', selector: '#below-fold', rawEvidence: '온라인 카지노 광고 예방 교육 안내입니다. 도박 피해 신고는 1336.', rationale: 'Normal below-fold placement and public-interest advice are not hidden advertisements.' },
];
