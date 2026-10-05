# Picker Quick Multi-Select — Phase 2 (Quick Toggle) Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the picker's click→preview-panel→restart flow with quick toggle: a single click adds/removes the clicked element (element-specific selector) into the session with no panel and no restart; refine happens on demand from a session-card "다듬기" button.

**Architecture:** Builds on the Phase 1 decomposition. Extract hover-candidate state into `picker-hover.ts`; add quick-toggle + element-specific-selector helpers to `picker-session.ts`; add `openRefinePanel(cardId)` to `picker-refine-panel.ts`; add a "다듬기" button + a re-renderable session panel to `picker-session-panel.ts`; rewrite the `startPicker` controller to wire click→`sessionToggleElement` and stay active.

**Tech Stack:** TypeScript content global scripts (shared global scope), Manifest V3.

---

## Working context

- Worktree: `/Users/jeonghan/Documents/WORK/WORKSPACE/apps/chrome-extension-mono-wt-infocutter-pickerquick`
- Run from: `cd vibecode-chrome-extension-infocutter`
- Branch: `feat/infocutter-picker-quick-select-20260530` (Phase 1 already committed on it).
- Verification gate per task: `./infocutter check` (lint + typecheck + test).
- Strict: no `//` line comments (`/* */` allowed). New content files start with `/* eslint-disable @typescript-eslint/no-unused-vars */`.
- Content scripts share one global scope. New globals resolve across files; new files must be registered in the three content-script lists (manifest, build.mjs, service-worker.ts) before `picker-ui.js`.
- Final manual verification uses a Mode-A devtools harness (see Task 5).

## File structure (Phase 2)

- `src/content/picker-session.ts` (modify) — add `sessionEntryForElement`, `sessionEntryById`, `sessionIsSelected`, `quickSelectorForElement`, `sessionToggleElement`, `sessionUpdateSelector`.
- `src/content/picker-refine-panel.ts` (modify) — add `openRefinePanel(cardId)`.
- `src/content/picker-session-panel.ts` (modify) — add a "다듬기" button per card + module-level `renderSessionPanel(onDone, onCancel)` / `refreshSessionPanel()`.
- `src/content/picker-hover.ts` (new) — hover-candidate state + cycling.
- `src/content/picker-ui.ts` (rewrite `startPicker`) — quick-toggle controller; `hideTargetElement` unchanged.
- Three content-script lists gain `picker-hover.js`.

---

## Task 1: picker-session quick-toggle helpers

**Files:** Modify `src/content/picker-session.ts`

- [ ] **Step 1: Append the helpers**

Append to `src/content/picker-session.ts` (after the existing functions):

```ts
function sessionEntryForElement(element: Element): PickerSessionEntry | null {
  const scope = currentFrameScope();
  for (const entry of selectionSession) {
    if (entry.frameScope !== scope) {
      continue;
    }
    try {
      if (element.matches(entry.selector)) {
        return entry;
      }
    } catch {
      /* ignore invalid selector */
    }
  }
  return null;
}

function sessionEntryById(cardId: string): PickerSessionEntry | null {
  return selectionSession.find((entry) => entry.cardId === cardId) ?? null;
}

function sessionIsSelected(element: Element): boolean {
  return sessionEntryForElement(element) !== null;
}

function quickSelectorForElement(element: Element): string {
  const candidates = buildSelectorCandidates(element);
  for (const candidate of candidates) {
    if (selectorAssessment(candidate).matches === 1) {
      return candidate;
    }
  }
  return buildSelector(element);
}

function sessionToggleElement(element: Element): "added" | "removed" {
  const existing = sessionEntryForElement(element);
  if (existing) {
    sessionRemove(existing.cardId);
    return "removed";
  }

  sessionAdd({
    cardId: generateId(),
    cardName: elementShortLabel(element),
    createdAt: new Date().toISOString(),
    frameScope: currentFrameScope(),
    selector: quickSelectorForElement(element)
  });
  return "added";
}

function sessionUpdateSelector(cardId: string, selector: string): void {
  selectionSession = selectionSession.map((entry) => (
    entry.cardId === cardId ? { ...entry, selector } : entry
  ));
}
```

- [ ] **Step 2: Verify**

Run: `./infocutter check`
Expected: PASS. (`buildSelectorCandidates`, `selectorAssessment`, `buildSelector`, `elementShortLabel`, `generateId`, `currentFrameScope`, and the existing `sessionAdd`/`sessionRemove` are content globals; `PickerSessionEntry` is ambient. The new functions are unused so far — the eslint-disable header at the top of the file covers that.)

- [ ] **Step 3: Commit**

```bash
git add src/content/picker-session.ts
git commit -m "feat(infocutter): add session quick-toggle + element-specific selector helpers"
```

---

## Task 2: refine-by-card (openRefinePanel + session-panel button)

`openRefinePanel` (refine-panel) and `refreshSessionPanel` (session-panel) are
mutually dependent globals, so they are implemented and verified together in this
single task across two files.

**Files:** Modify `src/content/picker-refine-panel.ts` and `src/content/picker-session-panel.ts`

- [ ] **Step 1: Append `openRefinePanel` to `picker-refine-panel.ts`**

Append to `src/content/picker-refine-panel.ts` (after `buildPreviewPanel`):

```ts
function openRefinePanel(cardId: string): void {
  const entry = sessionEntryById(cardId);
  if (!entry) {
    return;
  }

  const element = document.querySelector(entry.selector);
  if (!element) {
    buildPickerLabel().textContent = `다듬을 요소를 현재 페이지에서 찾지 못했습니다: ${entry.selector}`;
    return;
  }

  let depthChain = buildDepthChain(element);
  let depthIndex = 0;
  let candidateIndex = 0;

  const closeRefine = (): void => {
    document.getElementById(PICKER_PREVIEW_PANEL_ID)?.remove();
    document.getElementById(PICKER_PREVIEW_STYLE_ID)?.remove();
    applySelectionSessionHighlights();
  };

  const renderRefine = (): void => {
    const focusElement = depthChain[depthIndex] ?? element;
    const candidates = buildSelectorCandidates(focusElement);
    const selector = candidates[candidateIndex] ?? buildSelector(focusElement);
    applyPreviewSelector(selector);

    buildPreviewPanel(
      [element],
      0,
      element,
      depthChain,
      depthIndex,
      depthChain.length,
      candidates,
      candidateIndex,
      selector,
      entry.cardName,
      () => {},
      () => {},
      (nextSelectorCandidateIndex) => {
        candidateIndex = nextSelectorCandidateIndex;
        renderRefine();
      },
      (selectedSelector) => {
        sessionUpdateSelector(cardId, selectedSelector);
        closeRefine();
        refreshSessionPanel();
      },
      () => {
        depthIndex = Math.max(0, depthIndex - 1);
        candidateIndex = 0;
        renderRefine();
      },
      () => {
        candidateIndex = (candidateIndex + 1) % candidates.length;
        renderRefine();
      },
      () => {
        depthIndex = Math.min(depthChain.length - 1, depthIndex + 1);
        candidateIndex = 0;
        renderRefine();
      },
      () => {
        closeRefine();
      }
    );
  };

  renderRefine();
}
```

- [ ] **Step 2: Add module re-render state at the top of `picker-session-panel.ts`**

In `src/content/picker-session-panel.ts`, directly below the `/* eslint-disable ... */` header (before `function buildSessionPanel`), add:

```ts
let sessionPanelOnDone: () => void = () => {};
let sessionPanelOnCancel: () => void = () => {};

function renderSessionPanel(onDone: () => void, onCancel: () => void): void {
  sessionPanelOnDone = onDone;
  sessionPanelOnCancel = onCancel;
  buildSessionPanel(onDone, onCancel);
}

function refreshSessionPanel(): void {
  buildSessionPanel(sessionPanelOnDone, sessionPanelOnCancel);
}
```

- [ ] **Step 3: Add a 다듬기 button to each card**

In `buildSessionPanel`, find the card's remove button block:

```ts
    const removeButton = document.createElement("button");
    removeButton.type = "button";
    removeButton.textContent = "카드 제거";
    removeButton.style.marginTop = "8px";
    removeButton.style.border = "1px solid #f7f4eb";
    removeButton.style.background = "transparent";
    removeButton.style.color = "#f7f4eb";
    removeButton.style.padding = "6px 8px";
    removeButton.style.cursor = "pointer";
    removeButton.addEventListener("click", () => {
      sessionRemove(card.cardId);
      buildSessionPanel(onDone, onCancel);
    });

    item.append(nameInput, cardId, scope, selector, removeButton);
```

Replace it with (adds a refine button and includes it in the append):

```ts
    const refineButton = document.createElement("button");
    refineButton.type = "button";
    refineButton.textContent = "다듬기";
    refineButton.style.marginTop = "8px";
    refineButton.style.marginRight = "6px";
    refineButton.style.border = "1px solid #f7f4eb";
    refineButton.style.background = "transparent";
    refineButton.style.color = "#f7f4eb";
    refineButton.style.padding = "6px 8px";
    refineButton.style.cursor = "pointer";
    refineButton.addEventListener("click", () => {
      openRefinePanel(card.cardId);
    });

    const removeButton = document.createElement("button");
    removeButton.type = "button";
    removeButton.textContent = "카드 제거";
    removeButton.style.marginTop = "8px";
    removeButton.style.border = "1px solid #f7f4eb";
    removeButton.style.background = "transparent";
    removeButton.style.color = "#f7f4eb";
    removeButton.style.padding = "6px 8px";
    removeButton.style.cursor = "pointer";
    removeButton.addEventListener("click", () => {
      sessionRemove(card.cardId);
      buildSessionPanel(sessionPanelOnDone, sessionPanelOnCancel);
    });

    item.append(nameInput, cardId, scope, selector, refineButton, removeButton);
```

- [ ] **Step 4: Verify both files together**

Run: `./infocutter check`
Expected: PASS. Both `openRefinePanel` (refine-panel) and `refreshSessionPanel` (session-panel) now exist as globals, so the mutual references resolve.

- [ ] **Step 5: Commit both files**

```bash
git add src/content/picker-refine-panel.ts src/content/picker-session-panel.ts
git commit -m "feat(infocutter): refine a session card via 다듬기 (openRefinePanel)"
```

---

## Task 3: picker-hover.ts + rewrite the controller to quick-toggle

**Files:**
- Create `src/content/picker-hover.ts`
- Rewrite `startPicker` in `src/content/picker-ui.ts`
- Register `picker-hover.js` in the three lists

- [ ] **Step 1: Create `src/content/picker-hover.ts`**

```ts
/* eslint-disable @typescript-eslint/no-unused-vars */

let pickerHoverCandidates: Element[] = [];
let pickerHoverIndex = 0;

function hoverUpdateAt(clientX: number, clientY: number): void {
  const overlay = document.getElementById(PICKER_OVERLAY_ID);
  const sessionOverlay = document.getElementById(PICKER_SESSION_OVERLAY_ID);
  const previousOverlayDisplay = overlay instanceof HTMLElement ? overlay.style.display : null;
  const previousSessionDisplay = sessionOverlay instanceof HTMLElement ? sessionOverlay.style.display : null;

  if (overlay instanceof HTMLElement) {
    overlay.style.display = "none";
  }
  if (sessionOverlay instanceof HTMLElement) {
    sessionOverlay.style.display = "none";
  }

  const targets = document.elementsFromPoint(clientX, clientY)
    .filter((element): element is Element => element instanceof Element)
    .filter((element) => !isExtensionUiElement(element));

  if (overlay instanceof HTMLElement && previousOverlayDisplay !== null) {
    overlay.style.display = previousOverlayDisplay;
  }
  if (sessionOverlay instanceof HTMLElement && previousSessionDisplay !== null) {
    sessionOverlay.style.display = previousSessionDisplay;
  }

  pickerHoverCandidates = [...targets].sort((left, right) => {
    const leftIndex = targets.indexOf(left);
    const rightIndex = targets.indexOf(right);
    return candidateTargetScore(right, rightIndex) - candidateTargetScore(left, leftIndex);
  });
  pickerHoverIndex = 0;
}

function hoverCurrentTarget(): Element | null {
  return pickerHoverCandidates[pickerHoverIndex] ?? null;
}

function hoverCount(): number {
  return pickerHoverCandidates.length;
}

function hoverIndex(): number {
  return pickerHoverIndex;
}

function hoverCycle(backwards: boolean): void {
  if (pickerHoverCandidates.length <= 1) {
    return;
  }
  pickerHoverIndex = backwards
    ? (pickerHoverIndex - 1 + pickerHoverCandidates.length) % pickerHoverCandidates.length
    : (pickerHoverIndex + 1) % pickerHoverCandidates.length;
}

function hoverReset(): void {
  pickerHoverCandidates = [];
  pickerHoverIndex = 0;
}
```

- [ ] **Step 2: Replace the entire `startPicker` function in `src/content/picker-ui.ts`**

Replace `startPicker` (the whole function, from `function startPicker(): void {` through its closing `}` just before `async function hideTargetElement`) with EXACTLY:

```ts
function startPicker(): void {
  pickerStop?.();

  const overlay = buildOverlay();
  buildPickerLabel();
  let active = true;
  let overlayOpen = true;
  let currentOverlaySelector: string | null = null;
  let currentOverlayFallbackElement: Element | null = null;
  hoverReset();
  document.documentElement.style.cursor = "crosshair";
  updatePickerFocusState(true, currentFrameLabel());

  const syncOverlay = (): void => {
    if (!overlayOpen) {
      return;
    }
    const rects = currentOverlaySelector ? selectorRects(currentOverlaySelector) : [];
    const fallbackRects = currentOverlayFallbackElement ? [currentOverlayFallbackElement.getBoundingClientRect()] : [];
    setOverlayRects(overlay, rects.length > 0 ? rects : fallbackRects, "hover");
    applySelectionSessionHighlights();
  };

  const renderHover = (): void => {
    const target = hoverCurrentTarget();
    if (!target) {
      currentOverlaySelector = null;
      currentOverlayFallbackElement = null;
      syncOverlay();
      setPickerStatusBadge("선택 상태: 후보 없음", "#fde68a");
      return;
    }

    const hoverSummary = buildHoverSummary(target);
    currentOverlaySelector = hoverSummary.selector;
    currentOverlayFallbackElement = target;
    syncOverlay();
    setPickerLabelText(hoverSummary.label);

    const countLabel = `후보 ${hoverIndex() + 1}/${hoverCount()} · Tab 전환`;
    if (sessionIsSelected(target)) {
      setPickerStatusBadge(`이미 선택됨 · 다시 클릭하면 해제 · ${countLabel}`, "#fca5a5");
    } else if (hoverSummary.assessment) {
      setPickerStatusBadge(`클릭하면 담기 · ${hoverSummary.assessment.label} · ${countLabel}`, hoverSummary.assessment.tone);
    } else {
      setPickerStatusBadge(`클릭하면 담기 · ${countLabel}`, "#fde68a");
    }
  };

  const renderSession = (): void => {
    renderSessionPanel(
      () => {
        void (async () => {
          await sessionPersist();
          await renderAllRules();
          pickerStop?.();
        })();
      },
      () => {
        sessionClear();
        applySelectionSessionHighlights();
        pickerStop?.();
      }
    );
  };

  const updateOverlay = (event: MouseEvent): void => {
    if (!active) {
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    hoverUpdateAt(event.clientX, event.clientY);
    if (hoverCount() === 0) {
      return;
    }
    renderHover();
  };

  const handleViewportChange = (): void => {
    syncOverlay();
  };

  const stopPicker = (): void => {
    active = false;
    overlayOpen = false;
    document.removeEventListener("mousemove", updateOverlay, true);
    document.removeEventListener("click", handleClick, true);
    document.removeEventListener("keydown", handleKeydown, true);
    window.removeEventListener("scroll", handleViewportChange, true);
    window.removeEventListener("resize", handleViewportChange, true);
    removePickerArtifacts();
    pickerStop = null;
    updatePickerFocusState(false, "선택 모드 비활성");
  };

  pickerStop = stopPicker;

  const handleKeydown = (event: KeyboardEvent): void => {
    if (active && event.key === "Tab" && hoverCount() > 1) {
      event.preventDefault();
      event.stopPropagation();
      hoverCycle(event.shiftKey);
      renderHover();
      return;
    }

    if (event.key === "Escape") {
      stopPicker();
    }
  };

  const enterIframe = (frameTarget: HTMLIFrameElement): void => {
    active = false;
    document.removeEventListener("mousemove", updateOverlay, true);
    document.removeEventListener("click", handleClick, true);

    buildIframePanel(
      frameTarget,
      () => {
        void (async () => {
          await hideTargetElement(frameTarget);
          stopPicker();
        })();
      },
      () => {
        void (async () => {
          const accessMode = iframeAccessMode(frameTarget);
          const started = await startPickerInIframe(frameTarget);
          if (!started) {
            const label = buildPickerLabel();
            label.textContent = accessMode === "cross-origin"
              ? "cross-origin iframe이라 내부 선택을 시작하지 못했습니다. 프레임 자체 숨기기를 사용해보세요."
              : "iframe 내부 선택을 시작하지 못했습니다. 프레임 자체 숨기기를 사용해보세요.";
            return;
          }

          document.getElementById(PICKER_PREVIEW_PANEL_ID)?.remove();
          document.getElementById(PICKER_PREVIEW_STYLE_ID)?.remove();
          document.getElementById(`${PICKER_OVERLAY_ID}-label`)?.remove();
          buildPickerLabel().textContent = "iframe 안으로 들어갔습니다. 프레임 내부에서 다시 요소를 선택하세요.";
          window.removeEventListener("scroll", handleViewportChange, true);
          window.removeEventListener("resize", handleViewportChange, true);
          overlay.remove();
          document.documentElement.style.cursor = "";
          overlayOpen = false;
          pickerStop = null;
          updatePickerFocusState(false, "iframe 내부 선택 대기 중");
        })();
      },
      () => {
        stopPicker();
      }
    );
  };

  const handleClick = (event: MouseEvent): void => {
    if (!active) {
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation();

    hoverUpdateAt(event.clientX, event.clientY);
    const target = hoverCurrentTarget();
    if (!target) {
      return;
    }

    if (target instanceof HTMLIFrameElement) {
      enterIframe(target);
      return;
    }

    sessionToggleElement(target);
    renderHover();
    renderSession();
  };

  const swallowPointer = (event: MouseEvent): void => {
    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation();
  };

  overlay.addEventListener("mousemove", updateOverlay, true);
  overlay.addEventListener("mousedown", swallowPointer, true);
  overlay.addEventListener("mouseup", swallowPointer, true);
  overlay.addEventListener("click", handleClick, true);
  document.addEventListener("keydown", handleKeydown, true);
  window.addEventListener("scroll", handleViewportChange, true);
  window.addEventListener("resize", handleViewportChange, true);

  renderSession();
}
```

- [ ] **Step 3: Register `picker-hover.js`**

Insert `"src/content/picker-hover.js"` immediately BEFORE `"src/content/picker-session.js"` in all three lists (`public/manifest.json` `content_scripts[0].js`, `scripts/build.mjs` `contentScriptFiles`, `src/background/service-worker.ts` `contentScriptFiles`). (picker-hover uses `candidateTargetScore`/`isExtensionUiElement` from picker-analysis, which loads before it, and is used by the controller, which loads after — so placing it among the picker modules is correct; immediately before picker-session keeps it grouped.)

- [ ] **Step 4: Verify**

Run: `./infocutter check`
Expected: PASS. Then verify load order:
```bash
node -e "const js=require('./dist/manifest.json').content_scripts[0].js; const h=js.indexOf('src/content/picker-hover.js'); const a=js.indexOf('src/content/picker-analysis.js'); const u=js.indexOf('src/content/picker-ui.js'); if(!(a<h && h<u)) throw new Error('order: '+js.join(',')); console.log('order ok')"
```
Expected: `order ok`.

- [ ] **Step 5: Commit**

```bash
git add src/content/picker-hover.ts src/content/picker-ui.ts public/manifest.json scripts/build.mjs src/background/service-worker.ts
git commit -m "feat(infocutter): quick-toggle picker controller + picker-hover module"
```

---

## Task 4: Final verification (devtools harness)

**Files:** none (verification only)

- [ ] **Step 1: Build**

Run: `./infocutter rc` → expect rebuild + check + package PASS.

- [ ] **Step 2: Drive a Mode-A harness (chrome-devtools MCP)**

Serve `dist/` over HTTP, load a harness page that includes the compiled content scripts in manifest order (with a `chrome` shim, excluding `index.js`), and verify the NEW behavior end to end via `evaluate_script`:
- `startPicker()` renders overlay + label + an (empty) session controller.
- `sessionToggleElement(document.getElementById('ad1'))` returns `"added"`; `applySelectionSessionHighlights()` shows a numbered outline; `refreshSessionPanel()` lists one card with a 다듬기 button.
- `sessionToggleElement(document.getElementById('ad1'))` again returns `"removed"`; the card disappears.
- Add two cards, `openRefinePanel(cardId)` opens the precise panel (`#infocutter-preview-panel` exists); narrowing/widening updates and `sessionUpdateSelector` changes the card.
- `quickSelectorForElement(document.getElementById('ad1'))` returns a selector matching exactly one element.
- `sessionPersist()` writes `infocutter.ruleStore` (via the shim) and clears the session.
- Console has no errors.

- [ ] **Step 3: Confirm gate**

Run: `./infocutter check` → expect PASS (still green).

---

## Self-review notes (reconciled with spec)

- Quick toggle: `handleClick` → `sessionToggleElement` (element-specific selector via `quickSelectorForElement`, match==1), stays active, no restart (spec §Interaction model). Re-click removes via `sessionEntryForElement` matching (spec §De-selecting).
- Refine via card: 다듬기 → `openRefinePanel(cardId)` edits one card's selector in place, re-resolving the element with `querySelector` and reporting if missing (spec §Data flow step 2, §Edge cases).
- Picker-hover extracted from the controller closure (spec §Phase 2). Controller slimmed to wiring + lifecycle.
- Reads of `selectionSession` widen (sessionEntryForElement/sessionEntryById iterate it); all WRITES remain in picker-session.ts (sole-writer rule preserved).
- No storage/message/permission changes (spec §Non-goals).
- Tests: content is not node-testable; verification is the devtools harness + `./infocutter check` (spec §Testing).
