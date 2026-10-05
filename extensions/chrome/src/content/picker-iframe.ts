/* eslint-disable @typescript-eslint/no-unused-vars */

function buildIframePanel(
  iframeElement: HTMLIFrameElement,
  onHideFrame: () => void,
  onEnterFrame: () => void,
  onCancel: () => void
): HTMLDivElement {
  const panel = createPreviewChromePanel("320px");

  const title = document.createElement("div");
  title.textContent = "iframe 감지됨";
  title.style.fontWeight = "700";
  title.style.marginBottom = "8px";

  const meta = document.createElement("div");
  const frameHint = iframeElement.getAttribute("src") ?? iframeElement.getAttribute("title") ?? "내부 프레임";
  meta.textContent = `이 요소는 iframe 입니다: ${frameHint}`;
  meta.style.marginBottom = "8px";
  meta.style.color = "#f5d6b0";
  meta.style.whiteSpace = "pre-wrap";
  meta.style.wordBreak = "break-word";

  const guide = document.createElement("div");
  const accessMode = iframeAccessMode(iframeElement);
  if (accessMode === "cross-origin") {
    guide.textContent = "이 iframe은 다른 출처일 가능성이 있어 내부 선택이 제한될 수 있습니다. 안으로 들어가지 못하면 프레임 자체 숨기기를 사용하세요.";
  } else {
    guide.textContent = "프레임 자체를 숨기거나, 프레임 안으로 들어가서 내부 요소를 다시 선택할 수 있습니다.";
  }
  guide.style.marginBottom = "10px";
  guide.style.lineHeight = "1.45";

  const actions = document.createElement("div");
  actions.style.display = "flex";
  actions.style.gap = "8px";

  const hideButton = document.createElement("button");
  hideButton.type = "button";
  hideButton.textContent = "프레임 숨기기";
  hideButton.style.flex = "1";

  const enterButton = document.createElement("button");
  enterButton.type = "button";
  enterButton.textContent = "프레임 안 선택";
  enterButton.style.flex = "1";
  if (accessMode === "cross-origin") {
    enterButton.textContent = "프레임 안 선택 시도";
  }

  const cancelButton = document.createElement("button");
  cancelButton.type = "button";
  cancelButton.textContent = "취소";
  cancelButton.style.flex = "1";

  for (const button of [hideButton, enterButton, cancelButton]) {
    button.style.border = "1px solid #f7f4eb";
    button.style.background = "transparent";
    button.style.color = "#f7f4eb";
    button.style.padding = "8px 10px";
    button.style.cursor = "pointer";
  }

  hideButton.addEventListener("click", onHideFrame);
  enterButton.addEventListener("click", onEnterFrame);
  cancelButton.addEventListener("click", onCancel);

  actions.append(hideButton, enterButton, cancelButton);
  panel.append(title, meta, guide, actions);
  document.documentElement.append(panel);
  return panel;
}

async function startPickerInIframe(iframeElement: HTMLIFrameElement): Promise<boolean> {
  if (!iframeElement.contentWindow) {
    return false;
  }

  const requestId = generateId();

  return new Promise((resolve) => {
    const timeoutId = window.setTimeout(() => {
      window.removeEventListener("message", handleAck);
      resolve(false);
    }, 1200);

    const handleAck = (event: MessageEvent): void => {
      const message = parseFrameMessage(event);
      if (!message) {
        return;
      }

      const { source, type } = message;
      const ackRequestId = message.requestId;

      if (source === "infocutter" && type === PICKER_FRAME_ACK_TYPE && ackRequestId === requestId) {
        window.clearTimeout(timeoutId);
        window.removeEventListener("message", handleAck);
        resolve(true);
      }
    };

    window.addEventListener("message", handleAck);
    iframeElement.contentWindow?.postMessage(
      {
        requestId,
        source: "infocutter",
        type: PICKER_FRAME_MESSAGE_TYPE
      },
      "*"
    );
  });
}
