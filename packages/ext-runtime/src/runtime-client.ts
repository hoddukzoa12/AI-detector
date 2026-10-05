export type RuntimeEnvelope = {
  ok: boolean;
  data?: unknown;
  error?: string;
};

export function isRuntimeEnvelope(response: unknown): response is RuntimeEnvelope {
  return response !== null && typeof response === "object" && "ok" in response;
}

/** True when the extension context is still alive (survives SW/context invalidation). */
export function isExtensionContextValid(): boolean {
  const runtime = chrome.runtime as typeof chrome.runtime | undefined;
  return runtime?.id !== undefined;
}

/**
 * Generic typed request/response bus over chrome.runtime.sendMessage.
 * Per-extension code binds Req/Res to its own message union
 * (e.g. `sendRuntimeMessage<AnyRequest, ResponseOf<R>>`).
 */
export async function sendRuntimeMessage<Res>(
  request: unknown,
  fallbackError = "background error"
): Promise<Res> {
  if (!isExtensionContextValid()) {
    throw new Error("extension context invalidated");
  }
  const response: unknown = await chrome.runtime.sendMessage(request);
  if (!isRuntimeEnvelope(response)) {
    throw new Error("invalid response from background");
  }
  if (!response.ok) {
    throw new Error(response.error ?? fallbackError);
  }
  return response.data as Res;
}
