import type { AiAnalysis, FindingsResponse, OfficialFinding } from '../core/types.js';
import type { ExtraFinding, ExtraFindingsResponse, OcrFile, OcrImageOccurrence, FindingDetailV2 as FindingDetail, FindingDetailsFileV2 as FindingDetailsFile, PublicConfigV2 as PublicConfig, ReviewCandidateV2 as ReviewCandidate, ReviewFileV2 as ReviewFile, RunSnapshotV2 as RunSnapshot, ScanStatusFileV2 as ScanStatusFile } from '../core/v2.js';

export interface BootstrapOptions {
  /** A local server session token, never the AI provider key. */
  sessionToken: string;
  config?: PublicConfig;
  pollIntervalMs?: number;
}
/** Session API projection; persisted V2 evidence/file DTOs remain unchanged. */
interface RelatedLinksResponse { runId: string; candidates: { candidateId: string; links: string[] }[] }
export interface Dashboard { ready: Promise<void>; dispose(): void }
const stateLabels = { idle: '대기', running: '점검 중', stopping: '중지 중', completed: '완료', partial: '부분 완료', cancelled: '중지됨', failed: '실패' };
const files = ['result.json', 'result_extra.json', 'scan-status.json', 'review.json', 'finding-details.json', 'ocr.json'] as const;
const countLabels = { discoveredPages: '발견 페이지', scannedPages: '점검 페이지', failedPages: '실패 페이지', skippedPages: '제외 페이지', pendingPages: '대기 페이지', confirmedFindings: '공식 탐지', extraConfirmedFindings: '추가 이미지 탐지', reviewCandidates: '검토 후보' };
function element<K extends keyof HTMLElementTagNameMap>(tag: K, text?: string, className?: string): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag); if (text !== undefined) node.textContent = text; if (className) node.className = className; return node;
}
function button(text: string, onClick: () => void): HTMLButtonElement {
  const node = element('button', text); node.type = 'button'; node.addEventListener('click', onClick); return node;
}
function safeLink(url: string): HTMLElement {
  try {
    const parsed = new URL(url);
    if ((parsed.protocol === 'http:' || parsed.protocol === 'https:') && !parsed.username && !parsed.password) {
      const a = element('a', url); a.href = parsed.href; a.target = '_blank'; a.rel = 'noopener noreferrer'; a.title = '현재 페이지 다시 열기 (캡처 시점의 근거가 아닙니다)'; return a;
    }
  } catch { /* Invalid captured URL remains plain text. */ }
  return element('span', url);
}
function pre(text: string): HTMLPreElement { const node = element('pre', text, 'raw'); node.tabIndex = 0; node.setAttribute('aria-label', '원문 또는 캡처 JSON'); return node; }
function section(title: string): { section: HTMLElement; body: HTMLDivElement } {
  const section = element('section', undefined, 'panel'); const heading = element('h2', title); const body = element('div'); section.append(heading, body); return { section, body };
}
function analysis(ai: AiAnalysis | null): HTMLElement {
  const node = element('div', undefined, 'analysis');
  if (!ai) { node.append(element('p', 'CLEF 미판정 · 검토/미처리 이유를 확인하세요')); return node; }
  node.append(element('p', `CLEF 분류: ${ai.choice ?? '미판정'} · CLEF 신뢰도: ${ai.confidence === null ? '없음' : ai.confidence} · 모델: ${ai.model}`));
  if (ai.probabilities) node.append(element('p', `확률: ${Object.entries(ai.probabilities).map(([key, value]) => `${key} ${value}`).join(' · ')}`));
  node.append(element('p', `대표 청크: ${ai.summaryChunkId ?? '없음'}`));
  const chunks = element('ul');
  for (const chunk of ai.chunks) chunks.append(element('li', `${chunk.chunkId} · UTF-16 [${chunk.rawStart}, ${chunk.rawEnd}) · ${chunk.status} · ${chunk.choice ?? '미판정'}${chunk.reasonCode ? ` · ${chunk.reasonCode}` : ''}${chunk.probabilities ? ` · 확률 ${JSON.stringify(chunk.probabilities)}` : ''}`));
  node.append(chunks); return node;
}

/** Mount a dashboard. dispose aborts requests, releases downloads and removes all timers. */
export function bootstrap(root: HTMLElement, options: BootstrapOptions): Dashboard {
  let config: PublicConfig | null = options.config ?? null;
  let run: RunSnapshot | null = null;
  let found: OfficialFinding[] = [];
  let extraFound: ExtraFinding[] = [];
  let images: OcrImageOccurrence[] = [];
  let savedStatus: ScanStatusFile | null = null;
  let relatedLinks: RelatedLinksResponse['candidates'] = [];
  let details: FindingDetail[] = [];
  let reviews: ReviewCandidate[] = [];
  let scope: ScanStatusFile['scope'] | null = null;
  let resultSignature = '';
  let reviewSignature = '';
  let disposed = false;
  let busy = false;
  let cancelling = false;
  let acceptArtifacts = true;
  let generation = 0;
  let artifactRequest = 0;
  let errorsInRow = 0;
  let pollTimer: ReturnType<typeof setTimeout> | null = null;
  const controllers = new Set<AbortController>();
  const blobUrls = new Set<string>();
  const revokeTimers = new Set<ReturnType<typeof setTimeout>>();
  const pollInterval = Math.min(10000, Math.max(250, options.pollIntervalMs ?? 1000));
  let activeDialog: HTMLDialogElement | null = null;
  let dialogVersion = 0;
  let previewUrl: string | null = null;
  let dialogTrigger: HTMLElement | null = null;

  root.replaceChildren(); root.className = 'inspector';
  const header = element('header', undefined, 'hero'); header.append(element('p', 'PUBLIC SITE INSPECTOR', 'eyebrow'), element('h1', '공개 웹사이트 광고 점검'), element('p', '공개 페이지와 포함 프레임을 읽고, 원문 근거와 점검 범위를 함께 기록합니다.'));
  const form = element('form', undefined, 'panel input-panel');
  const urlLabel = element('label', '진입 URL'); const urlInput = element('input'); urlInput.id = 'entry-url'; urlInput.type = 'url'; urlInput.required = true; urlInput.placeholder = 'https://www.example.go.kr/'; urlInput.setAttribute('autocomplete', 'url'); urlLabel.htmlFor = urlInput.id;
  const consentLabel = element('label', undefined, 'checkbox'); const consentInput = element('input'); consentInput.type = 'checkbox'; consentInput.id = 'external-consent'; consentInput.setAttribute('aria-label', '외부 분석 전송 동의'); consentLabel.append(consentInput, element('span', '외부 분석 전송 동의 · 후보 원문/정규화 텍스트와 소유 관계가 확인된 관련 링크를 OpenRouter CLEF로 전송합니다.'));
  const ocrLabel = element('label', undefined, 'checkbox'); const ocrInput = element('input'); ocrInput.type = 'checkbox'; ocrInput.id = 'ocr-enabled'; ocrInput.setAttribute('aria-label', '이미지 OCR 사용'); ocrLabel.append(ocrInput, element('span', '이미지 OCR 사용 · 포함 이미지의 정적 PNG 분석 프레임을 OpenRouter OCR 모델로 전송하는 데 동의합니다.'));
  const aiHint = element('p', 'CLEF 필수 · 키 설정 확인 중', 'hint');
  const limitsHint = element('p', undefined, 'hint');
  const frameHint = element('p', '이미지는 첫 프레임 하나만 분석합니다. 캔버스·영상·나머지 애니메이션 프레임·CSS 그리기·아직 나타나지 않은 지연 이미지는 범위 밖입니다.', 'hint');
  consentInput.addEventListener('change', renderControls);
  const controls = element('div', undefined, 'controls');
  const startButton = element('button', '점검 시작', 'primary'); startButton.type = 'submit'; startButton.dataset.action = 'start'; startButton.disabled = true;
  const stopButton = button('점검 중지', () => { void cancel(); }); stopButton.disabled = true;
  controls.append(startButton, stopButton); form.append(urlLabel, urlInput, aiHint, consentLabel, ocrLabel, limitsHint, frameHint, controls);
  const alert = element('div', undefined, 'alert'); alert.setAttribute('role', 'alert'); alert.hidden = true;
  const status = section('점검 현황'); status.body.setAttribute('aria-live', 'polite'); status.body.setAttribute('aria-atomic', 'true');
  const results = section('공식 네 유형 · 직접 DOM 텍스트');
  const extraResults = section('추가 이미지 탐지 · OCR 추출');
  const imagePanel = section('이미지 읽기 상태 및 미처리 범위');
  const reviewPanel = section('검토 후보');
  const scopes = section('미완료·제외 범위 및 오류');
  const exports = section('결과 파일');
  root.append(header, form, alert, status.section, results.section, extraResults.section, imagePanel.section, reviewPanel.section, scopes.section, exports.section);
  form.addEventListener('submit', event => { event.preventDefault(); void start(); });

  function showError(error: unknown): void {
    if (disposed) return;
    alert.textContent = error instanceof Error ? error.message : String(error); alert.hidden = false;
  }
  function clearError(): void { alert.hidden = true; alert.textContent = ''; }
  function active(): boolean { return run?.state === 'running' || run?.state === 'stopping'; }
  function validRun(id: string, version: number): boolean { return !disposed && run?.runId === id && generation === version; }
  function clearTimer(): void { if (pollTimer !== null) clearTimeout(pollTimer); pollTimer = null; }
  function renderControls(): void {
    startButton.disabled = !config?.aiConfigured || !consentInput.checked || busy || active(); urlInput.disabled = busy || active();
    consentInput.disabled = busy || active(); ocrInput.disabled = busy || active(); stopButton.disabled = busy || cancelling || run?.state !== 'running';
    aiHint.textContent = `CLEF 필수 · OpenRouter cloudflare/clef · ${config ? config.aiConfigured ? '키 설정됨' : '키 미설정 · 서버에 OPENROUTER_API_KEY를 설정하고 재시작하세요.' : '키 설정 확인 중'}`;
    limitsHint.textContent = config ? `처리 한도: OCR 최대 ${config.limits.maxOcrRequests}요청 · CLEF 최대 ${config.limits.maxClefRequests}요청 (재시도 포함). 이미지 바이트 ${config.limits.maxImageBytes} · 픽셀 ${config.limits.maxImagePixels}. 요청 한도는 달러 비용 보장이 아닙니다.` : '처리 한도 확인 중';
  }
  function renderStatus(): void {
    status.body.replaceChildren(); const badge = element('span', stateLabels[run?.state ?? 'idle'], `badge ${run?.state ?? 'idle'}`); status.body.append(badge);
    if (!run) { status.body.append(element('p', 'URL을 입력하고 점검을 시작하세요.')); return; }
    status.body.append(element('p', `실행 ID: ${run.runId}`, 'mono'), element('p', `진입 URL: ${run.entryUrl}`), element('p', `${run.elapsedSec}초`, 'elapsed'), element('p', `시작: ${run.startedAt} · 종료: ${run.finishedAt ?? '진행 중'}`), element('p', `CLEF 필수: ${run.model} · 이미지 범위: ${run.ocrEnabled ? 'OCR 선택 · ' + run.ocrModel : '선택 제외 (검사하지 않음)'}`));
    const counts = element('dl', undefined, 'counts');
    for (const [key, label] of Object.entries(countLabels)) { const value = run.counts[key as keyof typeof run.counts]; const cell = element('div'); cell.append(element('dt', label), element('dd', String(value))); counts.append(cell); }
    status.body.append(element('p', `이미지 발생 ${run.imageCounts.discovered} · 원본 확보 ${run.imageCounts.captured} · OCR 응답 완료 ${run.imageCounts.ocrCompleted} · 실패 ${run.imageCounts.failed} · 미처리 ${run.imageCounts.pending} · 선택 제외/미지원 ${run.imageCounts.skipped}`), element('p', `실제 요청: OCR ${run.requestCounts.ocr} · CLEF ${run.requestCounts.clef}`), counts, element('h3', '현재 점검 URL')); const urls = element('ul'); for (const url of run.activeUrls) urls.append(element('li', url)); status.body.append(urls); if (!run.activeUrls.length) status.body.append(element('p', '진행 중인 페이지 없음', 'hint'));
  }
  function evidenceButton(id: string | undefined): HTMLElement {
    return id ? button(`캡처 근거 보기 ${id}`, () => { void showEvidence(id); }) : element('span', '등록된 캡처 근거 없음');
  }
  function imageButtons(ids: string[]): HTMLElement {
    const group = element('div');
    for (const id of ids) if (images.some(item => item.imageId === id)) group.append(button(`이미지 상세 ${id}`, () => { void showImage(id); }));
    return group;
  }
  function candidateLinks(id: string): HTMLElement {
    const node = element('div'); const links = relatedLinks.find(item => item.candidateId === id)?.links;
    node.append(element('p', `관련 링크 · ${id} (소유 요소 기준)`));
    if (!links) node.append(element('p', '관련 링크 조회 중이거나 자료 없음'));
    else if (!links.length) node.append(element('p', '관련 링크 없음'));
    else for (const link of links) node.append(element('p', link, 'mono'));
    return node;
  }
  function renderResults(): void {
    const signature = JSON.stringify([run?.runId, found, extraFound, details, images, relatedLinks]);
    if (signature === resultSignature) return; resultSignature = signature;
    function fill(panel: typeof results, items: (OfficialFinding | ExtraFinding)[], isImage: boolean): void {
      const label = isImage ? '추가 이미지 탐지' : '공식 탐지';
      panel.body.replaceChildren(element('p', run ? `${label} ${items.length}건` : '점검 시작 전', 'summary'));
      if (!run) return;
      panel.body.append(element('p', isImage ? 'result_extra.json · ETC / IMAGE_AD_OCR · OCR 추출 원문' : 'result.json · 직접 DOM 원문 · HOMOGLYPH / JAMO / TRANSPARENT / OFFSCREEN', 'hint'));
      if (!items.length) { panel.body.append(element('p', '확정 결과 수만 표시합니다. 검토 후보와 미완료 범위를 함께 확인하세요.', 'hint')); return; }
      const wrapper = element('div', undefined, 'table-scroll'); wrapper.tabIndex = 0; wrapper.setAttribute('role', 'region'); wrapper.setAttribute('aria-label', `${label} 표`);
      const table = element('table'); table.append(element('caption', `${label}의 원문 및 CLEF 근거`));
      const head = element('thead'); const hr = element('tr'); for (const title of ['URL / 유형', '원문 / 위치', '판정 상세 / 근거']) { const th = element('th', title); th.scope = 'col'; hr.append(th); } head.append(hr); const body = element('tbody');
      for (const finding of items) {
        const row = element('tr'); const first = element('td'); first.append(safeLink(finding.url), element('p', finding.technique, 'technique'));
        const raw = element('td'); raw.append(pre(finding.evidence_text), element('p', finding.location, 'mono'));
        const more = element('td'); const detail = details.find(item => item.findingId === finding.id && item.resultFile === (isImage ? 'result_extra.json' : 'result.json'));
        if (detail) more.append(analysis(detail.ai), candidateLinks(detail.candidateId), element('p', `DOM 관측: ${detail.observationIds.join(', ') || '없음'}`), pre(JSON.stringify(detail.sourceTextRanges)), imageButtons(detail.sourceIds), evidenceButton(detail.evidence.snapshotId));
        else more.append(element('p', '상세 근거 없음'));
        row.append(first, raw, more); body.append(row);
      }
      table.append(head, body); wrapper.append(table); panel.body.append(wrapper);
    }
    fill(results, found, false); fill(extraResults, extraFound, true);
  }
  function imageStatus(image: OcrImageOccurrence): string {
    if (image.status === 'not_selected') return '선택 제외';
    if (image.status === 'unsupported') return '지원 범위 밖';
    if (image.status === 'error') return 'OCR/이미지 실패';
    if (image.status !== 'completed') return '미처리';
    return { readable: '읽기 완료', partial: '일부 읽기 · 미완료', no_text: '문자 없음 · 검토', unreadable: '읽기 불가 · 미완료' }[image.extractionStatus ?? 'unreadable'];
  }
  function renderImages(): void {
    imagePanel.body.replaceChildren(element('p', run ? run.ocrEnabled ? `OCR 선택 · 이미지 발생 ${images.length}건` : 'OCR 미선택 · 이미지를 검사하지 않았습니다.' : '점검 시작 전', 'summary'));
    for (const image of images) {
      const card = element('article', undefined, 'image-card'); card.append(element('h3', image.imageId), element('p', imageStatus(image)), element('p', `${image.status} · ${image.extractionStatus ?? '미요청'} · ${image.reasonCode ?? '오류 없음'}`), element('p', image.location, 'mono'), pre(image.text ?? '추출 문자열 없음'), imageButtons([image.imageId])); imagePanel.body.append(card);
    }
  }
  function renderReviews(): void {
    const signature = JSON.stringify([run?.runId, reviews, images, relatedLinks]);
    if (signature === reviewSignature) return;
    reviewSignature = signature;
    reviewPanel.body.replaceChildren(element('p', `검토 후보 ${reviews.length}건`, 'summary'), element('p', '검토 후보는 확정 탐지에 포함되지 않습니다.', 'hint'));
    for (const item of reviews) { const card = element('article', undefined, 'review-card'); card.append(element('h3', `${item.candidateId} · ${item.reason}`), safeLink(item.url), element('p', item.location, 'mono'), element('p', `출처: ${item.sourceType} · DOM 관측: ${item.techniques.join(', ') || '없음'}`), pre(item.evidenceText), analysis(item.ai), candidateLinks(item.candidateId), pre(JSON.stringify(item.sourceTextRanges)), imageButtons(item.sourceIds), evidenceButton(item.evidence.snapshotId)); reviewPanel.body.append(card); }
  }
  function renderScope(): void {
    scopes.body.replaceChildren();
    if (!run) { scopes.body.append(element('p', '점검 시작 전')); return; }
    scopes.body.append(element('p', `실패 ${run.counts.failedPages} · 제외 ${run.counts.skippedPages} · 대기 ${run.counts.pendingPages}`));
    const list = element('ul');
    for (const error of run.errors) list.append(element('li', `${error.scope} · ${error.code} · ${error.url ?? error.candidateId ?? ''} · ${error.message}`));
    if (scope) { for (const skipped of scope.skipped) list.append(element('li', `제외: ${skipped.url} · ${skipped.reasonCode}`)); for (const url of scope.unvisitedUrls) list.append(element('li', `미방문: ${url}`)); }
    else scopes.body.append(element('p', active() ? '점검 중입니다. 종료 후 상세 범위를 불러옵니다.' : '상세 범위를 불러오는 중이거나 파일을 사용할 수 없습니다.', 'hint'));
    if (savedStatus) { scopes.body.append(element('p', `공식 저장: ${savedStatus.resultSaved ? '완료' : '실패'} · 추가 이미지 저장: ${savedStatus.extraResultSaved ? '완료' : '실패'}`), element('p', `미처리 이미지: ${savedStatus.imageScope.pendingImageIds.join(', ') || '없음'}`)); }
    scopes.body.append(list);
  }
  function renderExports(): void {
    exports.body.replaceChildren(element('p', '실제 저장 위치', 'hint'), element('p', config?.outputRoot ?? '설정 확인 중', 'mono'));
    if (run) { const runId = run.runId; exports.body.append(element('p', `다운로드 대상 실행: ${runId}`)); const group = element('div', undefined, 'downloads'); for (const name of files) { const download = button(`${name} 다운로드`, () => { void downloadFile(runId, name); }); download.disabled = active() || busy || (name === 'result.json' && savedStatus?.resultSaved === false) || (name === 'result_extra.json' && savedStatus?.extraResultSaved === false); group.append(download); } exports.body.append(group); }
    exports.body.append(element('p', '근거는 등록된 캡처 ID의 JSON으로만 표시·저장하며, 수집한 HTML을 실행하지 않습니다.', 'hint'));
  }
  function render(): void { renderControls(); renderStatus(); renderResults(); renderReviews(); renderImages(); renderScope(); renderExports(); }
  async function request(path: string, init: RequestInit = {}): Promise<Response> {
    const controller = new AbortController(); controllers.add(controller);
    const timeout = setTimeout(() => controller.abort(), 15000);
    try {
      const response = await fetch(path, { ...init, credentials: 'same-origin', headers: { Authorization: `Bearer ${options.sessionToken}`, ...(init.body ? { 'Content-Type': 'application/json' } : {}), ...init.headers }, signal: controller.signal });
      if (!response.ok) {
        let message = `요청 실패 (${response.status})`;
        try { const body = await response.json() as { error?: { code?: string; message?: string } }; if (body.error?.message) message = `${body.error.code ?? response.status}: ${body.error.message}`; } catch { /* Non-JSON failures retain HTTP status. */ }
        throw new Error(message);
      }
      // Drain the body while timeout/disposal can still abort the request.
      const bytes = await response.arrayBuffer();
      return new Response(bytes, { status: response.status, headers: response.headers });
    } finally { clearTimeout(timeout); controllers.delete(controller); }
  }
  async function json<T>(path: string, init?: RequestInit): Promise<T> { return await (await request(path, init)).json() as T; }
  function runPath(id: string): string { return `/api/runs/${encodeURIComponent(id)}`; }
  function schedule(): void {
    clearTimer(); if (!disposed && active()) pollTimer = setTimeout(() => { void poll(); }, Math.min(10000, pollInterval * 2 ** Math.min(errorsInRow, 4)));
  }
  async function loadArtifacts(id: string, version: number): Promise<void> {
    const sequence = ++artifactRequest;
    const parts = await Promise.allSettled([
      json<FindingsResponse>(`${runPath(id)}/findings`), json<FindingDetailsFile>(`${runPath(id)}/finding-details`), json<ReviewFile>(`${runPath(id)}/review`), json<ExtraFindingsResponse>(`${runPath(id)}/extra-findings`), json<OcrFile>(`${runPath(id)}/ocr`), json<RelatedLinksResponse>(`${runPath(id)}/related-links`),
    ]);
    if (!validRun(id, version) || !acceptArtifacts || sequence !== artifactRequest) return;
    const [f, d, r, e, o, l] = parts;
    if (f.status === 'fulfilled' && f.value.runId === id) found = f.value.findings;
    if (d.status === 'fulfilled' && d.value.runId === id) details = d.value.details;
    if (r.status === 'fulfilled' && r.value.runId === id) reviews = r.value.candidates;
    if (e.status === 'fulfilled' && e.value.runId === id) extraFound = e.value.findings;
    if (o.status === 'fulfilled' && o.value.runId === id) images = o.value.images;
    if (l.status === 'fulfilled' && l.value.runId === id) relatedLinks = l.value.candidates;
    for (const part of parts) if (part.status === 'rejected') showError(part.reason);
    renderResults(); renderReviews(); renderImages();
  }
  async function loadScope(id: string, version: number): Promise<void> {
    try { const status = await json<ScanStatusFile>(`${runPath(id)}/files/scan-status.json`); if (validRun(id, version) && status.run.runId === id) { scope = status.scope; savedStatus = status; renderScope(); renderExports(); } } catch (error) { if (validRun(id, version)) showError(error); }
  }
  async function poll(): Promise<void> {
    if (!run || disposed) return;
    const id = run.runId; const version = generation;
    try {
      const next = await json<RunSnapshot>(runPath(id)); if (!validRun(id, version) || next.runId !== id) return;
      run = next; errorsInRow = 0; render();
      // Cancellation invalidates earlier responses; its saved terminal snapshot can
      // safely refresh artifacts within the current generation.
      if (!active()) acceptArtifacts = true;
      if (acceptArtifacts) await loadArtifacts(id, version);
      if (!validRun(id, version)) return;
      if (!active()) { await loadScope(id, version); } else schedule();
    } catch (error) { if (validRun(id, version)) { errorsInRow++; showError(error); schedule(); } }
  }
  async function start(): Promise<void> {
    if (busy || active() || !config || disposed) return;
    if (!config.aiConfigured) { showError(new Error('INVALID_CONFIG: CLEF 키 설정이 필요합니다.')); return; }
    if (!consentInput.checked) { showError(new Error('INVALID_REQUEST: 외부 분석 전송 동의가 필요합니다.')); return; }
    const entryUrl = urlInput.value.trim();
    try { const parsed = new URL(entryUrl); if (!['http:', 'https:'].includes(parsed.protocol) || parsed.username || parsed.password) throw new Error(); } catch { showError(new Error('INVALID_URL: HTTP(S) 진입 URL을 입력하세요.')); urlInput.focus(); return; }
    clearError(); busy = true; renderControls(); renderExports();
    try {
      const next = await json<RunSnapshot>('/api/runs', { method: 'POST', body: JSON.stringify({ entryUrl, ocrEnabled: ocrInput.checked, externalAnalysisConsent: true }) });
      if (disposed) return;
      clearTimer(); generation++; closeDialog(); run = next; acceptArtifacts = true; cancelling = false; errorsInRow = 0; found = []; extraFound = []; images = []; relatedLinks = []; details = []; reviews = []; scope = null; savedStatus = null;
      render();
      // Artifact fetching must not hold the stop button hostage.
      void loadArtifacts(next.runId, generation);
      if (active()) schedule(); else void loadScope(next.runId, generation);
    } catch (error) { showError(error); } finally { busy = false; if (!disposed) { renderControls(); renderExports(); } }
  }
  async function cancel(): Promise<void> {
    if (!run || cancelling || run.state !== 'running' || disposed) return;
    const id = run.runId; cancelling = true; acceptArtifacts = false; generation++; const version = generation; clearTimer(); closeDialog();
    run = { ...run, state: 'stopping' }; render(); clearError();
    try { const next = await json<RunSnapshot>(`${runPath(id)}/cancel`, { method: 'POST', body: '{}' }); if (validRun(id, version) && next.runId === id) { run = next; render(); } }
    catch (error) { if (validRun(id, version)) { acceptArtifacts = true; showError(error); } }
    finally { if (validRun(id, version)) { cancelling = false; renderControls(); if (active()) schedule(); else void poll(); } }
  }
  function registeredEvidence(id: string): boolean { return details.some(item => item.evidence.snapshotId === id) || reviews.some(item => item.evidence.snapshotId === id); }
  function closeDialog(): void { dialogVersion++; if (previewUrl) { URL.revokeObjectURL(previewUrl); blobUrls.delete(previewUrl); previewUrl = null; } if (activeDialog) { activeDialog.close(); activeDialog.remove(); activeDialog = null; dialogTrigger?.focus(); dialogTrigger = null; } }
  function saveBlob(bytes: Blob, filename: string): void {
    const blobUrl = URL.createObjectURL(new Blob([bytes], { type: 'application/json' })); blobUrls.add(blobUrl);
    const a = element('a'); a.href = blobUrl; a.download = filename.replace(/[^\p{L}\p{N}_.-]/gu, '_'); a.hidden = true; root.append(a); a.click(); a.remove();
    const timer = setTimeout(() => { URL.revokeObjectURL(blobUrl); blobUrls.delete(blobUrl); revokeTimers.delete(timer); }, 10000); revokeTimers.add(timer);
  }
  async function downloadFile(id: string, name: typeof files[number]): Promise<void> {
    const version = generation; clearError();
    try { const bytes = await (await request(`${runPath(id)}/files/${name}`)).blob(); if (validRun(id, version)) saveBlob(bytes, `${id}-${name}`); } catch (error) { if (validRun(id, version)) showError(error); }
  }
  async function showEvidence(id: string): Promise<void> {
    if (!run || !registeredEvidence(id)) return; const runId = run.runId; const version = generation; const dialogRequest = ++dialogVersion; dialogTrigger = document.activeElement as HTMLElement; clearError();
    try {
      const response = await json<unknown>(`${runPath(runId)}/evidence/${encodeURIComponent(id)}`);
      if (!validRun(runId, version) || dialogRequest !== dialogVersion || !registeredEvidence(id)) return;
      const trigger = dialogTrigger; closeDialog(); dialogTrigger = trigger;
      const dialog = element('dialog', undefined, 'evidence-dialog'); activeDialog = dialog; const title = element('h2', `캡처 근거 · ${id}`); title.id = 'evidence-title'; dialog.setAttribute('aria-labelledby', title.id);
      const raw = JSON.stringify(response, null, 2); dialog.append(title, element('p', '캡처 시점의 JSON입니다. 현재 웹페이지와 다를 수 있습니다.'), pre(raw), button('캡처 JSON 다운로드', () => { if (validRun(runId, version)) saveBlob(new Blob([raw]), `${runId}-${id}.json`); }), button('닫기', closeDialog));
      dialog.addEventListener('cancel', event => { event.preventDefault(); closeDialog(); }); root.append(dialog); dialog.showModal();
    } catch (error) { if (validRun(runId, version)) showError(error); }
  }
  async function showImage(id: string): Promise<void> {
    if (!run) return;
    const image = images.find(item => item.imageId === id); if (!image) return;
    const runId = run.runId; const version = generation; closeDialog(); dialogTrigger = document.activeElement as HTMLElement;
    const dialog = element('dialog', undefined, 'evidence-dialog'); activeDialog = dialog; const dialogRequest = dialogVersion;
    const title = element('h2', `이미지 근거 · ${id}`); title.id = 'image-title'; dialog.setAttribute('aria-labelledby', title.id);
    dialog.append(title, element('p', imageStatus(image)), element('p', `읽기 상태: ${image.extractionStatus ?? '미요청'} · confidence: 미제공 (CLEF 확률과 별도)`), pre(image.text ?? '추출 문자열 없음'), element('p', `위치: ${image.location} · frameUrl: ${image.frameUrl}`), pre(JSON.stringify(image.framePath)), element('p', `OCR 모델: ${image.model ?? '미선택'} · 규격: ${image.promptVersion} · 자산: ${image.sourceKind} [${image.sourceIndex}] · 숨김 관측: ${image.concealment.join(', ') || '없음'}`), element('p', `원본 SHA-256: ${image.original?.sha256 ?? '미확보'}`), element('p', `PNG SHA-256: ${image.input?.sha256 ?? '미확보'} · 첫 프레임 0 · ${image.input?.width ?? '?'} × ${image.input?.height ?? '?'}`), element('p', `캐시 원본: ${image.cacheOf ?? '없음'} · OCR 요청 ${image.attemptCount} · 비용: ${image.usage.costUsd ?? '미확정'}`), element('p', `사유: ${image.reasonCode ?? '없음'} · 원본은 archive에 보존되며 미리보기는 등록 PNG만 사용합니다.`));
    const linked = details.filter(item => item.sourceIds.includes(id)); const reviewed = reviews.filter(item => item.sourceIds.includes(id));
    for (const item of [...linked, ...reviewed]) dialog.append(analysis(item.ai), candidateLinks(item.candidateId), pre(JSON.stringify(item.sourceTextRanges)));
    dialog.append(element('details')); const styles = dialog.lastElementChild!; styles.append(element('summary', '캡처 스타일 관측'), pre(JSON.stringify(image.styles, null, 2)));
    dialog.append(button('닫기', closeDialog)); dialog.addEventListener('cancel', event => { event.preventDefault(); closeDialog(); }); root.append(dialog); dialog.showModal(); clearError();
    if (!image.input) { dialog.append(element('p', '등록된 PNG 없음')); return; }
    try {
      if (image.input.mime !== 'image/png') throw new Error('PNG 분석 프레임만 표시할 수 있습니다.');
      const response = await request(`${runPath(runId)}/images/${encodeURIComponent(image.input.assetId)}`);
      if (!validRun(runId, version) || activeDialog !== dialog || dialogRequest !== dialogVersion) return;
      if (response.headers.get('Content-Type')?.split(';')[0].trim().toLowerCase() !== 'image/png' || response.headers.get('X-Content-Type-Options')?.toLowerCase() !== 'nosniff') throw new Error('인증된 PNG 응답과 nosniff가 필요합니다.');
      const png = await response.blob();
      const signature = new Uint8Array(await png.slice(0, 8).arrayBuffer());
      if (![137, 80, 78, 71, 13, 10, 26, 10].every((byte, index) => signature[index] === byte)) throw new Error('PNG 바이트 서명이 일치하지 않습니다.');
      if (!validRun(runId, version) || activeDialog !== dialog || dialogRequest !== dialogVersion) return;
      previewUrl = URL.createObjectURL(png); blobUrls.add(previewUrl); const preview = element('img'); preview.src = previewUrl; preview.alt = `첫 프레임 PNG · ${id}`; preview.className = 'image-preview'; dialog.insertBefore(preview, title.nextSibling);
    } catch (error) { if (validRun(runId, version) && activeDialog === dialog) showError(error); }
  }
  render();
  const ready = (async () => {
    try { if (!config) config = await json<PublicConfig>('/api/config'); if (!disposed) render(); } catch (error) { showError(error); }
  })();
  return { ready, dispose() { disposed = true; generation++; clearTimer(); for (const controller of controllers) controller.abort(); controllers.clear(); for (const timer of revokeTimers) clearTimeout(timer); revokeTimers.clear(); for (const url of blobUrls) URL.revokeObjectURL(url); blobUrls.clear(); closeDialog(); root.replaceChildren(); } };
}

declare global { interface Window { __INSPECTOR_BOOTSTRAP__?: BootstrapOptions } }
if (typeof window !== 'undefined' && typeof document !== 'undefined') {
  const mount = () => { const root = document.getElementById('app'); const options = window.__INSPECTOR_BOOTSTRAP__; if (root && options?.sessionToken) { const dashboard = bootstrap(root, options); window.addEventListener('pagehide', () => dashboard.dispose(), { once: true }); } };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', mount, { once: true }); else mount();
}
