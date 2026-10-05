/**
 * 페이지 컨텍스트(content script) 증거 빌더 — offscreen 없이 Safari 대응.
 *
 * 안2(iOS Safari): chrome.offscreen 미지원 → 기존 offscreen 파이프라인(src/offscreen) 사망.
 * service-worker 가 chrome.scripting.executeScript 로 (1) vendor/jspdf.js 주입으로
 * globalThis.jspdf 세팅, (2) 이 func 를 주입해 페이지 DOM 의 canvas/Image 로
 * 헤더+타일 합성 PNG · htmlExcerpt · PDF 를 만들어 base64 로 회수한다.
 *
 * 제약(executeScript func 직렬화): 본 함수는 외부 클로저/모듈 심볼을 참조하면
 * 런타임에 깨진다. 따라서 모든 헬퍼를 본문 안에 중첩하고, jspdf 는
 * globalThis 에서만 가져온다. 결과 타입은 offscreen 의 OffscreenBuildResult 와
 * 호환되게 유지(service-worker 가 두 경로를 투명하게 분기).
 */

export type PageEvidenceTile = {
  dataUrl: string;
  y: number;
};

export type PageEvidenceMeta = {
  url: string;
  pageTitle: string;
  capturedAt: string;
  matchedTerm: string;
  htmlExcerpt: string;
};

export type PageEvidencePayload = {
  dpr: number;
  tiles: PageEvidenceTile[];
  totalWidth: number;
  totalHeight: number;
  meta: PageEvidenceMeta;
};

export type PageEvidenceResult = {
  ok: boolean;
  error?: string;
  pngBase64?: string;
  htmlBase64?: string;
  pdfBase64?: string;
  pngSha256?: string;
  htmlSha256?: string;
};

const PAGE_MAX_PIXELS = 178956970;
const PAGE_HEADER_HEIGHT = 96;
const PAGE_DISCLAIMER =
  "본 자료는 소명 참고자료입니다. 다툼이 있는 사건에서는 공증·증거보전 신청·디지털 포렌식 등 추가 절차가 필요할 수 있습니다.";

type PageJsPdfDoc = {
  internal: { pageSize: { getWidth: () => number; getHeight: () => number } };
  addImage: (data: string, format: string, x: number, y: number, width: number, height: number) => void;
  addPage: () => void;
  setFontSize: (size: number) => void;
  text: (text: string | string[], x: number, y: number) => void;
  splitTextToSize: (text: string, size: number) => string[];
  output: (type: "arraybuffer") => ArrayBuffer;
};

type PageJsPdfNamespace = {
  jsPDF: new (options: { unit: string; format: string }) => PageJsPdfDoc;
};

/**
 * executeScript.func 로 전달되는 빌드 본체. args: [payload]. self-contained.
 */
export async function buildEvidenceInPage(payload: PageEvidencePayload): Promise<PageEvidenceResult> {
  function loadImage(dataUrl: string): Promise<HTMLImageElement> {
    return new Promise((resolve, reject) => {
      const image = new Image();
      image.onload = () => {
        resolve(image);
      };
      image.onerror = () => {
        reject(new Error("타일 이미지를 불러오지 못했습니다."));
      };
      image.src = dataUrl;
    });
  }

  async function sha256Hex(data: BufferSource): Promise<string> {
    const digest = await crypto.subtle.digest("SHA-256", data);
    return Array.from(new Uint8Array(digest))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");
  }

  function canvasToPngBlob(canvas: HTMLCanvasElement): Promise<Blob> {
    return new Promise((resolve, reject) => {
      canvas.toBlob((blob) => {
        if (blob) {
          resolve(blob);
        } else {
          reject(new Error("PNG 변환에 실패했습니다."));
        }
      }, "image/png");
    });
  }

  function blobToBase64(blob: Blob): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        const result = typeof reader.result === "string" ? reader.result : "";
        resolve(result.slice(result.indexOf(",") + 1));
      };
      reader.onerror = () => {
        reject(new Error("base64 변환에 실패했습니다."));
      };
      reader.readAsDataURL(blob);
    });
  }

  const dpr = payload.dpr > 0 ? payload.dpr : 1;
  const physicalWidth = Math.max(Math.round(payload.totalWidth * dpr), 1);
  const headerPhysical = Math.round(PAGE_HEADER_HEIGHT * dpr);
  const requestedBodyPhysical = Math.round(payload.totalHeight * dpr);
  const maxBodyPhysical = Math.floor(PAGE_MAX_PIXELS / physicalWidth);

  if (requestedBodyPhysical > maxBodyPhysical) {
    return { error: "페이지가 너무 커 전체 캡처에 실패했습니다.", ok: false };
  }

  const canvas = document.createElement("canvas");
  canvas.width = physicalWidth;
  canvas.height = requestedBodyPhysical + headerPhysical;
  const context = canvas.getContext("2d");
  if (!context) {
    return { error: "캔버스 컨텍스트를 만들 수 없습니다.", ok: false };
  }

  context.fillStyle = "#1d1d1d";
  context.fillRect(0, 0, canvas.width, headerPhysical);
  context.fillStyle = "#f7f4eb";
  context.font = `${Math.round(16 * dpr)}px sans-serif`;
  context.fillText(`URL: ${payload.meta.url}`, 12 * dpr, 26 * dpr);
  context.fillText(`제목: ${payload.meta.pageTitle}`, 12 * dpr, 50 * dpr);
  context.fillText(
    `캡처시각: ${payload.meta.capturedAt}   감시이름: ${payload.meta.matchedTerm}`,
    12 * dpr,
    74 * dpr
  );

  for (const tile of payload.tiles) {
    const image = await loadImage(tile.dataUrl);
    context.drawImage(image, 0, headerPhysical + Math.round(tile.y * dpr));
  }

  const pngBlob = await canvasToPngBlob(canvas);
  const pngBuffer = await pngBlob.arrayBuffer();
  const pngSha256 = await sha256Hex(pngBuffer);
  const pngBase64 = await blobToBase64(pngBlob);

  const htmlBytes = new TextEncoder().encode(payload.meta.htmlExcerpt);
  const htmlSha256 = await sha256Hex(htmlBytes);
  const htmlBase64 = await blobToBase64(new Blob([payload.meta.htmlExcerpt], { type: "text/html" }));

  const namespace = (globalThis as unknown as { jspdf?: PageJsPdfNamespace }).jspdf;
  if (!namespace?.jsPDF) {
    return { error: "jspdf 가 주입되지 않았습니다.", ok: false };
  }
  const doc = new namespace.jsPDF({ format: "a4", unit: "pt" });
  const pageWidth = doc.internal.pageSize.getWidth();
  const imageHeight = (canvas.height / canvas.width) * pageWidth;
  doc.addImage(`data:image/png;base64,${pngBase64}`, "PNG", 0, 0, pageWidth, imageHeight);

  doc.addPage();
  doc.setFontSize(12);
  const lines = [
    "인포커터 증거 메타데이터",
    "",
    `URL: ${payload.meta.url}`,
    `제목: ${payload.meta.pageTitle}`,
    `캡처시각: ${payload.meta.capturedAt}`,
    `감시이름: ${payload.meta.matchedTerm}`,
    "",
    `스크린샷 SHA-256: ${pngSha256}`,
    `HTML SHA-256: ${htmlSha256}`,
    "",
    PAGE_DISCLAIMER
  ];
  const wrapped = doc.splitTextToSize(lines.join("\n"), pageWidth - 48);
  doc.text(wrapped, 24, 48);

  const pdfBuffer = doc.output("arraybuffer");
  const pdfBase64 = await blobToBase64(new Blob([pdfBuffer], { type: "application/pdf" }));

  return { htmlBase64, htmlSha256, ok: true, pdfBase64, pngBase64, pngSha256 };
}
