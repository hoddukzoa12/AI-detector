/* eslint-disable @typescript-eslint/no-unused-vars */

function buildHoverSummary(element: Element): HoverSummaryResult {
  const selector = buildSelectorCandidates(element)[0] ?? null;
  if (selector) {
    const assessment = selectorAssessment(selector);
    if (assessment.matches !== null) {
      const selectionLabel = assessment.matches === 1
        ? "현재 요소 하나를 기준으로 선택합니다."
        : `같은 성격의 요소 ${assessment.matches}개가 함께 선택될 수 있습니다.`;
      return {
        assessment,
        label: `인포커터 선택 모드: ${currentFrameLabel()} / ${selectionLabel} 상태: ${assessment.label}`,
        selector
      };
    }
  }

  return {
    assessment: null,
    label: `인포커터 선택 모드: ${currentFrameLabel()} / 범위가 넓을 수 있어 클릭 후 미리보기에서 다시 조정하세요.`,
    selector: null
  };
}

function isExtensionUiElement(element: Element): boolean {
  const id = element.getAttribute("id");
  return typeof id === "string" && id.startsWith("infocutter-");
}

function candidateTargetScore(element: Element, stackIndex: number): number {
  const selector = buildSelectorCandidates(element)[0] ?? buildSelector(element);
  const assessment = selectorAssessment(selector);
  const rect = element.getBoundingClientRect();
  const viewportArea = Math.max(1, window.innerWidth * window.innerHeight);
  const rectArea = rect.width * rect.height;
  const areaRatio = rectArea / viewportArea;
  const areaScore = Math.min(rectArea / 500, 16);
  const stackBonus = Math.max(0, 28 - stackIndex * 6);
  const applyBonus = assessment.applyAllowed ? 50 : 0;
  const matchPenalty = assessment.matches === null ? 20 : Math.min(assessment.matches, 20);
  const interactiveBonus = element.closest("button, a, input, textarea, select, option, label, [role='button'], [role='link']")
    ? 22
    : 0;
  const tinyPenalty = rect.width < 24 || rect.height < 18 ? 8 : 0;
  const containerPenalty =
    areaRatio > 0.45
      ? 80
      : areaRatio > 0.25
        ? 36
        : areaRatio > 0.12
          ? 14
          : 0;
  const oversizedBlockPenalty =
    rect.width >= window.innerWidth * 0.8 && rect.height >= window.innerHeight * 0.22
      ? 24
      : 0;

  return (
    applyBonus +
    selectorSpecificityScore(selector) +
    areaScore +
    stackBonus +
    interactiveBonus -
    matchPenalty -
    tinyPenalty -
    containerPenalty -
    oversizedBlockPenalty
  );
}

function buildDepthChain(element: Element, maxDepth = 4): Element[] {
  const chain: Element[] = [element];
  let current = element.parentElement;
  let depth = 0;

  while (current && current !== document.documentElement && depth < maxDepth) {
    chain.push(current);
    current = current.parentElement;
    depth += 1;
  }

  return chain;
}

function depthLabel(depthIndex: number): string {
  if (depthIndex === 0) {
    return "현재 요소";
  }

  return `부모 ${depthIndex}단계`;
}

function elementShortLabel(element: Element): string {
  const id = element.getAttribute("id");
  if (id) {
    return `${element.localName}#${id}`;
  }

  const firstClass = Array.from(element.classList).find((className) => maybeStableClassName(className));
  if (firstClass) {
    return `${element.localName}.${firstClass}`;
  }

  return element.localName;
}

function hoverCandidatePreview(element: Element): HoverCandidatePreview {
  const selector = buildSelectorCandidates(element)[0] ?? null;
  if (!selector) {
    return {
      applyAllowed: false,
      assessment: null,
      label: elementShortLabel(element),
      matches: 0,
      selector: null
    };
  }

  const assessment = selectorAssessment(selector);
  return {
    applyAllowed: assessment.applyAllowed,
    assessment: assessment.matches === null ? null : assessment,
    label: elementShortLabel(element),
    matches: assessment.matches ?? 0,
    selector
  };
}

function candidateRelationshipLabel(candidate: Element, currentTarget: Element): string {
  if (candidate === currentTarget) {
    return "현재 타깃";
  }

  if (candidate.contains(currentTarget)) {
    return "부모 후보";
  }

  if (currentTarget.contains(candidate)) {
    return "자식 후보";
  }

  return "대체 후보";
}

function candidateKindLabel(element: Element): string {
  if (element.matches("button, [role='button']")) {
    return "버튼";
  }
  if (element.matches("a, [role='link']")) {
    return "링크";
  }
  if (element.matches("input, textarea, select, option")) {
    return "입력";
  }
  if (element.matches("img, picture, svg")) {
    return "미디어";
  }
  if (element.children.length === 0) {
    return "리프";
  }
  return "컨테이너";
}
