const ACTIVE_TAB_STORAGE_KEY = "infocutter:options-active-tab";

export function resolveActiveTab(
  stored: string | null | undefined,
  validKeys: readonly string[]
): string {
  if (stored && validKeys.includes(stored)) {
    return stored;
  }
  return validKeys[0] ?? "";
}

function readStoredTab(): Promise<string | null> {
  return new Promise((resolve) => {
    try {
      chrome.storage.local.get(ACTIVE_TAB_STORAGE_KEY, (items) => {
        const raw: unknown = Reflect.get(items, ACTIVE_TAB_STORAGE_KEY);
        resolve(typeof raw === "string" ? raw : null);
      });
    } catch {
      resolve(null);
    }
  });
}

function writeStoredTab(key: string): void {
  try {
    void chrome.storage.local.set({ [ACTIVE_TAB_STORAGE_KEY]: key });
  } catch {
    /* storage unavailable; ignore */
  }
}

function applyActiveTab(
  key: string,
  tabs: HTMLElement[],
  panels: HTMLElement[]
): void {
  for (const tab of tabs) {
    const isActive = tab.dataset.tab === key;
    tab.setAttribute("aria-selected", isActive ? "true" : "false");
    tab.tabIndex = isActive ? 0 : -1;
  }
  for (const panel of panels) {
    panel.hidden = panel.dataset.panel !== key;
  }
}

async function initTabs(): Promise<void> {
  const tablist = document.querySelector<HTMLElement>('[role="tablist"]');
  const tabs = Array.from(
    document.querySelectorAll<HTMLElement>('[role="tab"]')
  );
  const panels = Array.from(
    document.querySelectorAll<HTMLElement>('[role="tabpanel"]')
  );
  if (!tablist || tabs.length === 0 || panels.length === 0) {
    console.warn("[infocutter] options tabs missing; skipping tab init");
    return;
  }

  const validKeys = tabs
    .map((tab) => tab.dataset.tab ?? "")
    .filter((key) => key.length > 0);

  const stored = await readStoredTab();
  applyActiveTab(resolveActiveTab(stored, validKeys), tabs, panels);

  for (const tab of tabs) {
    tab.addEventListener("click", () => {
      const key = tab.dataset.tab;
      if (key) {
        applyActiveTab(key, tabs, panels);
        writeStoredTab(key);
      }
    });
  }

  tablist.addEventListener("keydown", (event) => {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") {
      return;
    }
    const currentIndex = tabs.findIndex(
      (tab) => tab.getAttribute("aria-selected") === "true"
    );
    if (currentIndex === -1) {
      return;
    }
    const delta = event.key === "ArrowRight" ? 1 : -1;
    const nextTab = tabs[(currentIndex + delta + tabs.length) % tabs.length];
    if (!nextTab) {
      return;
    }
    const nextKey = nextTab.dataset.tab;
    if (nextKey) {
      applyActiveTab(nextKey, tabs, panels);
      writeStoredTab(nextKey);
      nextTab.focus();
    }
  });
}

if (typeof document !== "undefined") {
  void initTabs();
}

export { ACTIVE_TAB_STORAGE_KEY };
