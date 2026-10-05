/**
 * 증거 PDF 빌더 — offscreen 없이 content script 컨텍스트에서 jsPDF 로 PDF 생성.
 *
 * 안2(iOS Safari) 대응: chrome.offscreen 은 Safari 전 플랫폼 미지원이라
 * 기존 offscreen 파이프라인(service-worker L454)이 사망. 이 모듈은 content script 에서
 * 직접 jsPDF 인스턴스를 받아 메타 + 본문 텍스트 → PDF base64 를 만든다.
 *
 * 프로토타입 범위:
 * - 캡처(이미지 타일)는 미포함 → content script 캡처 실측(issue #12 note_27561 A안) 후 채운다.
 * - 통합(service-worker 분기·jspdf 주입)은 별도 단계.
 *
 * jsPDF 실제 인스턴스와 호환되는 최소 인터페이스만 의존(결합도↓·테스트 용이).
 */

export type EvidenceMeta = {
  url: string;
  pageTitle: string;
  capturedAt: string;
  matchedTerm?: string;
  hash?: string;
}

export type JsPdfLike = {
  internal: { pageSize: { getWidth(): number; getHeight(): number } };
  setFontSize(size: number): unknown;
  text(input: string, x: number, y: number, opts?: { maxWidth?: number }): unknown;
  splitTextToSize(text: string, maxWidth: number): string[];
  addPage(): unknown;
  output(kind: "datauristring"): string;
}

const MARGIN = 40;
const LINE_HEIGHT = 13;

export function buildEvidencePdf(meta: EvidenceMeta, bodyText: string, doc: JsPdfLike): string {
  const pageWidth = doc.internal.pageSize.getWidth();
  const pageHeight = doc.internal.pageSize.getHeight();
  const contentWidth = pageWidth - MARGIN * 2;
  let y = MARGIN + 8;

  doc.setFontSize(14);
  y = writeWrapped(doc, meta.pageTitle || meta.url, MARGIN, y, contentWidth, 24);

  doc.setFontSize(9);
  y = writeWrapped(doc, meta.url, MARGIN, y, contentWidth, 16);
  if (meta.matchedTerm) {
    y = writeLine(doc, `matched: ${meta.matchedTerm}`, MARGIN, y, pageHeight);
  }
  y = writeLine(doc, `captured: ${meta.capturedAt}`, MARGIN, y, pageHeight);
  if (meta.hash) {
    y = writeLine(doc, `sha256: ${meta.hash}`, MARGIN, y, pageHeight);
  }

  y += 10;
  doc.setFontSize(10);
  for (const line of doc.splitTextToSize(bodyText, contentWidth)) {
    y = writeLine(doc, line, MARGIN, y, pageHeight);
  }

  const dataUri = doc.output("datauristring");
  const comma = dataUri.indexOf(",");
  return comma >= 0 ? dataUri.slice(comma + 1) : dataUri;
}

function writeWrapped(
  doc: JsPdfLike,
  text: string,
  x: number,
  y: number,
  maxWidth: number,
  gapAfter: number
): number {
  for (const line of doc.splitTextToSize(text, maxWidth)) {
    doc.text(line, x, y, { maxWidth });
    y += LINE_HEIGHT;
  }
  return y + gapAfter - LINE_HEIGHT;
}

function writeLine(
  doc: JsPdfLike,
  text: string,
  x: number,
  y: number,
  pageHeight: number
): number {
  if (y > pageHeight - MARGIN) {
    doc.addPage();
    y = MARGIN + 8;
  }
  doc.text(text, x, y);
  return y + LINE_HEIGHT;
}
