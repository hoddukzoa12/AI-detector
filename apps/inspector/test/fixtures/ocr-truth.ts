import { readFileSync } from 'node:fs';

/** Independent authored text and labels. Asset hashes describe bytes, never detector decisions. */
export type OcrFixtureLabel = 'illegal_ad' | 'general_ad' | 'non_ad' | 'unjudged';
export interface OcrAssetTruth {
  id: string; file: string; mime: string; sha256: string; byteLength: number;
  width: number; height: number; frameIndex: 0;
  text: string; label: OcrFixtureLabel; extractionStatus: 'readable' | 'no_text' | 'unreadable';
}
interface Recipe { id: string; text: string; label: OcrFixtureLabel; status: OcrAssetTruth['extractionStatus'] }
const recipes = JSON.parse(readFileSync(new URL('./ocr-assets/recipes.json', import.meta.url), 'utf8')) as Recipe[];
const manifest = JSON.parse(readFileSync(new URL('./ocr-assets/manifest.json', import.meta.url), 'utf8')) as Omit<OcrAssetTruth, 'text' | 'label' | 'extractionStatus'>[];
const relatedRecipe: Record<string, string> = { jpeg: 'korean', webp: 'general', avif: 'logo', animation: 'korean', 'animation-first': 'korean' };
export const assetTruth: readonly OcrAssetTruth[] = manifest.map(asset => {
  if (asset.id === 'vector') return { ...asset, text: '공공 도서관 안내', label: 'non_ad', extractionStatus: 'readable' };
  const recipe = recipes.find(item => item.id === (relatedRecipe[asset.id] ?? asset.id));
  if (!recipe) throw new Error(`Missing human recipe for ${asset.id}`);
  return { ...asset, text: recipe.status === 'unreadable' ? '' : recipe.text, label: recipe.label, extractionStatus: recipe.status };
});
export interface ImageOccurrenceTruth {
  id: string; pagePath: '/images'; framePath: string[]; selector: string;
  sourceKind: 'img' | 'css_background' | 'css_before' | 'css_after'; sourceIndex: number;
  assetId: string; directText: string; relatedHref: string | null; external: boolean; concealment: 'TRANSPARENT' | 'OFFSCREEN' | null;
}
const image = (id: string, assetId: string, options: Partial<ImageOccurrenceTruth> = {}): ImageOccurrenceTruth => ({
  id, pagePath: '/images', framePath: [], selector: '#' + id, sourceKind: 'img', sourceIndex: 0,
  assetId, directText: '', relatedHref: null, external: false, concealment: null, ...options,
});
export const imageTruth: readonly ImageOccurrenceTruth[] = [
  image('korean', 'korean'), image('english', 'english'), image('logo', 'logo'), image('cover', 'cover'),
  image('general', 'general'), image('article', 'article'), image('notice', 'notice'), image('no-text', 'no-text'), image('unreadable', 'unreadable'),
  image('selected', 'korean'),
  image('layers-top', 'korean', { selector: '#layers', sourceKind: 'css_background' }),
  image('layers-bottom', 'english', { selector: '#layers', sourceKind: 'css_background', sourceIndex: 1 }),
  image('before', 'general', { selector: '#pseudo', sourceKind: 'css_before' }),
  image('after', 'notice', { selector: '#pseudo', sourceKind: 'css_after' }),
  image('data', 'korean'), image('blob', 'english'), image('svg', 'vector'), image('animation', 'animation'),
  image('jpeg', 'jpeg'), image('webp', 'webp'), image('avif', 'avif'),
  image('transparent', 'korean', { concealment: 'TRANSPARENT' }), image('hidden', 'english', { concealment: 'OFFSCREEN' }),
  image('outside-image', 'korean', { concealment: 'OFFSCREEN' }),
  image('same-a', 'korean'), image('same-b', 'korean'), image('linked', 'korean', { relatedHref: '/destination' }),
  image('multi-img', 'korean', { selector: '#multi' }),
  image('multi-background', 'english', { selector: '#multi', sourceKind: 'css_background' }),
  image('multi-before', 'general', { selector: '#multi', sourceKind: 'css_before' }),
  image('multi-after', 'notice', { selector: '#multi', sourceKind: 'css_after' }),
  image('mixed', 'korean', { selector: '#mixed', sourceKind: 'css_background', directText: '불법 온라인 카지노 가입 배팅 보너스' }),
  image('external-asset', 'english'),
  image('shared-a-image', 'korean', { framePath: ['iframe#shared-a'], selector: '#frame-image' }),
  image('shared-b-image', 'korean', { framePath: ['iframe#shared-b'], selector: '#frame-image' }),
  image('external-image', 'english', { framePath: ['iframe#external'], selector: '#frame-image', external: true }),
  image('nested-image', 'notice', { framePath: ['iframe#external', 'iframe#nested'], selector: '#frame-image', external: true }),
  image('srcdoc-image', 'logo', { framePath: ['iframe#inline'], selector: '#frame-image' }),
  image('blank-image', 'cover', { framePath: ['iframe#blank'], selector: '#frame-image' }),
];
export interface MenuOwnerTruth {
  id: string; selector: string; rawText: string; label: 'non_ad' | 'illegal_ad';
  relatedHref: string | null; technique: 'TRANSPARENT' | 'OFFSCREEN' | null;
}
/** Eleven independent repetitions reproduce the observed 11 MEMBER + 11 MENU title negatives. */
export const menuTruth: readonly MenuOwnerTruth[] = [
  ...Array.from({ length: 11 }, (_, index) => [
    { id: `member-${index}`, selector: `#member-${index}`, rawText: 'MEMBER', label: 'non_ad' as const, relatedHref: null, technique: 'OFFSCREEN' as const },
    { id: `menu-${index}`, selector: `#menu-${index}`, rawText: 'MENU', label: 'non_ad' as const, relatedHref: null, technique: 'OFFSCREEN' as const },
  ]).flat(),
  { id: 'nearby-ad', selector: '#nearby-ad', rawText: '불법 온라인 카지노 가입 배팅 보너스', label: 'illegal_ad', relatedHref: '/destination', technique: 'TRANSPARENT' },
  { id: 'direct-parent', selector: '#direct-parent', rawText: '불법 온라인 카지노 가입 배팅 보너스', label: 'illegal_ad', relatedHref: '/destination', technique: 'TRANSPARENT' },
  { id: 'direct-child', selector: '#direct-child', rawText: '불법 온라인 카지노 가입 배팅 보너스', label: 'illegal_ad', relatedHref: '/destination', technique: 'TRANSPARENT' },
  { id: 'tiny-parent', selector: '#tiny-parent', rawText: '불법 온라인 카지노 가입 배팅 보너스', label: 'illegal_ad', relatedHref: '/destination', technique: 'OFFSCREEN' },
  { id: 'tiny-child', selector: '#tiny-child', rawText: '불법 온라인 카지노 가입 배팅 보너스', label: 'illegal_ad', relatedHref: '/destination', technique: 'OFFSCREEN' },
];

/** Error cases have no OCR/advertising label; failed decoding is never no_text. */
export const imageExceptionTruth = [
  { id: 'decode-failure', selector: '#decode-failure', imagePath: '/exceptions/decode.png', kind: 'decode_failure', httpStatus: 200, file: 'malformed.png', byteLength: 16, sha256: '45458224bd0b05b1d05831905f1134fa6c5e220ac4db1eb63846ff011f3850b7' },
  { id: 'missing-image', selector: '#missing-image', imagePath: '/exceptions/missing.png', kind: 'http_failure', httpStatus: 404, file: null, byteLength: null, sha256: null },
  { id: 'unavailable-image', selector: '#unavailable-image', imagePath: '/exceptions/unavailable.png', kind: 'http_failure', httpStatus: 503, file: null, byteLength: null, sha256: null },
] as const;
