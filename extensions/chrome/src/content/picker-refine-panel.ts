/* eslint-disable @typescript-eslint/no-unused-vars */
function buildPreviewPanel(
  hoverCandidates: Element[],
  hoverCandidateIndex: number,
  currentTarget: Element,
  depthChain: Element[],
  depthIndex: number,
  depthTotal: number,
  selectorCandidates: string[],
  selectorCandidateIndex: number,
  selector: string,
  defaultCardName: string,
  onSelectHoverCandidate: (nextIndex: number) => void,
  onInspectHoverCandidate: (nextIndex: number | null) => void,
  onSelectSelectorCandidate: (nextIndex: number) => void,
  onAddCard: (selector: string, cardName: string) => void,
  onNarrow: () => void,
  onNext: () => void,
  onWider: () => void,
  onCancel: () => void
): HTMLDivElement {
  const panel = createPreviewChromePanel("340px");

  const title = document.createElement("div");
  title.textContent = `미리보기 선택자 ${selectorCandidateIndex + 1}/${selectorCandidates.length}`;
  title.style.fontWeight = "700";
  title.style.marginBottom = "8px";

  const meta = document.createElement("div");
  meta.textContent = `${depthLabel(depthIndex)} · 이 selector로 숨길 범위를 확인합니다.`;
  meta.style.marginBottom = "8px";
  meta.style.color = "#f5d6b0";

  const depthMeta = document.createElement("div");
  depthMeta.textContent = `범위 ${depthIndex + 1}/${depthTotal}`;
  depthMeta.style.marginBottom = "8px";
  depthMeta.style.color = "#c9ba9c";

  const candidateSection = document.createElement("details");
  candidateSection.style.marginBottom = "10px";
  candidateSection.open = hoverCandidates.length <= 2;

  const candidateTitle = document.createElement("summary");
  candidateTitle.textContent = `포인터 후보 ${hoverCandidateIndex + 1}/${hoverCandidates.length}`;
  candidateTitle.style.fontWeight = "700";
  candidateTitle.style.marginBottom = "6px";
  candidateTitle.style.cursor = "pointer";

  const candidateGuide = document.createElement("div");
  candidateGuide.textContent = "필요할 때 펼쳐서 원하는 오브젝트를 고정하세요.";
  candidateGuide.style.marginBottom = "8px";
  candidateGuide.style.color = "#c9ba9c";
  candidateGuide.style.lineHeight = "1.45";

  const candidateList = document.createElement("div");
  candidateList.style.display = "grid";
  candidateList.style.gap = "6px";
  candidateList.style.maxHeight = "190px";
  candidateList.style.overflow = "auto";

  const candidateSections = [
    { label: "현재 타깃", match: (candidate: Element) => candidate === currentTarget },
    { label: "자식 후보", match: (candidate: Element) => currentTarget.contains(candidate) && candidate !== currentTarget },
    { label: "부모 후보", match: (candidate: Element) => candidate.contains(currentTarget) && candidate !== currentTarget },
    { label: "대체 후보", match: (candidate: Element) => candidateRelationshipLabel(candidate, currentTarget) === "대체 후보" }
  ] as const;

  const createCandidateButton = (candidateElement: Element, candidateStackIndex: number): HTMLButtonElement => {
    const candidatePreview = hoverCandidatePreview(candidateElement);
    const candidateAssessment = candidatePreview.assessment;
    const palette = selectionSessionPalette[candidateStackIndex % selectionSessionPalette.length] ?? {
      fill: "rgba(59, 130, 246, 0.10)",
      stroke: "rgba(59, 130, 246, 0.92)"
    };

    const candidateButton = document.createElement("button");
    candidateButton.type = "button";
    candidateButton.style.display = "grid";
    candidateButton.style.gridTemplateColumns = "12px 1fr";
    candidateButton.style.gap = "8px";
    candidateButton.style.alignItems = "start";
    candidateButton.style.width = "100%";
    candidateButton.style.padding = "8px";
    candidateButton.style.border = candidateStackIndex === hoverCandidateIndex
      ? `1px solid ${palette.stroke}`
      : "1px solid rgba(255,255,255,0.18)";
    candidateButton.style.background = candidateStackIndex === hoverCandidateIndex
      ? "rgba(255,255,255,0.10)"
      : "rgba(255,255,255,0.05)";
    candidateButton.style.color = "#f7f4eb";
    candidateButton.style.cursor = "pointer";
    candidateButton.style.textAlign = "left";

    const swatch = document.createElement("span");
    swatch.style.display = "block";
    swatch.style.width = "12px";
    swatch.style.height = "12px";
    swatch.style.borderRadius = "999px";
    swatch.style.marginTop = "2px";
    swatch.style.background = palette.stroke;

    const candidateCopy = document.createElement("div");
    const candidateName = document.createElement("div");
    candidateName.textContent = `${candidateStackIndex + 1}. ${candidatePreview.label}`;
    candidateName.style.fontWeight = "700";
    candidateName.style.marginBottom = "3px";

    const candidateBadgeRow = document.createElement("div");
    candidateBadgeRow.style.display = "flex";
    candidateBadgeRow.style.flexWrap = "wrap";
    candidateBadgeRow.style.gap = "4px";
    candidateBadgeRow.style.marginBottom = "4px";

    const relationshipBadge = document.createElement("span");
    relationshipBadge.textContent = candidateRelationshipLabel(candidateElement, currentTarget);
    relationshipBadge.style.padding = "1px 6px";
    relationshipBadge.style.borderRadius = "999px";
    relationshipBadge.style.background = "rgba(255,255,255,0.10)";
    relationshipBadge.style.color = "#fff7ed";

    const kindBadge = document.createElement("span");
    kindBadge.textContent = candidateKindLabel(candidateElement);
    kindBadge.style.padding = "1px 6px";
    kindBadge.style.borderRadius = "999px";
    kindBadge.style.background = "rgba(255,255,255,0.08)";
    kindBadge.style.color = "#f7f4eb";

    if (candidateStackIndex === hoverCandidateIndex) {
      const currentBadge = document.createElement("span");
      currentBadge.textContent = "사용 중";
      currentBadge.style.padding = "1px 6px";
      currentBadge.style.borderRadius = "999px";
      currentBadge.style.background = palette.stroke;
      currentBadge.style.color = "#fff";
      candidateBadgeRow.append(currentBadge);
    }

    candidateBadgeRow.append(relationshipBadge, kindBadge);

    const candidateMeta = document.createElement("div");
    candidateMeta.style.color = candidateAssessment?.tone ?? "#c9ba9c";
    candidateMeta.style.lineHeight = "1.35";
    candidateMeta.textContent = candidateAssessment
      ? `${candidateAssessment.label} · ${candidateAssessment.matches ?? 0}개`
      : "후보 상태를 확인하지 못했습니다.";

    const candidateSelector = document.createElement("code");
    candidateSelector.textContent = candidatePreview.selector ?? "선택자 없음";
    candidateSelector.style.display = "block";
    candidateSelector.style.marginTop = "4px";
    candidateSelector.style.whiteSpace = "pre-wrap";
    candidateSelector.style.wordBreak = "break-word";
    candidateSelector.style.opacity = "0.9";

    candidateCopy.append(candidateName, candidateBadgeRow, candidateMeta, candidateSelector);
    candidateButton.append(swatch, candidateCopy);
    candidateButton.addEventListener("click", () => {
      onSelectHoverCandidate(candidateStackIndex);
    });
    candidateButton.addEventListener("mouseenter", () => {
      onInspectHoverCandidate(candidateStackIndex);
    });
    candidateButton.addEventListener("mouseleave", () => {
      onInspectHoverCandidate(null);
    });
    return candidateButton;
  };

  for (const section of candidateSections) {
    const sectionCandidates = hoverCandidates
      .map((candidateElement, candidateStackIndex) => ({ candidateElement, candidateStackIndex }))
      .filter(({ candidateElement }) => section.match(candidateElement));

    if (sectionCandidates.length === 0) {
      continue;
    }

    const sectionTitle = document.createElement("div");
    sectionTitle.textContent = `${section.label} ${sectionCandidates.length}개`;
    sectionTitle.style.marginTop = "4px";
    sectionTitle.style.marginBottom = "4px";
    sectionTitle.style.fontWeight = "700";
    sectionTitle.style.color = "#f5d6b0";
    candidateList.append(sectionTitle);

    for (const { candidateElement, candidateStackIndex } of sectionCandidates) {
      candidateList.append(createCandidateButton(candidateElement, candidateStackIndex));
    }
  }

  candidateSection.append(candidateTitle, candidateGuide, candidateList);

  const breadcrumb = document.createElement("div");
  breadcrumb.style.display = "flex";
  breadcrumb.style.flexWrap = "wrap";
  breadcrumb.style.gap = "6px";
  breadcrumb.style.marginBottom = "8px";

  for (const [index, node] of depthChain.entries()) {
    const chip = document.createElement("span");
    chip.textContent = elementShortLabel(node);
    chip.style.padding = "3px 6px";
    chip.style.border = "1px solid rgba(255,255,255,0.18)";
    chip.style.background = index === depthIndex ? "rgba(217,119,6,0.24)" : "rgba(255,255,255,0.08)";
    chip.style.color = index === depthIndex ? "#fff7ed" : "#f7f4eb";
    breadcrumb.append(chip);
  }

  const qualityMeta = document.createElement("div");
  qualityMeta.style.marginBottom = "8px";
  qualityMeta.style.fontWeight = "700";

  const assistMeta = document.createElement("div");
  assistMeta.style.marginBottom = "8px";
  assistMeta.style.color = "#c9ba9c";
  assistMeta.style.lineHeight = "1.45";

  const cardNameInput = document.createElement("input");
  cardNameInput.type = "text";
  cardNameInput.value = defaultCardName;
  cardNameInput.placeholder = "카드 이름";
  cardNameInput.style.display = "block";
  cardNameInput.style.width = "100%";
  cardNameInput.style.boxSizing = "border-box";
  cardNameInput.style.padding = "10px";
  cardNameInput.style.background = "rgba(255,255,255,0.08)";
  cardNameInput.style.color = "#f7f4eb";
  cardNameInput.style.border = "1px solid rgba(255,255,255,0.18)";
  cardNameInput.style.marginBottom = "10px";
  cardNameInput.style.font = '12px "SF Mono", "IBM Plex Mono", ui-monospace, monospace';

  const input = document.createElement("textarea");
  input.value = selector;
  input.style.display = "block";
  input.style.width = "100%";
  input.style.minHeight = "84px";
  input.style.boxSizing = "border-box";
  input.style.whiteSpace = "pre-wrap";
  input.style.wordBreak = "break-word";
  input.style.padding = "10px";
  input.style.background = "rgba(255,255,255,0.08)";
  input.style.color = "#f7f4eb";
  input.style.border = "1px solid rgba(255,255,255,0.18)";
  input.style.marginBottom = "10px";
  input.style.font = '12px "SF Mono", "IBM Plex Mono", ui-monospace, monospace';

  const selectorDetails = document.createElement("details");
  selectorDetails.style.marginBottom = "10px";
  selectorDetails.open = selectorCandidates.length <= 2;

  const selectorDetailsTitle = document.createElement("summary");
  selectorDetailsTitle.textContent = `선택자 상세 ${selectorCandidateIndex + 1}/${selectorCandidates.length}`;
  selectorDetailsTitle.style.fontWeight = "700";
  selectorDetailsTitle.style.marginBottom = "6px";
  selectorDetailsTitle.style.cursor = "pointer";

  const selectorDetailsGuide = document.createElement("div");
  selectorDetailsGuide.textContent = "긴 경로 selector까지 보고 직접 고를 수 있습니다.";
  selectorDetailsGuide.style.marginBottom = "8px";
  selectorDetailsGuide.style.color = "#c9ba9c";
  selectorDetailsGuide.style.lineHeight = "1.45";

  const selectorDetailsList = document.createElement("div");
  selectorDetailsList.style.display = "grid";
  selectorDetailsList.style.gap = "6px";
  selectorDetailsList.style.maxHeight = "210px";
  selectorDetailsList.style.overflow = "auto";

  for (const [candidateIndex, candidateSelector] of selectorCandidates.entries()) {
    const candidateAssessment = selectorAssessment(candidateSelector);
    const detailButton = document.createElement("button");
    detailButton.type = "button";
    detailButton.style.display = "block";
    detailButton.style.width = "100%";
    detailButton.style.padding = "8px";
    detailButton.style.border = candidateIndex === selectorCandidateIndex
      ? "1px solid rgba(59, 130, 246, 0.95)"
      : "1px solid rgba(255,255,255,0.18)";
    detailButton.style.background = candidateIndex === selectorCandidateIndex
      ? "rgba(59, 130, 246, 0.12)"
      : "rgba(255,255,255,0.05)";
    detailButton.style.color = "#f7f4eb";
    detailButton.style.cursor = "pointer";
    detailButton.style.textAlign = "left";

    const detailMeta = document.createElement("div");
    detailMeta.textContent = candidateAssessment.matches === null
      ? `${candidateIndex + 1}. 잘못된 선택자`
      : `${candidateIndex + 1}. ${candidateAssessment.label} · ${candidateAssessment.matches}개`;
    detailMeta.style.marginBottom = "4px";
    detailMeta.style.fontWeight = "700";
    detailMeta.style.color = candidateAssessment.tone;

    const detailBadgeRow = document.createElement("div");
    detailBadgeRow.style.display = "flex";
    detailBadgeRow.style.flexWrap = "wrap";
    detailBadgeRow.style.gap = "4px";
    detailBadgeRow.style.marginBottom = "4px";

    if (candidateIndex === selectorCandidateIndex) {
      const currentBadge = document.createElement("span");
      currentBadge.textContent = "현재 사용 중";
      currentBadge.style.padding = "1px 6px";
      currentBadge.style.borderRadius = "999px";
      currentBadge.style.background = "rgba(59, 130, 246, 0.95)";
      currentBadge.style.color = "#fff";
      detailBadgeRow.append(currentBadge);
    }

    const detailCode = document.createElement("code");
    detailCode.textContent = candidateSelector;
    detailCode.style.display = "block";
    detailCode.style.whiteSpace = "pre-wrap";
    detailCode.style.wordBreak = "break-word";
    detailCode.style.opacity = "0.95";

    detailButton.append(detailMeta, detailBadgeRow, detailCode);
    detailButton.addEventListener("click", () => {
      onSelectSelectorCandidate(candidateIndex);
    });
    selectorDetailsList.append(detailButton);
  }

  selectorDetails.append(selectorDetailsTitle, selectorDetailsGuide, selectorDetailsList);

  const primaryActions = document.createElement("div");
  primaryActions.style.display = "grid";
  primaryActions.style.gridTemplateColumns = "1fr 1fr";
  primaryActions.style.gap = "8px";
  primaryActions.style.marginBottom = "8px";

  const addCardButton = document.createElement("button");
  addCardButton.type = "button";
  addCardButton.textContent = "카드에 담기";
  addCardButton.style.gridColumn = "1 / -1";

  const refreshButton = document.createElement("button");
  refreshButton.type = "button";
  refreshButton.textContent = "다시 읽기";

  const rangeActions = document.createElement("div");
  rangeActions.style.display = "grid";
  rangeActions.style.gridTemplateColumns = "1fr 1fr 1fr";
  rangeActions.style.gap = "8px";
  rangeActions.style.marginBottom = "8px";

  const narrowButton = document.createElement("button");
  narrowButton.type = "button";
  narrowButton.textContent = "대상 좁히기";
  narrowButton.disabled = depthIndex === 0;

  const nextButton = document.createElement("button");
  nextButton.type = "button";
  nextButton.textContent = selectorCandidates.length > 1 ? "다음 선택자" : "후보 없음";
  nextButton.disabled = selectorCandidates.length <= 1;

  const widerButton = document.createElement("button");
  widerButton.type = "button";
  widerButton.textContent = "대상 넓히기";
  widerButton.disabled = depthIndex >= depthTotal - 1;

  const secondaryActions = document.createElement("div");
  secondaryActions.style.display = "grid";
  secondaryActions.style.gridTemplateColumns = "1fr";
  secondaryActions.style.gap = "8px";

  const cancelButton = document.createElement("button");
  cancelButton.type = "button";
  cancelButton.textContent = "패널 닫기";

  for (const button of [addCardButton, refreshButton, narrowButton, nextButton, widerButton, cancelButton]) {
    button.style.border = "1px solid #f7f4eb";
    button.style.background = "transparent";
    button.style.color = "#f7f4eb";
    button.style.padding = "8px 10px";
    button.style.cursor = "pointer";
    button.style.whiteSpace = "nowrap";
  }

  const updatePreview = (): void => {
    const currentSelector = input.value.trim();
    const assessment = currentSelector
      ? selectorAssessment(currentSelector)
      : {
          applyAllowed: false,
          label: "선택자가 비어 있습니다",
          matches: null,
          tone: "#fca5a5"
        };

    if (!currentSelector) {
      meta.textContent = `${depthLabel(depthIndex)} · 선택자가 비어 있습니다.`;
      qualityMeta.textContent = "상태: 비어 있음";
      qualityMeta.style.color = "#fca5a5";
      assistMeta.textContent = "안내: 선택자가 비어 있어 적용할 수 없습니다.";
      addCardButton.disabled = true;
      applyPreviewSelector("__infocutter_invalid__");
      return;
    }

    if (assessment.matches === null) {
      meta.textContent = `${depthLabel(depthIndex)} · 올바르지 않은 선택자입니다.`;
      qualityMeta.textContent = `상태: ${assessment.label}`;
      qualityMeta.style.color = assessment.tone;
      assistMeta.textContent = "안내: CSS 선택자 문법을 다시 확인하세요.";
      addCardButton.disabled = true;
      applyPreviewSelector("__infocutter_invalid__");
      return;
    }

    meta.textContent = `${depthLabel(depthIndex)} · 현재 선택자는 ${assessment.matches}개 요소에 적용됩니다.`;
    qualityMeta.textContent = `상태: ${assessment.label}`;
    qualityMeta.style.color = assessment.tone;
    assistMeta.textContent = assessment.applyAllowed
      ? "안내: 지금은 숨기지 않고 오브젝트 영역만 표시합니다. 카드에 추가한 뒤, 세션 완료 버튼으로 한 번에 적용할 수 있습니다."
      : "안내: 현재 선택자는 범위가 너무 넓습니다. 더 좁게 가거나 다른 선택자로 바꾸세요.";
    addCardButton.disabled = !assessment.applyAllowed;
    applyPreviewSelector(currentSelector);
  };

  addCardButton.addEventListener("click", () => {
    onAddCard(input.value.trim(), cardNameInput.value.trim() || defaultCardName);
  });
  refreshButton.addEventListener("click", updatePreview);
  narrowButton.addEventListener("click", onNarrow);
  nextButton.addEventListener("click", onNext);
  widerButton.addEventListener("click", onWider);
  cancelButton.addEventListener("click", onCancel);
  input.addEventListener("input", updatePreview);

  primaryActions.append(addCardButton, refreshButton);
  rangeActions.append(narrowButton, nextButton, widerButton);
  secondaryActions.append(cancelButton);
  panel.append(
    title,
    meta,
    depthMeta,
    candidateSection,
    breadcrumb,
    qualityMeta,
    assistMeta,
    cardNameInput,
    input,
    selectorDetails,
    primaryActions,
    rangeActions,
    secondaryActions
  );
  document.documentElement.append(panel);
  updatePreview();
  return panel;
}

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

  const depthChain = buildDepthChain(element);
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
      /* eslint-disable @typescript-eslint/no-empty-function */
      () => {},
      () => {},
      /* eslint-enable @typescript-eslint/no-empty-function */
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
