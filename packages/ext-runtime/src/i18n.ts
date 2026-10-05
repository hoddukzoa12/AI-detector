export function t(key: string, fallback: string): string {
  try {
    const g = globalThis as { chrome?: { i18n?: { getMessage?: (k: string) => string } } };
    const msg = g.chrome?.i18n?.getMessage?.(key);
    if (typeof msg === "string" && msg !== "") return msg;
  } catch {
    /* fall through */
  }
  return fallback;
}
