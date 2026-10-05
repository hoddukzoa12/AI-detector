import { buildEvidenceInPage } from "../evidence/page-evidence-builder.js";
import type { PageEvidencePayload, PageEvidenceResult } from "../evidence/page-evidence-builder.js";

/**
 * offscreen 증거 빌더 — 캔버스 합성·jspdf PDF 본체는 page-evidence-builder 와
 * 공유(content-script 경로와 동일 로직). 이 파일은 offscreen 메시지 수신만 담당.
 * chrome.offscreen 을 지원하는 플랫폼(Chrome)에서 service-worker 가 이 문서로
 * 빌드를 위임한다.
 */

const OFFSCREEN_BUILD_TYPE = "infocutter/offscreen-build";

chrome.runtime.onMessage.addListener((message: unknown, _sender, sendResponse) => {
  if (!message || typeof message !== "object") {
    return false;
  }

  const record = message as { target?: unknown; type?: unknown; payload?: unknown };
  if (record.target !== "offscreen" || record.type !== OFFSCREEN_BUILD_TYPE) {
    return false;
  }

  void buildEvidenceInPage(record.payload as PageEvidencePayload)
    .then((result: PageEvidenceResult) => {
      sendResponse(result);
    })
    .catch((error: unknown) => {
      sendResponse({ error: error instanceof Error ? error.message : "오프스크린 처리 실패", ok: false });
    });

  return true;
});
