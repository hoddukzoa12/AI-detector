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
