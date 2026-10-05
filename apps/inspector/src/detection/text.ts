/** Only adjacent Jamo are composed. Spaces and punctuation remain evidence boundaries. */
const initials = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ';
const vowels = 'ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ';
const finals = ' ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ';
const compoundVowels: Record<string, string> = { 'ㅗㅏ': 'ㅘ', 'ㅗㅐ': 'ㅙ', 'ㅗㅣ': 'ㅚ', 'ㅜㅓ': 'ㅝ', 'ㅜㅔ': 'ㅞ', 'ㅜㅣ': 'ㅟ', 'ㅡㅣ': 'ㅢ' };
const compoundFinals: Record<string, string> = { 'ㄱㅅ': 'ㄳ', 'ㄴㅈ': 'ㄵ', 'ㄴㅎ': 'ㄶ', 'ㄹㄱ': 'ㄺ', 'ㄹㅁ': 'ㄻ', 'ㄹㅂ': 'ㄼ', 'ㄹㅅ': 'ㄽ', 'ㄹㅌ': 'ㄾ', 'ㄹㅍ': 'ㄿ', 'ㄹㅎ': 'ㅀ', 'ㅂㅅ': 'ㅄ' };
const lookalikes: Record<string, string> = {
  а: 'a', А: 'A', е: 'e', Е: 'E', о: 'o', О: 'O', с: 'c', С: 'C',
  р: 'p', Р: 'P', х: 'x', Х: 'X', у: 'y', У: 'Y', і: 'i', І: 'I',
  ј: 'j', Ј: 'J', ѕ: 's', Ѕ: 'S', к: 'k', К: 'K', м: 'm', М: 'M',
  т: 't', Т: 'T', ν: 'v', ο: 'o', Ο: 'O', α: 'a', ι: 'i',
};
const digitLetters: Record<string, string> = { '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't' };
// A digit substitution must reconstruct a whole advertising vocabulary word. Never alter numbers.
const disguisedWords = new Set(['casino', 'betting', 'poker', 'toto', 'porn', 'sex', 'adult', 'slot', 'slots', 'baccarat']);

export interface TextChange {
  start: number; end: number; raw: string; restored: string;
  kind: 'HOMOGLYPH_CYRILLIC' | 'HOMOGLYPH_NUMBER' | 'JAMO_COMPATIBILITY' | 'JAMO_MODERN';
}
export interface TextAnalysis { normalizedText: string; changes: TextChange[] }

function compatibilityRun(run: string): string {
  let result = '';
  for (let offset = 0; offset < run.length;) {
    const initial = initials.indexOf(run[offset]);
    let vowel = vowels.indexOf(run[offset + 1] ?? '');
    if (initial < 0 || offset + 1 >= run.length || vowel < 0) { result += run[offset++]; continue; }
    let consumed = 2;
    const compoundVowel = compoundVowels[run.slice(offset + 1, offset + 3)];
    if (compoundVowel) { vowel = vowels.indexOf(compoundVowel); consumed++; }
    let final = 0;
    const next = run[offset + consumed];
    if (next && finals.indexOf(next) > 0 && !(offset + consumed + 1 < run.length && vowels.includes(run[offset + consumed + 1]))) {
      final = finals.indexOf(next);
      const compoundFinal = compoundFinals[run.slice(offset + consumed, offset + consumed + 2)];
      const afterPair = run[offset + consumed + 2];
      consumed++;
      if (compoundFinal && !(afterPair && vowels.includes(afterPair))) { final = finals.indexOf(compoundFinal); consumed++; }
    }
    result += String.fromCodePoint(0xac00 + initial * 21 * 28 + vowel * 28 + final);
    offset += consumed;
  }
  return result;
}

/** Changes carry original UTF-16 offsets and the actual disguised spans, not inferred keywords. */
export function analyzeText(rawText: string): TextAnalysis {
  const changes: TextChange[] = [];
  const normalizedText = rawText.replace(/[\u1100-\u11ff]+|[\u3131-\u3163]+|(?:(?![\u1100-\u11ff\u3131-\u3163])[\p{L}\p{N}])+/gu, (raw: string, start: number) => {
    let restored = raw;
    if (/^[\u1100-\u11ff]+$/u.test(raw)) {
      restored = raw.normalize('NFC');
      if (restored !== raw) changes.push({ start, end: start + raw.length, raw, restored, kind: 'JAMO_MODERN' });
    } else if (/^[\u3131-\u3163]+$/u.test(raw)) {
      restored = compatibilityRun(raw);
      if (restored !== raw) changes.push({ start, end: start + raw.length, raw, restored, kind: 'JAMO_COMPATIBILITY' });
    } else {
      const mapped = raw.replace(/[аАеЕоОсСрРхХуУіІјЈѕЅкКмМтТνοΟαι]/gu, character => lookalikes[character]);
      const letters = /[a-z]/iu.test(raw) || disguisedWords.has(mapped.toLowerCase()) ? mapped : raw;
      if (letters !== raw) {
        restored = letters;
        changes.push({ start, end: start + raw.length, raw, restored, kind: 'HOMOGLYPH_CYRILLIC' });
      }
      if (/[a-z]/iu.test(letters) && /\d/u.test(letters)) {
        const numbered = letters.replace(/[013457]/gu, digit => digitLetters[digit]);
        if (numbered !== letters && disguisedWords.has(numbered.toLowerCase())) {
          restored = numbered;
          changes.push({ start, end: start + raw.length, raw, restored, kind: 'HOMOGLYPH_NUMBER' });
        }
      }
    }
    return restored;
  });
  return { normalizedText, changes };
}

export function normalizeText(rawText: string): string { return analyzeText(rawText).normalizedText; }
