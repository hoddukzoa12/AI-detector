/* eslint-disable @typescript-eslint/no-unused-vars */

/*
 * Picker controller: wires DOM events to the picker modules
 * (picker-session, picker-overlay, picker-analysis, picker-refine-panel,
 * picker-session-panel, picker-iframe) and holds the per-session controller state.
 */
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

async function hideTargetElement(target: Element): Promise<string> {
  const selector = buildSelector(target);
  await addSiteRule(ownerPageUrl(), selector, currentFrameScope(), {
    cardId: generateId(),
    cardName: "기본 카드"
  });
  await renderAllRules();
  return selector;
}
