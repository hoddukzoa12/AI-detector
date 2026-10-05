import { AI_RULE_CATEGORIES } from "./constants.js";
import type { AiRuleCategory } from "./ai-types.js";

export type AiBlock = {
  selector: string;
  text: string;
  imageAlt: string;
  imageSrc: string;
};

export type AiDetection = {
  selector: string;
  category: AiRuleCategory;
  reason: string;
  confidence: number;
};

export function buildAiDetectionPrompt(blocks: AiBlock[], categories: AiRuleCategory[]): string {
  const categoryLine = categories.join(", ");
  const blockLines = blocks
    .map((block) => `- selector: ${block.selector} | text: ${block.text} | imageAlt: ${block.imageAlt} | imageSrc: ${block.imageSrc}`)
    .join("\n");
  return [
    "You flag web page regions that are provocative/disturbing for a user who wants them hidden.",
    `Only consider these categories: ${categoryLine}.`,
    "Given the page blocks below (each has a CSS selector), return ONLY a JSON array.",
    'Each item: {"selector": string, "category": one of the listed categories, "reason": short string, "confidence": number 0..1}.',
    "Return an empty array [] if nothing qualifies. Use the exact selector strings provided.",
    "",
    "Blocks:",
    blockLines
  ].join("\n");
}

function coerceCategory(value: unknown): AiRuleCategory {
  return AI_RULE_CATEGORIES.includes(value as AiRuleCategory) ? (value as AiRuleCategory) : "other";
}

export function clampConfidence(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? Math.min(1, Math.max(0, value)) : 0;
}

export function parseAiDetectionResponse(text: string): AiDetection[] {
  const start = text.indexOf("[");
  const end = text.lastIndexOf("]");
  if (start < 0 || end <= start) {
    return [];
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(text.slice(start, end + 1));
  } catch {
    return [];
  }
  if (!Array.isArray(parsed)) {
    return [];
  }
  const detections: AiDetection[] = [];
  for (const entry of parsed) {
    if (!entry || typeof entry !== "object") {
      continue;
    }
    const selector: unknown = Reflect.get(entry, "selector");
    if (typeof selector !== "string" || selector.length === 0) {
      continue;
    }
    const reason: unknown = Reflect.get(entry, "reason");
    const confidence: unknown = Reflect.get(entry, "confidence");
    detections.push({
      selector,
      category: coerceCategory(Reflect.get(entry, "category")),
      reason: typeof reason === "string" ? reason : "",
      confidence: clampConfidence(confidence)
    });
  }
  return detections;
}

export async function callLiteLLM(config: { endpoint: string; apiKey: string; model: string }, prompt: string): Promise<string> {
  const response = await fetch(`${config.endpoint}/chat/completions`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${config.apiKey}`
    },
    body: JSON.stringify({
      model: config.model,
      messages: [{ role: "user", content: prompt }]
    })
  });
  if (!response.ok) {
    throw new Error(`LiteLLM 호출 실패: ${response.status}`);
  }
  const data: unknown = await response.json();
  const choices: unknown = data && typeof data === "object" ? Reflect.get(data, "choices") : null;
  const first: unknown = Array.isArray(choices) ? choices[0] : null;
  const message: unknown = first && typeof first === "object" ? Reflect.get(first, "message") : null;
  const content: unknown = message && typeof message === "object" ? Reflect.get(message, "content") : null;
  return typeof content === "string" ? content : "";
}
