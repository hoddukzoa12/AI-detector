import { deleteEvidence, listEvidence } from "../shared/evidence-db.js";
import { mutateWatchStore, readWatchStore } from "../shared/watch-storage.js";
import type { EvidenceRecord } from "../shared/evidence-db.js";
import type { WatchStore } from "../../packages/infocutter-watch/src/index.js";
import {
  nameWatchAddButtonElement,
  nameWatchAliasInputElement,
  nameWatchEvidenceListElement,
  nameWatchNameInputElement,
  nameWatchTargetListElement
} from "./elements.js";

function truncateUrl(url: string, maxLength: number): string {
  if (url.length <= maxLength) {
    return url;
  }
  return `${url.slice(0, maxLength)}…`;
}

function renderEvidenceRow(record: EvidenceRecord, onDelete: () => void): HTMLElement {
  const row = document.createElement("div");
  row.className = "options__site-card";

  const header = document.createElement("div");
  header.className = "options__site-header";

  const headingWrap = document.createElement("div");

  const title = document.createElement("p");
  title.className = "options__site-title";
  title.style.fontSize = "14px";
  title.textContent = record.matchedTerm;

  const urlMeta = document.createElement("p");
  urlMeta.className = "options__meta";
  urlMeta.textContent = truncateUrl(record.url, 80);

  const dateMeta = document.createElement("p");
  dateMeta.className = "options__meta";
  dateMeta.textContent = record.capturedAt;

  const snippet = document.createElement("p");
  snippet.className = "options__meta";
  snippet.textContent = record.matchedText.slice(0, 120);

  headingWrap.append(title, urlMeta, dateMeta, snippet);

  const actions = document.createElement("div");
  actions.className = "options__site-actions";

  const pdfButton = document.createElement("button");
  pdfButton.type = "button";
  pdfButton.className = "options__secondary";
  pdfButton.textContent = "PDF 열기";
  pdfButton.addEventListener("click", () => {
    if (typeof record.downloadId === "number") {
      try {
        chrome.downloads.show(record.downloadId);
      } catch {
        /* downloads permission unavailable; ignore */
      }
    }
  });

  const deleteButton = document.createElement("button");
  deleteButton.type = "button";
  deleteButton.className = "options__secondary";
  deleteButton.textContent = "삭제";
  deleteButton.addEventListener("click", () => {
    void (async () => {
      await deleteEvidence(record.id);
      onDelete();
    })();
  });

  actions.append(pdfButton, deleteButton);
  header.append(headingWrap, actions);
  row.append(header);
  return row;
}

function renderEvidenceList(records: EvidenceRecord[], onDelete: () => void): void {
  if (records.length === 0) {
    const empty = document.createElement("p");
    empty.className = "options__empty";
    empty.textContent = "저장된 증거가 없습니다.";
    nameWatchEvidenceListElement.replaceChildren(empty);
    return;
  }

  const rows = records.map((record) => renderEvidenceRow(record, onDelete));
  nameWatchEvidenceListElement.replaceChildren(...rows);
}

function renderTargetList(store: WatchStore, onMutate: () => void): void {
  if (store.targets.length === 0) {
    const empty = document.createElement("p");
    empty.className = "options__empty";
    empty.textContent = "감시 중인 이름이 없습니다.";
    nameWatchTargetListElement.replaceChildren(empty);
    return;
  }

  const rows = store.targets.map((target) => {
    const row = document.createElement("div");
    row.className = "options__site-card";
    row.style.marginBottom = "12px";

    const header = document.createElement("div");
    header.className = "options__site-header";

    const headingWrap = document.createElement("div");

    const nameLabel = document.createElement("p");
    nameLabel.className = "options__site-title";
    nameLabel.style.fontSize = "15px";
    nameLabel.textContent = target.name;

    const aliasesMeta = document.createElement("p");
    aliasesMeta.className = "options__meta";
    aliasesMeta.textContent = target.aliases.length > 0
      ? `별칭: ${target.aliases.join(", ")}`
      : "별칭 없음";

    headingWrap.append(nameLabel, aliasesMeta);

    const actions = document.createElement("div");
    actions.className = "options__site-actions";

    const enableCheckboxWrap = document.createElement("label");
    enableCheckboxWrap.style.display = "inline-flex";
    enableCheckboxWrap.style.alignItems = "center";
    enableCheckboxWrap.style.gap = "6px";
    enableCheckboxWrap.style.fontSize = "13px";
    enableCheckboxWrap.style.cursor = "pointer";

    const enableCheckbox = document.createElement("input");
    enableCheckbox.type = "checkbox";
    enableCheckbox.checked = target.enabled;
    enableCheckbox.addEventListener("change", () => {
      void (async () => {
        await mutateWatchStore({ kind: "toggle", id: target.id, enabled: enableCheckbox.checked });
        onMutate();
      })();
    });

    enableCheckboxWrap.append(enableCheckbox, "사용");

    const deleteButton = document.createElement("button");
    deleteButton.type = "button";
    deleteButton.className = "options__secondary";
    deleteButton.textContent = "삭제";
    deleteButton.addEventListener("click", () => {
      void (async () => {
        await mutateWatchStore({ kind: "remove", id: target.id });
        onMutate();
      })();
    });

    actions.append(enableCheckboxWrap, deleteButton);
    header.append(headingWrap, actions);

    const aliasEditWrap = document.createElement("div");
    aliasEditWrap.className = "options__create-grid";
    aliasEditWrap.style.marginTop = "12px";
    aliasEditWrap.style.gridTemplateColumns = "minmax(220px, 1fr) 100px";

    const aliasInput = document.createElement("input");
    aliasInput.className = "options__input";
    aliasInput.type = "text";
    aliasInput.placeholder = "별칭 (쉼표 구분)";
    aliasInput.value = target.aliases.join(", ");

    const saveAliasButton = document.createElement("button");
    saveAliasButton.type = "button";
    saveAliasButton.className = "options__secondary";
    saveAliasButton.textContent = "저장";
    saveAliasButton.addEventListener("click", () => {
      void (async () => {
        const aliases = aliasInput.value
          .split(",")
          .map((s) => s.trim())
          .filter((s) => s.length > 0);
        await mutateWatchStore({ kind: "setAliases", id: target.id, aliases });
        onMutate();
      })();
    });

    aliasEditWrap.append(aliasInput, saveAliasButton);
    row.append(header, aliasEditWrap);
    return row;
  });

  nameWatchTargetListElement.replaceChildren(...rows);
}

function renderSettings(store: WatchStore, onMutate: () => void): void {
  const panel = document.getElementById("name-watch-settings-panel");
  if (!panel) {
    return;
  }

  panel.replaceChildren();

  const globalWrap = document.createElement("label");
  globalWrap.style.display = "flex";
  globalWrap.style.alignItems = "center";
  globalWrap.style.gap = "10px";
  globalWrap.style.cursor = "pointer";
  globalWrap.style.marginBottom = "14px";

  const globalCheckbox = document.createElement("input");
  globalCheckbox.type = "checkbox";
  globalCheckbox.id = "name-watch-global-enabled";
  globalCheckbox.checked = store.settings.globalEnabled;
  globalCheckbox.addEventListener("change", () => {
    void (async () => {
      await mutateWatchStore({ kind: "setGlobalEnabled", enabled: globalCheckbox.checked });
      onMutate();
    })();
  });

  const globalLabel = document.createElement("span");
  globalLabel.textContent = "전역 사용";

  globalWrap.append(globalCheckbox, globalLabel);

  const maskWrap = document.createElement("label");
  maskWrap.style.display = "flex";
  maskWrap.style.alignItems = "center";
  maskWrap.style.gap = "10px";
  maskWrap.style.cursor = "pointer";

  const maskCheckbox = document.createElement("input");
  maskCheckbox.type = "checkbox";
  maskCheckbox.id = "name-watch-auto-mask";
  maskCheckbox.checked = store.settings.autoMask;
  maskCheckbox.addEventListener("change", () => {
    void (async () => {
      await mutateWatchStore({ kind: "setAutoMask", enabled: maskCheckbox.checked });
      onMutate();
    })();
  });

  const maskLabel = document.createElement("span");
  maskLabel.textContent = "자동 가리기(마스킹)";

  maskWrap.append(maskCheckbox, maskLabel);
  panel.append(globalWrap, maskWrap);
}

export async function renderNameWatch(): Promise<void> {
  const store = await readWatchStore();
  const evidenceRecords = await listEvidence();

  const onMutate = (): void => {
    void renderNameWatch();
  };

  renderTargetList(store, onMutate);
  renderSettings(store, onMutate);
  renderEvidenceList(evidenceRecords, onMutate);
}

export function wireNameWatch(): void {
  nameWatchAddButtonElement.addEventListener("click", () => {
    void (async () => {
      const name = nameWatchNameInputElement.value.trim();
      if (!name) {
        return;
      }
      const aliases = nameWatchAliasInputElement.value
        .split(",")
        .map((s) => s.trim())
        .filter((s) => s.length > 0);
      await mutateWatchStore({ kind: "add", name, aliases });
      nameWatchNameInputElement.value = "";
      nameWatchAliasInputElement.value = "";
      await renderNameWatch();
    })();
  });
}
