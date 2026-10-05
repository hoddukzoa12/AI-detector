import {
  buildForcedUniqueSelector as forcedUniqueSelector,
  isBareTagSelector,
  isUniqueSelector,
  nthOfTypeSelector,
  selectorCss,
  simpleSelectorCandidates
} from "../../packages/infocutter-selector-rules/src/index.js";

export { selectorCss };

const MAX_SELECTOR_DEPTH = 4;

function selectorSpecificityScore(selector: string): number {
  let score = 0;
  if (selector.includes("#")) {
    score += 6;
  }
  if (selector.includes("[")) {
    score += 4;
  }
  if (selector.includes(".")) {
    score += 3;
  }
  if (selector.includes(":nth-of-type")) {
    score -= 2;
  }
  if (selector.includes(">")) {
    score += 2;
  }
  if (isBareTagSelector(selector)) {
    score -= 6;
  }
  return score;
}

function buildForcedUniqueSelector(element: Element, root: Document = document): string {
  return forcedUniqueSelector(element, selectorSpecificityScore, root);
}

function buildGroupSelectorCandidates(element: Element, root: Document = document): string[] {
  return simpleSelectorCandidates(element, { allowNth: false })
    .filter((candidate) => !isBareTagSelector(candidate))
    .sort((left, right) => selectorSpecificityScore(right) - selectorSpecificityScore(left))
    .filter((candidate) => {
      try {
        const matches = root.querySelectorAll(candidate).length;
        return matches > 1 && matches <= 12;
      } catch {
        return false;
      }
    });
}

function uniqueDirectCandidates(element: Element, root: Document = document): string[] {
  return simpleSelectorCandidates(element, { allowNth: true }).filter((selector) => isUniqueSelector(selector, root));
}

function pathSelector(ancestor: Element, target: Element): string {
  const segments: string[] = [];
  let current: Element | null = target;

  while (current && current !== ancestor) {
    const candidates = simpleSelectorCandidates(current, { allowNth: true });
    segments.unshift(candidates[0] ?? current.localName);
    current = current.parentElement;
  }

  const anchorCandidates = uniqueDirectCandidates(ancestor);
  const anchor = anchorCandidates[0] ?? ancestor.localName;

  return [anchor, ...segments].join(" > ");
}

export function buildSelectorCandidates(element: Element, root: Document = document): string[] {
  const results: string[] = [];
  const seen = new Set<string>();

  const pushIfUseful = (selector: string): void => {
    if (!selector || seen.has(selector)) {
      return;
    }

    seen.add(selector);
    results.push(selector);
  };

  pushIfUseful(buildForcedUniqueSelector(element, root));

  const directCandidates = uniqueDirectCandidates(element, root).sort(
    (left, right) => selectorSpecificityScore(right) - selectorSpecificityScore(left)
  );

  for (const selector of directCandidates) {
    pushIfUseful(selector);
  }

  let ancestor = element.parentElement;
  let depth = 0;

  while (ancestor && depth < MAX_SELECTOR_DEPTH) {
    const anchored = pathSelector(ancestor, element);
    pushIfUseful(anchored);
    if (isUniqueSelector(anchored, root)) {
      break;
    }

    ancestor = ancestor.parentElement;
    depth += 1;
  }

  for (const groupSelector of buildGroupSelectorCandidates(element, root)) {
    pushIfUseful(groupSelector);
  }

  if (results.length === 0) {
    pushIfUseful(nthOfTypeSelector(element));
  }

  return results;
}

export function buildSelector(element: Element): string {
  return buildSelectorCandidates(element)[0] ?? element.localName;
}
