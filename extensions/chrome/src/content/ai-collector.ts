/* eslint-disable @typescript-eslint/no-unused-vars */

function isAiCollectableElement(element: Element): boolean {
  if (typeof element.id === "string" && element.id.startsWith("infocutter-")) {
    return false;
  }
  if (element.closest("input, textarea, select, [type='password'], [contenteditable='true']")) {
    return false;
  }
  return true;
}

function collectAiBlocks(): AiBlockRecord[] {
  const blocks: AiBlockRecord[] = [];
  const candidates = document.querySelectorAll("section, article, li, figure, aside, img, video");
  for (const element of candidates) {
    if (blocks.length >= AI_COLLECT_MAX_BLOCKS) {
      break;
    }
    if (!isAiCollectableElement(element)) {
      continue;
    }
    const text = element.textContent.replace(/\s+/g, " ").trim().slice(0, AI_COLLECT_MAX_TEXT_LENGTH);
    const image = element instanceof HTMLImageElement ? element : element.querySelector("img");
    const imageAlt = image instanceof HTMLImageElement ? image.alt : "";
    const imageSrc = image instanceof HTMLElement ? image.getAttribute("src") ?? "" : "";
    if (text.length === 0 && imageSrc.length === 0) {
      continue;
    }
    blocks.push({ selector: buildSelector(element), text, imageAlt, imageSrc });
  }
  return blocks;
}
