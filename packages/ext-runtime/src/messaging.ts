import { type RuntimeEnvelope } from "./runtime-client.js";

export type TypedMessage = { type: string; payload?: unknown };

export type MessageHandler<Req extends TypedMessage = TypedMessage> = (
  request: Req,
  sender: chrome.runtime.MessageSender
) => unknown;

/**
 * Generic background messaging bus. Register per-type handlers and mount once;
 * responses are wrapped in the { ok, data, error } envelope that
 * sendRuntimeMessage() unwraps. Keeps the async sendResponse plumbing in one place.
 */
export function createMessageBus() {
  const handlers = new Map<string, MessageHandler>();

  function on<Req extends TypedMessage>(type: Req["type"], handler: MessageHandler<Req>): void {
    handlers.set(type, handler as MessageHandler);
  }

  function dispatch(
    request: unknown,
    sender: chrome.runtime.MessageSender,
    sendResponse: (response: RuntimeEnvelope) => void
  ): boolean {
    if (request === null || typeof request !== "object" || !("type" in request)) {
      return false;
    }
    const message = request as TypedMessage;
    const handler = handlers.get(message.type);
    if (!handler) {
      return false;
    }

    Promise.resolve()
      .then(() => handler(message, sender))
      .then((data) => {
        sendResponse({ ok: true, data });
      })
      .catch((error: unknown) => {
        sendResponse({ ok: false, error: error instanceof Error ? error.message : String(error) });
      });

    return true;
  }

  function mount(): void {
    chrome.runtime.onMessage.addListener(dispatch);
  }

  return { on, dispatch, mount };
}
