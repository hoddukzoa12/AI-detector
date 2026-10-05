/* eslint-disable @typescript-eslint/no-unused-vars */

function createOverlayRectBox(rect: DOMRect, background: string, border: string): HTMLDivElement {
  const box = document.createElement("div");
  box.style.position = "fixed";
  box.style.left = `${rect.left}px`;
  box.style.top = `${rect.top}px`;
  box.style.width = `${rect.width}px`;
  box.style.height = `${rect.height}px`;
  box.style.pointerEvents = "none";
  box.style.background = background;
  box.style.border = border;
  box.style.boxSizing = "border-box";
  box.style.borderRadius = "2px";
  return box;
}

function createPickerChromePanel(panelId: string): HTMLDivElement {
  const panel = document.createElement("div");
  panel.id = panelId;
  panel.style.position = "fixed";
  panel.style.padding = "12px";
  panel.style.background = "#231f17";
  panel.style.color = "#f7f4eb";
  panel.style.zIndex = "2147483647";
  panel.style.boxShadow = "0 12px 30px rgba(0,0,0,0.24)";
  panel.style.font = '12px "SF Mono", "IBM Plex Mono", ui-monospace, monospace';
  return panel;
}

function createPreviewChromePanel(width: string): HTMLDivElement {
  document.getElementById(PICKER_PREVIEW_PANEL_ID)?.remove();
  const panel = createPickerChromePanel(PICKER_PREVIEW_PANEL_ID);
  panel.style.right = "16px";
  panel.style.bottom = "64px";
  panel.style.width = width;
  return panel;
}

function removePickerArtifacts(): void {
  document.getElementById(PICKER_OVERLAY_ID)?.remove();
  document.getElementById(`${PICKER_OVERLAY_ID}-label`)?.remove();
  document.getElementById(PICKER_STATUS_BADGE_ID)?.remove();
  document.getElementById(PICKER_PREVIEW_PANEL_ID)?.remove();
  document.getElementById(PICKER_PREVIEW_STYLE_ID)?.remove();
  document.getElementById(PICKER_SESSION_PANEL_ID)?.remove();
  document.getElementById(PICKER_SESSION_OVERLAY_ID)?.remove();
  document.documentElement.style.cursor = "";
}

function buildOverlay(): HTMLDivElement {
  removePickerArtifacts();
  const overlay = document.createElement("div");
  overlay.id = PICKER_OVERLAY_ID;
  overlay.style.position = "fixed";
  overlay.style.left = "0";
  overlay.style.top = "0";
  overlay.style.width = "100vw";
  overlay.style.height = "100vh";
  overlay.style.pointerEvents = "auto";
  overlay.style.zIndex = "2147483645";
  overlay.style.transition = "all 80ms ease-out";
  document.documentElement.append(overlay);
  return overlay;
}

function buildPickerLabel(): HTMLDivElement {
  const label = document.createElement("div");
  label.id = `${PICKER_OVERLAY_ID}-label`;
  label.style.position = "fixed";
  label.style.right = "16px";
  label.style.bottom = "16px";
  label.style.padding = "10px 12px";
  label.style.background = "#231f17";
  label.style.color = "#f7f4eb";
  label.style.font = '12px "SF Mono", "IBM Plex Mono", ui-monospace, monospace';
  label.style.zIndex = "2147483647";
  label.style.pointerEvents = "none";
  label.textContent = `인포커터 선택 모드: ${currentFrameLabel()} / 숨길 요소를 클릭하거나 Escape로 취소하세요.`;
  document.documentElement.append(label);
  return label;
}

function setPickerLabelText(text: string): void {
  const label = document.getElementById(`${PICKER_OVERLAY_ID}-label`);
  if (label instanceof HTMLDivElement) {
    label.textContent = text;
  }
}

function setPickerStatusBadge(label: string, tone: string): void {
  let badge = document.getElementById(PICKER_STATUS_BADGE_ID);
  if (!(badge instanceof HTMLDivElement)) {
    badge = document.createElement("div");
    badge.id = PICKER_STATUS_BADGE_ID;
    badge.style.position = "fixed";
    badge.style.right = "16px";
    badge.style.bottom = "116px";
    badge.style.padding = "8px 10px";
    badge.style.font = '12px "SF Mono", "IBM Plex Mono", ui-monospace, monospace';
    badge.style.zIndex = "2147483647";
    badge.style.pointerEvents = "none";
    badge.style.border = "1px solid rgba(255,255,255,0.2)";
    badge.style.boxShadow = "0 8px 20px rgba(0,0,0,0.18)";
    document.documentElement.append(badge);
  }

  badge.textContent = label;
  badge.style.background = tone;
  badge.style.color = "#231f17";
}

function setOverlayRects(overlay: HTMLDivElement, rects: DOMRect[], tone: OverlayTone = "hover"): void {
  overlay.replaceChildren();
  overlay.style.opacity = rects.length > 0 ? "1" : "0";

  const palette = tone === "preview"
    ? {
        background: "rgba(59, 130, 246, 0.14)",
        border: "2px solid rgba(59, 130, 246, 0.95)"
      }
    : {
        background: "rgba(217, 119, 6, 0.12)",
        border: "2px solid rgba(217, 119, 6, 0.95)"
      };

  for (const rect of rects) {
    overlay.append(createOverlayRectBox(rect, palette.background, palette.border));
  }
}

function ensureSessionOverlayRoot(): HTMLDivElement {
  const existingOverlay = document.getElementById(PICKER_SESSION_OVERLAY_ID);
  if (existingOverlay instanceof HTMLDivElement) {
    return existingOverlay;
  }

  const overlay = document.createElement("div");
  overlay.id = PICKER_SESSION_OVERLAY_ID;
  overlay.style.position = "fixed";
  overlay.style.left = "0";
  overlay.style.top = "0";
  overlay.style.width = "100vw";
  overlay.style.height = "100vh";
  overlay.style.pointerEvents = "none";
  overlay.style.zIndex = "2147483646";
  document.documentElement.append(overlay);
  return overlay;
}

function applyPreviewSelector(selector: string): boolean {
  let style = document.getElementById(PICKER_PREVIEW_STYLE_ID);
  if (!(style instanceof HTMLStyleElement)) {
    style = document.createElement("style");
    style.id = PICKER_PREVIEW_STYLE_ID;
    document.documentElement.append(style);
  }

  if (matchCountForSelector(selector) === null) {
    style.textContent = "";
    return false;
  }

  style.textContent = `
    ${selector} {
      outline: 2px solid rgba(59, 130, 246, 0.95) !important;
      outline-offset: -1px !important;
      background: rgba(59, 130, 246, 0.10) !important;
      box-shadow: inset 0 0 0 9999px rgba(59, 130, 246, 0.08) !important;
    }
  `;
  return true;
}

function applySelectionSessionHighlights(): void {
  const overlay = ensureSessionOverlayRoot();
  overlay.replaceChildren();

  if (selectionSession.length === 0) {
    overlay.style.opacity = "0";
    return;
  }

  overlay.style.opacity = "1";

  for (const [index, card] of selectionSession.entries()) {
    const palette = selectionSessionPalette[index % selectionSessionPalette.length] ?? {
      fill: "rgba(59, 130, 246, 0.10)",
      stroke: "rgba(59, 130, 246, 0.92)"
    };
    const rects = selectorRects(card.selector);
    for (const [rectIndex, rect] of rects.entries()) {
      const box = createOverlayRectBox(rect, palette.fill, `2px solid ${palette.stroke}`);
      overlay.append(box);

      if (rectIndex === 0) {
        const badge = document.createElement("div");
        badge.textContent = card.cardName;
        badge.style.position = "fixed";
        badge.style.left = `${Math.max(8, rect.left)}px`;
        badge.style.top = `${Math.max(8, rect.top - 22)}px`;
        badge.style.padding = "2px 6px";
        badge.style.background = palette.stroke;
        badge.style.color = "#fff";
        badge.style.font = '11px "SF Mono", "IBM Plex Mono", ui-monospace, monospace';
        badge.style.borderRadius = "999px";
        badge.style.boxShadow = "0 4px 12px rgba(0,0,0,0.18)";
        overlay.append(badge);
      }
    }
  }
}
