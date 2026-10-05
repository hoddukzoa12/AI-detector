import type { CollectedElement, CollectedFrame, ElementStyle, Technique } from '../core/types.js';

interface Color { r: number; g: number; b: number; a: number }
interface StyleAnalysis { techniques: Technique[]; observationIds: string[]; ambiguous: boolean }

function css(style: ElementStyle | undefined, property: string): string {
  return (style?.css[property] ?? style?.css[property.replace(/-([a-z])/gu, (_, letter: string) => letter.toUpperCase())] ?? '').trim().toLowerCase();
}
function numeric(value: string): number | null {
  const result = Number.parseFloat(value);
  return Number.isFinite(result) ? result : null;
}
function color(value: string): Color | null {
  if (value === 'transparent') return { r: 0, g: 0, b: 0, a: 0 };
  const named: Record<string, string> = { white: '#ffffff', black: '#000000', red: '#ff0000' };
  value = named[value] ?? value;
  const hex = /^#([\da-f]{3,4}|[\da-f]{6}|[\da-f]{8})$/iu.exec(value)?.[1];
  if (hex) {
    const expanded = hex.length <= 4 ? [...hex].map(character => character.repeat(2)).join('') : hex;
    return { r: parseInt(expanded.slice(0, 2), 16), g: parseInt(expanded.slice(2, 4), 16), b: parseInt(expanded.slice(4, 6), 16), a: expanded.length === 8 ? parseInt(expanded.slice(6, 8), 16) / 255 : 1 };
  }
  const rgb = /^rgba?\((.*)\)$/u.exec(value)?.[1];
  if (!rgb) return null;
  const parts = rgb.trim().split(/\s*[,/]\s*|\s+/u);
  if (parts.length < 3 || parts.length > 4) return null;
  const channels = parts.slice(0, 3).map(part => Number.parseFloat(part) * (part.endsWith('%') ? 2.55 : 1));
  const alpha = parts[3] === undefined ? 1 : Number.parseFloat(parts[3]) / (parts[3].endsWith('%') ? 100 : 1);
  if (![...channels, alpha].every(Number.isFinite)) return null;
  return { r: channels[0], g: channels[1], b: channels[2], a: alpha };
}
function overlay(front: Color, back: Color): Color {
  const a = front.a + back.a * (1 - front.a);
  return { r: (front.r * front.a + back.r * back.a * (1 - front.a)) / a,
    g: (front.g * front.a + back.g * back.a * (1 - front.a)) / a,
    b: (front.b * front.a + back.b * back.a * (1 - front.a)) / a, a };
}

export function analyzeStyles(element: CollectedElement, frame: CollectedFrame): StyleAnalysis {
  const observationIds: string[] = [];
  const techniques: Technique[] = [];
  let ambiguous = false;
  const styles = element.styles;
  // Computed foreground belongs to the text owner; ancestor foreground is never its background.
  const foreground = color(css(styles[0], 'color'));
  if (foreground?.a === 0) observationIds.push('TRANSPARENT_FOREGROUND_ALPHA_ZERO');
  if (styles.some(style => numeric(css(style, 'opacity')) === 0)) observationIds.push('TRANSPARENT_OWNER_OR_ANCESTOR_OPACITY_ZERO');
  let background: Color = { r: 255, g: 255, b: 255, a: 1 }; // browser canvas default
  let backgroundKnown = true;
  for (const style of [...styles].reverse()) {
    const value = css(style, 'background-color');
    if (!value) continue;
    const parsed = color(value);
    if (parsed) { background = overlay(parsed, background); if (parsed.a === 1) backgroundKnown = true; }
    else backgroundKnown = false;
    if (css(style, 'background-image') && css(style, 'background-image') !== 'none') backgroundKnown = false;
  }
  if (foreground && foreground.a > 0 && backgroundKnown && !styles.some(style => css(style, 'background-image') && css(style, 'background-image') !== 'none')) {
    const rendered = overlay(foreground, background);
    if ((['r', 'g', 'b'] as const).every(channel => Math.abs(rendered[channel] - background[channel]) < 1e-6)) observationIds.push('TRANSPARENT_FOREGROUND_EQUALS_EFFECTIVE_BACKGROUND');
  }
  if (observationIds.length) techniques.push('TRANSPARENT');

  const offscreenRules: string[] = [];
  if (styles.some(style => css(style, 'display') === 'none')) offscreenRules.push('OFFSCREEN_OWNER_OR_ANCESTOR_DISPLAY_NONE');
  const fontSize = numeric(css(styles[0], 'font-size'));
  if (fontSize !== null && fontSize >= 0 && fontSize <= 1) offscreenRules.push('OFFSCREEN_FONT_ZERO_OR_ONE_PIXEL');
  // Bounds are in document coordinates for scrollable content, viewport coordinates for fixed elements.
  for (const style of styles) {
    const position = css(style, 'position');
    if (!['absolute', 'fixed'].includes(position)) continue;
    const fixed = position === 'fixed';
    const owner = style.elementLocation === element.location;
    const bounds = fixed ? style.bounds : owner ? element.documentBounds : { ...style.bounds, x: style.bounds.x + frame.viewport.scrollX, y: style.bounds.y + frame.viewport.scrollY };
    const width = fixed ? frame.viewport.width : frame.documentSize.width;
    const height = fixed ? frame.viewport.height : frame.documentSize.height;
    const left = numeric(css(style, 'left'));
    const top = numeric(css(style, 'top'));
    if ((left !== null && left <= -frame.viewport.width) || (top !== null && top <= -frame.viewport.height) ||
      bounds.x + bounds.width < -1 || bounds.y + bounds.height < -1 || bounds.x > width + 1 || bounds.y > height + 1) {
      offscreenRules.push('OFFSCREEN_POSITION_OUTSIDE_DOCUMENT'); break;
    }
  }
  if (styles.some(style => ['hidden', 'collapse'].includes(css(style, 'visibility')))) {
    offscreenRules.push('OFFSCREEN_VISIBILITY_HIDDEN'); ambiguous = true;
  }
  if (styles.some(style => /rect\(\s*0(?:px)?[\s,]+0(?:px)?[\s,]+0(?:px)?[\s,]+0(?:px)?\s*\)/u.test(css(style, 'clip')) || /inset\(\s*50%\s*\)/u.test(css(style, 'clip-path')))) {
    offscreenRules.push('OFFSCREEN_CLIPPED'); ambiguous = true;
  }
  if (offscreenRules.length) techniques.push('OFFSCREEN');
  return { techniques, observationIds: [...observationIds, ...offscreenRules], ambiguous };
}
