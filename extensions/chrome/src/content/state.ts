/* eslint-disable @typescript-eslint/no-unused-vars, prefer-const */

const infocutterGlobal = globalThis as typeof globalThis & {
  __INFOCUTTER_CONTENT_LOADED__?: boolean;
};

let pickerStop: (() => void) | null = null;
let lastContextTarget: Element | null = null;
let textBlockRenderTimer: number | null = null;
let textBlockObserver: MutationObserver | null = null;
let textBlockRuntimeIdCounter = 0;
let selectionSession: PickerSessionEntry[] = [];

const selectionSessionPalette: SessionPaletteEntry[] = [
  { fill: "rgba(34, 197, 94, 0.10)", stroke: "rgba(34, 197, 94, 0.92)" },
  { fill: "rgba(59, 130, 246, 0.10)", stroke: "rgba(59, 130, 246, 0.92)" },
  { fill: "rgba(249, 115, 22, 0.10)", stroke: "rgba(249, 115, 22, 0.92)" },
  { fill: "rgba(168, 85, 247, 0.10)", stroke: "rgba(168, 85, 247, 0.92)" },
  { fill: "rgba(236, 72, 153, 0.10)", stroke: "rgba(236, 72, 153, 0.92)" }
];

const textBlockRuntimeIds = new WeakMap<Element, string>();

function generateId(): string {
  return InfocutterSelectorRules.generateSelectorRuleId();
}
