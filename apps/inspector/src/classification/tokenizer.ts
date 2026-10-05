import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { Tokenizer } from '@huggingface/tokenizers';

/** Copy these resources next to a bundled Node entrypoint; no weights or runtime download. */
export const TOKENIZER_RESOURCE_DIRECTORY = new URL('./resources/', import.meta.url);
export const CLEF_TOKENIZER_REVISION = '2f3de3dd85f379784083b0814d997ab627200f0c';
let tokenizer: Tokenizer | undefined;
function load(name: string, hash: string): object {
  const bytes = readFileSync(new URL(name, TOKENIZER_RESOURCE_DIRECTORY));
  if (createHash('sha256').update(bytes).digest('hex') !== hash) throw new Error('CLEF tokenizer resource integrity failure');
  return JSON.parse(bytes.toString('utf8')) as object;
}
export function getClefTokenizer(): Tokenizer {
  tokenizer ??= new Tokenizer(
    load('tokenizer.json', '06b9509352d2af50381ab2247e083b80d32d5c0aba91c272ca9ff729b6a0e523'),
    load('tokenizer_config.json', '91a08f825d370d085d692e04cf117cdd7faad7bf18e996f1e6031b6dab03db72'),
  );
  return tokenizer;
}
export interface CandidateState { rawText: string; normalizedText: string; links: string[] }
/** Measures the exact JSON sent as state, including property names, escaping and every link. */
export function countStateTokens(state: CandidateState): number {
  return getClefTokenizer().encode(JSON.stringify(state), { add_special_tokens: false }).ids.length;
}
