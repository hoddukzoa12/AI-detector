/* eslint-disable @typescript-eslint/no-unused-vars */
/* eslint-disable @typescript-eslint/no-empty-function */
let sessionPanelOnDone: () => void = () => {};
let sessionPanelOnCancel: () => void = () => {};
/* eslint-enable @typescript-eslint/no-empty-function */

function renderSessionPanel(onDone: () => void, onCancel: () => void): void {
  sessionPanelOnDone = onDone;
  sessionPanelOnCancel = onCancel;
  buildSessionPanel(onDone, onCancel);
}

function refreshSessionPanel(): void {
  buildSessionPanel(sessionPanelOnDone, sessionPanelOnCancel);
}

function buildSessionPanel(onDone: () => void, onCancel: () => void): HTMLDivElement | null {
  document.getElementById(PICKER_SESSION_PANEL_ID)?.remove();
  applySelectionSessionHighlights();

  if (selectionSession.length === 0) {
    return null;
  }

  const panel = createPickerChromePanel(PICKER_SESSION_PANEL_ID);
  panel.style.left = "16px";
  panel.style.bottom = "16px";
  panel.style.width = "320px";
  panel.style.maxHeight = "50vh";
  panel.style.overflow = "auto";

  const title = document.createElement("div");
  title.textContent = `선택 세션 카드 ${selectionSession.length}개`;
  title.style.fontWeight = "700";
  title.style.marginBottom = "8px";

  const list = document.createElement("div");
  list.style.display = "grid";
  list.style.gap = "8px";
  list.style.marginBottom = "10px";

  for (const card of selectionSession) {
    const item = document.createElement("div");
    item.style.padding = "8px";
    item.style.background = "rgba(255,255,255,0.08)";
    item.style.border = "1px solid rgba(255,255,255,0.12)";

    const nameInput = document.createElement("input");
    nameInput.type = "text";
    nameInput.value = card.cardName;
    nameInput.placeholder = "카드 이름";
    nameInput.style.display = "block";
    nameInput.style.width = "100%";
    nameInput.style.boxSizing = "border-box";
    nameInput.style.padding = "8px";
    nameInput.style.background = "rgba(255,255,255,0.08)";
    nameInput.style.color = "#f7f4eb";
    nameInput.style.border = "1px solid rgba(255,255,255,0.18)";
    nameInput.style.font = '12px "SF Mono", "IBM Plex Mono", ui-monospace, monospace';
    nameInput.addEventListener("input", () => {
      sessionRename(card.cardId, nameInput.value);
    });

    const cardId = document.createElement("div");
    cardId.textContent = `카드 ID: ${card.cardId}`;
    cardId.style.color = "#c9ba9c";
    cardId.style.marginTop = "6px";
    cardId.style.wordBreak = "break-all";

    const scope = document.createElement("div");
    scope.textContent = card.frameScope ? `iframe: ${card.frameScope}` : "메인 문서";
    scope.style.color = "#c9ba9c";
    scope.style.marginTop = "4px";

    const selector = document.createElement("code");
    selector.textContent = card.selector;
    selector.style.display = "block";
    selector.style.marginTop = "6px";
    selector.style.whiteSpace = "pre-wrap";
    selector.style.wordBreak = "break-word";

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
    list.append(item);
  }

  const actions = document.createElement("div");
  actions.style.display = "flex";
  actions.style.gap = "8px";

  const doneButton = document.createElement("button");
  doneButton.type = "button";
  doneButton.textContent = "완료 적용";
  doneButton.style.flex = "1";

  const cancelButton = document.createElement("button");
  cancelButton.type = "button";
  cancelButton.textContent = "세션 취소";
  cancelButton.style.flex = "1";

  for (const button of [doneButton, cancelButton]) {
    button.style.border = "1px solid #f7f4eb";
    button.style.background = "transparent";
    button.style.color = "#f7f4eb";
    button.style.padding = "8px 10px";
    button.style.cursor = "pointer";
  }

  doneButton.disabled = selectionSession.length === 0;
  doneButton.addEventListener("click", onDone);
  cancelButton.addEventListener("click", onCancel);

  actions.append(doneButton, cancelButton);
  panel.append(title, list, actions);
  document.documentElement.append(panel);
  return panel;
}
