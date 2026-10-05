import type { AiRuleCategory } from "../shared/ai-types.js";

export const AI_CATEGORY_LABELS: Record<AiRuleCategory, string> = {
  violence: "폭력",
  sexual: "선정성",
  gore: "잔혹/고어",
  hate: "혐오 발언",
  shock: "충격/혐오감",
  other: "기타"
};
