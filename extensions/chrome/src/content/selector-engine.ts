/* eslint-disable @typescript-eslint/no-unused-vars */

function maybeStableClassName(className: string): boolean {
  return InfocutterSelectorRules.maybeStableClassName(className);
}

function stableClasses(element: Element): string[] {
  return InfocutterSelectorRules.stableClasses(element);
}

function nthOfTypeSelector(element: Element): string {
  return InfocutterSelectorRules.nthOfTypeSelector(element);
}

function isUniqueSelector(selector: string, root: Document = document): boolean {
  return InfocutterSelectorRules.isUniqueSelector(selector, root);
}

function simpleCandidates(element: Element, options?: { allowNth?: boolean }): string[] {
  return InfocutterSelectorRules.simpleSelectorCandidates(element, options);
}

function isUniqueAmongSiblings(element: Element, segment: string): boolean {
  return InfocutterSelectorRules.isUniqueAmongSiblings(element, segment);
}

function isBareTagSelector(selector: string): boolean {
  return InfocutterSelectorRules.isBareTagSelector(selector);
}

function selectorSpecificityScore(selector: string): number {
  const idCount = (selector.match(/#/g) ?? []).length;
  const classCount = (selector.match(/[.[\]:]/g) ?? []).length;
  const segmentCount = selector.split(">").length;
  const nthCount = (selector.match(/:nth-of-type/g) ?? []).length;
  return (idCount * 1000) + (classCount * 100) + (segmentCount * 10) + nthCount;
}

function preferredExactSegmentSelector(element: Element): string {
  return InfocutterSelectorRules.preferredExactSegmentSelector(element, selectorSpecificityScore);
}

function buildForcedUniqueSelector(element: Element): string {
  return InfocutterSelectorRules.buildForcedUniqueSelector(element, selectorSpecificityScore);
}

function selectorAssessment(selector: string): SelectorAssessmentResult {
  let matches: number | null = null;
  try {
    matches = document.querySelectorAll(selector).length;
  } catch {
    return {
      applyAllowed: false,
      label: "잘못된 선택자",
      matches: null,
      tone: "#fecaca"
    };
  }

  if (matches === 1) {
    return {
      applyAllowed: true,
      label: "정확히 1개 대상",
      matches,
      tone: "#bbf7d0"
    };
  }

  if (matches > 1) {
    return {
      applyAllowed: true,
      label: "같은 구조 여러 대상",
      matches,
      tone: "#bfdbfe"
    };
  }

  return {
    applyAllowed: false,
    label: "대상 없음",
    matches,
    tone: "#fde68a"
  };
}

function buildGroupSelectorCandidates(element: Element): string[] {
  return simpleCandidates(element, { allowNth: false })
    .filter((candidate) => !isBareTagSelector(candidate))
    .sort((left, right) => selectorSpecificityScore(right) - selectorSpecificityScore(left))
    .filter((candidate) => {
      const assessment = selectorAssessment(candidate);
      return assessment.applyAllowed && (assessment.matches ?? 0) > 1;
    });
}

function preferredSegmentSelector(element: Element): string {
  const candidates = simpleCandidates(element, { allowNth: true }).sort(
    (left, right) => selectorSpecificityScore(right) - selectorSpecificityScore(left)
  );

  for (const candidate of candidates) {
    if (isUniqueAmongSiblings(element, candidate)) {
      return candidate;
    }
  }

  return candidates[0] ?? element.localName;
}

function pathSelector(ancestor: Element, target: Element): string {
  const segments: string[] = [];
  let current: Element | null = target;

  while (current && current !== ancestor) {
    segments.unshift(preferredSegmentSelector(current));
    current = current.parentElement;
  }

  const anchor = simpleCandidates(ancestor, { allowNth: true })
    .filter((candidate) => !isBareTagSelector(candidate))
    .find((candidate) => isUniqueSelector(candidate))
    ?? nthOfTypeSelector(ancestor);

  return [anchor, ...segments].join(" > ");
}

function buildSelectorCandidates(element: Element): string[] {
  const seen = new Set<string>();
  const selectors: string[] = [];

  const pushIfUseful = (selector: string): void => {
    if (!selector || seen.has(selector)) {
      return;
    }

    seen.add(selector);
    selectors.push(selector);
  };

  pushIfUseful(buildForcedUniqueSelector(element));

  const directCandidates = simpleCandidates(element, { allowNth: true }).sort(
    (left, right) => selectorSpecificityScore(right) - selectorSpecificityScore(left)
  );

  for (const selector of directCandidates) {
    if (isUniqueSelector(selector)) {
      pushIfUseful(selector);
    }
  }

  let ancestor = element.parentElement;
  let depth = 0;

  while (ancestor && depth < 4) {
    const selector = pathSelector(ancestor, element);
    pushIfUseful(selector);
    if (isUniqueSelector(selector)) {
      break;
    }

    ancestor = ancestor.parentElement;
    depth += 1;
  }

  for (const groupSelector of buildGroupSelectorCandidates(element)) {
    pushIfUseful(groupSelector);
  }

  if (selectors.length === 0) {
    pushIfUseful(pathSelector(element.parentElement ?? element, element));
    pushIfUseful(nthOfTypeSelector(element));
  }

  return selectors;
}

function buildSelector(element: Element): string {
  return buildSelectorCandidates(element)[0] ?? element.localName;
}

let selectorRenderTimer: number | null = null;
let selectorObserver: MutationObserver | null = null;

function querySelectorElements(selector: string): Element[] {
  try {
    return Array.from(document.querySelectorAll(selector)).filter((element): element is Element => element instanceof Element);
  } catch {
    return [];
  }
}

function clearSelectorHiddenMarkers(): void {
  document.querySelectorAll(`[${SELECTOR_HIDDEN_ATTR}]`).forEach((element) => {
    element.removeAttribute(SELECTOR_HIDDEN_ATTR);
  });
}

function hasMatchingExceptionTarget(target: Element, exceptionTargets: Set<Element>): boolean {
  if (exceptionTargets.has(target)) {
    return true;
  }

  for (const exceptionTarget of exceptionTargets) {
    if (target.contains(exceptionTarget)) {
      return true;
    }
  }

  return false;
}

function ensureStyleElement(): HTMLStyleElement {
  const existing = document.getElementById(STYLE_ELEMENT_ID);
  if (existing instanceof HTMLStyleElement) {
    return existing;
  }

  const style = document.createElement("style");
  style.id = STYLE_ELEMENT_ID;
  document.documentElement.append(style);
  return style;
}

async function renderRules(): Promise<void> {
  const activeSiteState = await readActiveSiteState(ownerPageUrl());
  const style = ensureStyleElement();
  const frameScope = currentFrameScope();
  clearSelectorHiddenMarkers();

  if (!activeSiteState.globalEnabled || !activeSiteState.profileEnabled) {
    style.textContent = "";
    return;
  }

  const enabledRules = activeSiteState.cards
    .filter((card) => card.enabled)
    .flatMap((card) => card.rules)
    .filter((rule) => rule.frameScope === frameScope);
  const hideRules = enabledRules.filter((rule) => rule.mode === "hide");
  const exceptionRules = enabledRules.filter((rule) => rule.mode === "unhide");

  if (hideRules.length === 0) {
    style.textContent = "";
    return;
  }

  style.textContent = hiddenAttrCss(SELECTOR_HIDDEN_ATTR);

  const exceptionTargets = new Set<Element>(
    exceptionRules.flatMap((rule) => querySelectorElements(rule.selector))
  );

  for (const rule of hideRules) {
    for (const target of querySelectorElements(rule.selector)) {
      if (hasMatchingExceptionTarget(target, exceptionTargets)) {
        continue;
      }

      target.setAttribute(SELECTOR_HIDDEN_ATTR, "true");
    }
  }
}

function matchCountForSelector(selector: string): number | null {
  try {
    return document.querySelectorAll(selector).length;
  } catch {
    return null;
  }
}

function selectorRects(selector: string): DOMRect[] {
  try {
    return querySelectorElements(selector)
      .map((element) => element.getBoundingClientRect())
      .filter((rect) => rect.width > 0 || rect.height > 0);
  } catch {
    return [];
  }
}

function scheduleSelectorRender(): void {
  if (selectorRenderTimer !== null) {
    window.clearTimeout(selectorRenderTimer);
  }

  selectorRenderTimer = window.setTimeout(() => {
    selectorRenderTimer = null;
    void renderRules();
  }, 120);
}

function ensureSelectorObserver(): void {
  if (selectorObserver) {
    return;
  }

  selectorObserver = new MutationObserver(() => {
    scheduleSelectorRender();
  });
  selectorObserver.observe(document.documentElement, {
    childList: true,
    subtree: true
  });
}
