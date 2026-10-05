import type { CollectedElement, CollectedFrame } from '../core/types.js';

import type { CollectedImageOccurrence } from '../core/v2.js';

export type DocumentImage = Omit<CollectedImageOccurrence, 'imageId' | 'url' | 'frameUrl' | 'framePath' | 'snapshotId'>;
export interface DocumentCaptureOptions { framePath: string[]; maxElements: number; maxHtmlBytes: number; maxCaptureBytes?: number; captureImages?: boolean }
export type DocumentCapture = Omit<CollectedFrame, 'framePath' | 'snapshotId' | 'capturedAt' | 'frameUrl'> & {
  discoveredUrls: string[]; excludedLoginRegions: string[]; images: DocumentImage[];
};

/** Runs inside a frame. No live DOM writes, visibility filters, normalization or truncation. */
export function captureDocument(options: DocumentCaptureOptions): DocumentCapture {
  const root = document;
  const loginRegions = [...new Set([...root.querySelectorAll('input[type="password"]')].map(input =>
    input.closest('form,[role="form"],dialog') ?? input.parentElement ?? input))];
  // Object methods stay self-contained when tsx/esbuild keepNames serializes this function.
  const helpers = {
  uniqueSelector(element: Element): string {
    if (!element.isConnected || element.ownerDocument !== root) throw new Error('DOM detached');
    if (element.id) {
      const id = '#' + CSS.escape(element.id);
      if (root.querySelectorAll(id).length === 1) return id;
    }
    const parts: string[] = [];
    let current: Element | null = element;
    while (current) {
      const tag = CSS.escape(current.localName);
      const siblings = current.parentElement ? [...current.parentElement.children].filter(e => e.localName === current!.localName) : [current];
      parts.unshift(siblings.length > 1 ? `${tag}:nth-of-type(${siblings.indexOf(current) + 1})` : tag);
      const selector = parts.join(' > ');
      if (root.querySelectorAll(selector).length === 1 && root.querySelector(selector) === element) return selector;
      current = current.parentElement;
    }
    throw new Error('Element location is not unique');
  },
  rect(element: Element) {
    const b = element.getBoundingClientRect();
    return { x: b.x, y: b.y, width: b.width, height: b.height };
  },
  location(element: Element) { return [...options.framePath, helpers.uniqueSelector(element)].join(' >>> '); },
  safeUrl(value: string): string | null {
    try { const u = new URL(value, root.baseURI); return ['http:', 'https:'].includes(u.protocol) && !u.username && !u.password ? u.href : null; }
    catch { return null; }
  },
  publicText(element: Element): string {
    const copy = element.cloneNode(true) as Element;
    for (const excluded of copy.querySelectorAll('script,style,noscript')) excluded.remove();
    for (const input of copy.querySelectorAll('input[type="password"]')) {
      const region = input.closest('form,[role="form"],dialog') ?? input.parentElement ?? input;
      if (region === copy) return '';
      region.remove();
    }
    return copy.textContent ?? '';
  },
  imageClipped(style: DocumentImage['styles'][number]): boolean {
    // Legacy rect clipping applies to absolutely positioned boxes; clip-path applies independently.
    return (['absolute', 'fixed'].includes(style.css.position ?? '') &&
      /rect\(\s*0(?:px)?[\s,]+0(?:px)?[\s,]+0(?:px)?[\s,]+0(?:px)?\s*\)/u.test(style.css.clip ?? '')) ||
      /inset\(\s*50%\s*\)/u.test(style.css['clip-path'] ?? '');
  },
  fixedContainingBlock(style: DocumentImage['styles'][number]): boolean {
    return ['transform', 'filter', 'backdrop-filter', 'perspective'].some(property => {
      const value = style.css[property];
      return value && value !== 'none';
    }) || (style.css.contain ?? '').split(/\s+/u).some(value => ['layout', 'paint', 'strict', 'content'].includes(value)) ||
      (style.css['will-change'] ?? '').split(',').some(value => ['transform', 'filter', 'perspective'].includes(value.trim())) ||
      style.css['content-visibility'] === 'auto';
  },
  fixedPseudoOutside(style: DocumentImage['styles'][number]): boolean {
    // Pseudos have no DOM rectangle. Resolve offsets only when transforms and box adjustments are absent.
    if (style.css.transform !== 'none' || ['margin', 'padding', 'border-width'].some(property =>
      !/^0px(?:\s+0px){0,3}$/u.test(style.css[property] ?? ''))) return false;
    const width = Number.parseFloat(style.css.width ?? ''), height = Number.parseFloat(style.css.height ?? '');
    const left = Number.parseFloat(style.css.left ?? ''), top = Number.parseFloat(style.css.top ?? '');
    const right = Number.parseFloat(style.css.right ?? ''), bottom = Number.parseFloat(style.css.bottom ?? '');
    const x = Number.isFinite(left) ? left : innerWidth - right - width;
    const y = Number.isFinite(top) ? top : innerHeight - bottom - height;
    return x >= innerWidth || y >= innerHeight || x + width <= 0 || y + height <= 0;
  },
  };
  const html = [...root.childNodes].map(node => node instanceof Element ? node.outerHTML : new XMLSerializer().serializeToString(node)).join('');
  const encoder = new TextEncoder();
  let capturedBytes = encoder.encode(html).byteLength;
  if (capturedBytes > options.maxHtmlBytes) throw new Error('RESOURCE_LIMIT: frame HTML byte limit');
  const elements: CollectedElement[] = [];
  const propertyNames = ['font-size', 'display', 'visibility', 'opacity', 'color', 'background-color', 'background-image',
    'position', 'left', 'top', 'right', 'bottom', 'transform', 'transform-origin', 'clip', 'clip-path',
    'overflow', 'overflow-x', 'overflow-y', 'width', 'height', 'text-indent', 'content-visibility'];
  for (const element of root.querySelectorAll('*')) {
    if (element.closest('script,style,noscript,head') || loginRegions.some(region => region.contains(element))) continue;
    const rawText = [...element.childNodes].filter(n => n.nodeType === Node.TEXT_NODE).map(n => n.nodeValue ?? '').join('');
    if (!rawText.trim()) continue;
    if (elements.length >= options.maxElements) throw new Error('RESOURCE_LIMIT: frame text owner limit');
    const ownerLocation = helpers.location(element);
    const styles: CollectedElement['styles'] = [];
    let ancestor: Element | null = element;
    while (ancestor) {
      const style = getComputedStyle(ancestor);
      styles.push({ elementLocation: helpers.location(ancestor), bounds: helpers.rect(ancestor),
        css: Object.fromEntries(propertyNames.map(name => [name, style.getPropertyValue(name)])) });
      ancestor = ancestor.parentElement;
    }
    const links = new Set<string>();
    const anchor = element.closest('a[href]');
    const value = anchor?.getAttribute('href');
    const url = value === null || value === undefined ? null : helpers.safeUrl(value);
    if (url) links.add(url);
    const bounds = helpers.rect(element);
    const captured: CollectedElement = { location: ownerLocation, rawText, links: [...links], styles, tagName: element.localName,
      attributes: Object.fromEntries([...element.attributes].map(a => [a.name, a.value])), contextText: rawText,
      accessibility: { role: element.getAttribute('role') ?? element.closest('[role]')?.getAttribute('role') ?? null,
        ariaHidden: element.getAttribute('aria-hidden') ?? element.closest('[aria-hidden]')?.getAttribute('aria-hidden') ?? null,
        ariaLabel: element.getAttribute('aria-label') ?? element.closest('[aria-label]')?.getAttribute('aria-label') ?? null },
      bounds, documentBounds: { ...bounds, x: bounds.x + scrollX, y: bounds.y + scrollY } };
    capturedBytes += encoder.encode(JSON.stringify(captured)).byteLength;
    if (capturedBytes > (options.maxCaptureBytes ?? 50 * 1024 * 1024)) throw new Error('RESOURCE_LIMIT: frame capture byte limit');
    elements.push(captured);
  }
  const images: DocumentImage[] = [];
  const imagePropertyNames = [...propertyNames, 'filter', 'backdrop-filter', 'perspective', 'contain', 'will-change'];
  if (options.captureImages) for (const element of root.querySelectorAll('*')) {
    if (element.closest('script,style,noscript,head') || loginRegions.some(region => region.contains(element))) continue;
    const sources: { sourceKind: DocumentImage['sourceKind']; selectedUrl: string; sourceIndex: number; pseudo: string | null }[] = [];
    if (element instanceof HTMLImageElement && element.currentSrc) sources.push({ sourceKind: 'img', selectedUrl: element.currentSrc, sourceIndex: 0, pseudo: null });
    for (const [kind, pseudo] of [['css_background', null], ['css_before', '::before'], ['css_after', '::after']] as const) {
      const css = getComputedStyle(element, pseudo).backgroundImage;
      // Computed URLs can contain commas, parentheses, escapes and data payloads.
      const expression = /url\(\s*(?:"((?:\\.|[^"\\])*)"|'((?:\\.|[^'\\])*)'|((?:\\.|[^)\\])*))\s*\)/gi;
      let sourceIndex = 0;
      for (const match of css.matchAll(expression)) {
        const selectedUrl = (match[1] ?? match[2] ?? match[3] ?? '').trim().replace(/\\([\da-f]{1,6}\s?|[\s\S])/gi, (_all, escaped: string) => /^[\da-f]/i.test(escaped) ? String.fromCodePoint(parseInt(escaped.trim(), 16) || 0xfffd) : escaped);
        let resolved = selectedUrl;
        try { resolved = new URL(selectedUrl, root.baseURI).href; } catch { /* Preserve invalid selected assets as per-image acquisition failures. */ }
        sources.push({ sourceKind: kind, selectedUrl: resolved, sourceIndex: sourceIndex++, pseudo });
      }
    }
    for (const source of sources) {
      if (images.length >= options.maxElements) throw new Error('RESOURCE_LIMIT: frame image occurrence limit');
      const styles: DocumentImage['styles'] = [];
      // Pseudo style selectors identify getComputedStyle(owner, pseudo); bounds remain the owner rectangle.
      if (source.pseudo) {
        const computed = getComputedStyle(element, source.pseudo);
        styles.push({ elementLocation: helpers.location(element) + source.pseudo, bounds: helpers.rect(element), css: Object.fromEntries([...imagePropertyNames, 'margin', 'padding', 'border-width'].map(name => [name, computed.getPropertyValue(name)])) });
      }
      let ancestor: Element | null = element;
      while (ancestor) {
        const computed = getComputedStyle(ancestor);
        styles.push({ elementLocation: helpers.location(ancestor), bounds: helpers.rect(ancestor), css: Object.fromEntries(imagePropertyNames.map(name => [name, computed.getPropertyValue(name)])) });
        ancestor = ancestor.parentElement;
      }
      const bounds = helpers.rect(element);
      const concealment: DocumentImage['concealment'] = [];
      if (styles.some(style => Number(style.css.opacity) === 0)) concealment.push('TRANSPARENT');
      // Ancestor CSS can establish a containing block for fixed descendants; ordinary scrollable
      // content uses document coordinates so scrolling above/left of an image does not conceal it.
      const viewportFixed = styles.map((style, index) => style.css.position === 'fixed' &&
        !styles.slice(index + 1).some(ancestorStyle => helpers.fixedContainingBlock(ancestorStyle)));
      const fixedOwner = viewportFixed.some((fixed, index) => fixed && !(source.pseudo && index === 0));
      const x = bounds.x + (fixedOwner ? 0 : scrollX), y = bounds.y + (fixedOwner ? 0 : scrollY);
      const fixedOutside = viewportFixed.some((fixed, index) => fixed &&
        (source.pseudo && index === 0 ? helpers.fixedPseudoOutside(styles[index]!) :
          bounds.x >= innerWidth || bounds.y >= innerHeight || bounds.x + bounds.width <= 0 || bounds.y + bounds.height <= 0));
      if (styles.some(style => style.css.display === 'none' || ['hidden', 'collapse'].includes(style.css.visibility ?? '') ||
        style.css['content-visibility'] === 'hidden' || helpers.imageClipped(style)) || bounds.width <= 1 || bounds.height <= 1 ||
        x + bounds.width < 0 || y + bounds.height < 0 || fixedOutside) concealment.push('OFFSCREEN');
      const href = element.closest('a[href]')?.getAttribute('href');
      const link = href ? helpers.safeUrl(href) : null;
      const image: DocumentImage = { location: helpers.location(element), selectedUrl: source.selectedUrl, imageUrl: helpers.safeUrl(source.selectedUrl), sourceKind: source.sourceKind, sourceIndex: source.sourceIndex,
        links: link ? [link] : [], styles, bounds, documentBounds: { ...bounds, x: bounds.x + scrollX, y: bounds.y + scrollY }, concealment };
      capturedBytes += encoder.encode(JSON.stringify(image)).byteLength;
      if (capturedBytes > (options.maxCaptureBytes ?? 50 * 1024 * 1024)) throw new Error('RESOURCE_LIMIT: frame capture byte limit');
      images.push(image);
    }
  }
  const discoveredUrls = [...new Set([...root.querySelectorAll('a[href],area[href]')].flatMap(a => {
    if (loginRegions.some(region => region.contains(a))) return [];
    const url = helpers.safeUrl(a.getAttribute('href') ?? ''); return url ? [url] : [];
  }))];
  return { html, elements, images, excludedLoginRegions: loginRegions.map(region => helpers.location(region)),
    viewport: { width: innerWidth, height: innerHeight, scrollX, scrollY },
    documentSize: { width: Math.max(root.documentElement.scrollWidth, root.body?.scrollWidth ?? 0),
      height: Math.max(root.documentElement.scrollHeight, root.body?.scrollHeight ?? 0) }, discoveredUrls };
}

/** Absolute src is a logical selector: compare resolved attributes without rewriting the DOM. */
export function frameSelector(element: Element): string {
  const root = element.ownerDocument;
  if (!element.isConnected) throw new Error('Frame DOM detached');
  const tag = element.localName;
  const src = element.getAttribute('src');
  if (src && !element.hasAttribute('srcdoc')) {
    const absolute = new URL(src, root.baseURI).href;
    const matches = [...root.querySelectorAll(tag + '[src]')].filter(candidate => {
      try { return !candidate.hasAttribute('srcdoc') && new URL(candidate.getAttribute('src')!, root.baseURI).href === absolute; }
      catch { return false; }
    });
    if (matches.length === 1 && matches[0] === element) {
      return `${tag}[src="${absolute.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\a ')}"]`;
    }
  }
  if (element.id) {
    const selector = `${tag}#${CSS.escape(element.id)}`;
    if (root.querySelectorAll(selector).length === 1) return selector;
  }
  const parts: string[] = [];
  let current: Element | null = element;
  while (current) {
    const siblings = current.parentElement ? [...current.parentElement.children].filter(e => e.localName === current!.localName) : [current];
    parts.unshift(`${CSS.escape(current.localName)}:nth-of-type(${siblings.indexOf(current) + 1})`);
    const selector = parts.join(' > ');
    if (root.querySelectorAll(selector).length === 1 && root.querySelector(selector) === element) return selector;
    current = current.parentElement;
  }
  throw new Error('Frame location is not unique');
}
