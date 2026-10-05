/* eslint-disable @typescript-eslint/no-unused-vars */

const WATCH_STYLE_ELEMENT_ID = "infocutter-watch-style";
let watchRenderTimer: number | null = null;
let watchObserver: MutationObserver | null = null;
let watchScrollBound = false;
let watchRuntimeIdCounter = 0;
const watchRuntimeIds = new WeakMap<Element, string>();
const watchActiveChips = new Map<string, { element: Element; term: string; chip: HTMLElement }>();
const watchResolvedIds = new Set<string>();

function watchRuntimeId(element: Element): string {
  const existing = watchRuntimeIds.get(element);
  if (existing) {
    return existing;
  }

  watchRuntimeIdCounter += 1;
  const nextId = `iwm-${watchRuntimeIdCounter.toString(36)}`;
  watchRuntimeIds.set(element, nextId);
  return nextId;
}

type WatchRuntimeState = {
  globalEnabled: boolean;
  autoMask: boolean;
  terms: string[];
};

async function readWatchRuntimeState(): Promise<WatchRuntimeState> {
  const result = await chrome.storage.local.get(WATCH_STORAGE_KEY);
  const store = InfocutterWatch.normalizeWatchStore(result[WATCH_STORAGE_KEY]);
  return {
    autoMask: store.settings.autoMask,
    globalEnabled: store.settings.globalEnabled,
    terms: InfocutterWatch.watchTerms(store)
  };
}

function ensureWatchStyleElement(): void {
  if (document.getElementById(WATCH_STYLE_ELEMENT_ID)) {
    return;
  }

  const style = document.createElement("style");
  style.id = WATCH_STYLE_ELEMENT_ID;
  style.textContent = `[${WATCH_MASK_ATTR}] { filter: blur(8px) !important; }`;
  document.documentElement.append(style);
}

function collectWatchMatches(terms: string[]): Map<string, { element: Element; term: string }> {
  const found = new Map<string, { element: Element; term: string }>();
  if (terms.length === 0) {
    return found;
  }

  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
    acceptNode(node) {
      const parent = node.parentElement;
      if (!parent || isIgnoredTextHost(parent)) {
        return NodeFilter.FILTER_REJECT;
      }

      return InfocutterWatch.matchTerms(node.textContent ?? "", terms) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
    }
  });

  let current = walker.nextNode();
  while (current) {
    const parent = current.parentElement;
    const matched = parent ? InfocutterWatch.matchTerms(current.textContent ?? "", terms) : null;
    if (parent && matched) {
      const container = preferredBlockContainer(parent);
      const id = watchRuntimeId(container);
      if (!found.has(id)) {
        found.set(id, { element: container, term: matched });
      }
    }

    current = walker.nextNode();
  }

  return found;
}

function positionWatchChip(chip: HTMLElement, element: Element): void {
  const rect = element.getBoundingClientRect();
  chip.style.top = `${Math.max(rect.top + 4, 4)}px`;
  chip.style.left = `${Math.max(Math.min(rect.right - 168, window.innerWidth - 176), 4)}px`;
}

function repositionWatchChips(): void {
  for (const entry of watchActiveChips.values()) {
    positionWatchChip(entry.chip, entry.element);
  }
}

function dismissWatchMatch(id: string, element: Element): void {
  element.removeAttribute(WATCH_MASK_ATTR);
  const entry = watchActiveChips.get(id);
  if (entry) {
    entry.chip.remove();
  }

  watchActiveChips.delete(id);
  watchResolvedIds.add(id);
}

async function captureWatchEvidence(
  id: string,
  element: Element,
  term: string,
  chip: HTMLElement,
  saveButton: HTMLButtonElement
): Promise<void> {
  saveButton.disabled = true;
  saveButton.textContent = "저장 중…";
  element.removeAttribute(WATCH_MASK_ATTR);
  element.scrollIntoView({ block: "center" });
  await new Promise<void>((resolve) => {
    window.setTimeout(() => {
      resolve();
    }, 350);
  });

  const payload = {
    htmlExcerpt: (element instanceof HTMLElement ? element.outerHTML : "").slice(0, 200000),
    matchedTerm: term,
    matchedText: element.textContent.replace(/\s+/g, " ").trim().slice(0, 400),
    pageTitle: document.title,
    url: window.location.href
  };

  const raw: unknown = await chrome.runtime
    .sendMessage({ type: messageTypes.captureEvidence, payload })
    .catch(() => null);

  const ok = raw !== null && typeof raw === "object" && "ok" in raw && raw.ok === true;

  if (ok) {
    if (element instanceof HTMLElement) {
      element.style.setProperty("display", "none", "important");
    }

    chip.textContent = "저장됨";
    window.setTimeout(() => {
      chip.remove();
    }, 2000);
    watchActiveChips.delete(id);
    watchResolvedIds.add(id);
    repositionWatchChips();
    return;
  }

  element.setAttribute(WATCH_MASK_ATTR, "true");
  saveButton.disabled = false;
  saveButton.textContent = "재시도";
}

function createWatchChip(id: string, element: Element, term: string): HTMLElement {
  const chip = document.createElement("div");
  chip.id = `${WATCH_CHIP_ID}-${id}`;
  chip.style.cssText = [
    "position: fixed",
    "z-index: 2147483646",
    "display: flex",
    "gap: 6px",
    "align-items: center",
    "padding: 4px 8px",
    "background: #8f2d1d",
    "color: #f7f4eb",
    "font: 12px/1.4 sans-serif",
    "border-radius: 6px",
    "box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3)"
  ].join(";");

  const label = document.createElement("span");
  label.textContent = "🚩 감시 대상";

  const saveButton = document.createElement("button");
  saveButton.type = "button";
  saveButton.textContent = "증거 저장";
  saveButton.style.cssText = "cursor:pointer;border:0;border-radius:4px;padding:2px 6px;background:#f7f4eb;color:#8f2d1d;font:inherit;";
  saveButton.addEventListener("click", () => {
    void captureWatchEvidence(id, element, term, chip, saveButton);
  });

  const dismissButton = document.createElement("button");
  dismissButton.type = "button";
  dismissButton.textContent = "무시";
  dismissButton.style.cssText = "cursor:pointer;border:0;border-radius:4px;padding:2px 6px;background:transparent;color:#f7f4eb;font:inherit;";
  dismissButton.addEventListener("click", () => {
    dismissWatchMatch(id, element);
  });

  chip.append(label, saveButton, dismissButton);
  document.documentElement.append(chip);
  positionWatchChip(chip, element);
  return chip;
}

async function renderWatchMasks(): Promise<void> {
  const state = await readWatchRuntimeState();
  if (!state.globalEnabled || state.terms.length === 0) {
    return;
  }

  ensureWatchStyleElement();
  const matches = collectWatchMatches(state.terms);
  for (const [id, match] of matches) {
    if (watchResolvedIds.has(id) || watchActiveChips.has(id)) {
      continue;
    }

    if (state.autoMask) {
      match.element.setAttribute(WATCH_MASK_ATTR, "true");
    }

    const chip = createWatchChip(id, match.element, match.term);
    watchActiveChips.set(id, { chip, element: match.element, term: match.term });
  }

  repositionWatchChips();
}

function scheduleWatchRender(): void {
  if (watchRenderTimer !== null) {
    window.clearTimeout(watchRenderTimer);
  }

  watchRenderTimer = window.setTimeout(() => {
    watchRenderTimer = null;
    void renderWatchMasks();
  }, 150);
}

function ensureWatchObserver(): void {
  if (!watchScrollBound) {
    window.addEventListener("scroll", repositionWatchChips, { passive: true });
    window.addEventListener("resize", repositionWatchChips, { passive: true });
    watchScrollBound = true;
  }

  if (watchObserver) {
    return;
  }

  watchObserver = new MutationObserver(() => {
    scheduleWatchRender();
  });
  watchObserver.observe(document.documentElement, {
    characterData: true,
    childList: true,
    subtree: true
  });
}

function bootWatchRuntime(): void {
  if (window.top !== window) {
    return;
  }

  ensureWatchObserver();
  void renderWatchMasks();
}
