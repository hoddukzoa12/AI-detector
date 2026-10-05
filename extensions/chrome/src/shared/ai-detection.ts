import { AI_CONFIDENCE_THRESHOLD } from "./constants.js";
import { replaceAiSiteRules } from "./ai-rule-storage.js";
import type { AiBlock, AiDetection } from "./ai-llm-client.js";
import type { AiRuleCategory } from "./ai-types.js";

export function filterDetections(
  detections: AiDetection[],
  enabledCategories: AiRuleCategory[],
  threshold: number
): AiDetection[] {
  return detections.filter((detection) => (
    enabledCategories.includes(detection.category) && detection.confidence >= threshold
  ));
}

export async function runAiDetection(
  matchers: string[],
  blocks: AiBlock[],
  enabledCategories: AiRuleCategory[],
  model: string,
  detect: (blocks: AiBlock[]) => Promise<AiDetection[]>
): Promise<number> {
  const detections = await detect(blocks);
  const kept = filterDetections(detections, enabledCategories, AI_CONFIDENCE_THRESHOLD);
  if (kept.length === 0) {
    return 0;
  }
  await replaceAiSiteRules(
    matchers,
    kept.map((detection) => ({
      selector: detection.selector,
      category: detection.category,
      reason: detection.reason,
      confidence: detection.confidence
    })),
    model
  );
  return kept.length;
}
