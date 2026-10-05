# 키워드 캡처 (페이지 텍스트 선택 → 키워드 차단 규칙) Implementation Plan

> REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`.

**Goal:** 블록 픽커("고르기")의 키워드판 — 키워드 패널에서 **"키워드 잡기"** 모드를 켜고 페이지에서 텍스트를 선택하면, 그 텍스트가 키워드 입력 폼에 채워져(미리보기 매칭 수 포함) 사용자가 검토(minMatchCount 기본 2, 이름) 후 추가. 사람 UI + MCP 구동 + 다듬기.

**Confirmed UX:** 캡처 = 즉시 규칙 생성 X → **폼에 채워 검토 후 추가**(과차단 방지). 크롬엔 선택 캡처가 없음(타이핑 only) — 이건 신규.

**Architecture:** 요소 픽커를 미러. JS IIFE(`keywordCaptureUserScriptSource`)가 캡처 모드 on일 때 `getSelection()` → `callHandler('infocutter.keywordResult', text)`; `webview_adapter`가 핸들러 등록 + start/stop; `coordinator`가 받아 `WebViewModel.infocutterCapturedKeyword`(ValueNotifier<String?>) 갱신; 키워드 패널이 그걸 watch해 `_keywordController`에 채움. MCP `textBlock.setCaptureMode` + `/state.textBlocks` 노출.

## 검증된 seam (조사 결과)
- 픽커 패턴: `selector_engine.dart` emitCurrent→`callHandler('infocutter.pickerResult', …)` (792), 이벤트 리스너 837-848, start/stop `window.__infocutterPicker` 871-883.
- 핸들러: `webview_adapter.dart` `pickerResultHandlerName`(15) + `attachPickerHandler`(51) + `setPickerActive`(102); watch도 동일 패턴(`attachWatchHandler` 81).
- 주입/배선: `webview_integration.dart` `buildInfocutterUserScripts`(39), `attachInfocutterHandlers`(42), `webview_tab_load_handlers.dart`(18).
- 텍스트블록: `text_block_service.dart` `addRuleForUrl(TextBlockRuleRequest{keyword, objectName, minMatchCount})`(82); `text_block_models.dart` `TextBlockRule{keyword,enabled,minMatchCount,objectName,objectTags,id}`; runtime `text_block_runtime.dart` `normalizeText`(26)/`preferredBlockContainer`(53).
- 패널: `ui/infocutter_text_block_panel.dart` `_keywordController`(27)/`_minCountController`(29)/`_addRule`(180)/form build(90).
- 패널 모드: `infocutter_panel_mode.dart` `InfocutterPanelMode.keyword`(9).
- MCP: `app_automation_infocutter_commands.dart` `addTextBlockRule`(275)/list/setEnabled/remove; controller cases + capabilities.
- 세션 notifier 패턴: `WebViewModel.infocutterSelectionSession` (ValueNotifier) — mirror for `infocutterCapturedKeyword`.

## Tasks

### K1 — JS capture + Dart handler + capture start/stop + notifier (data path)
**Files:** `lib/infocutter/selector_engine.dart` (or a new `*_runtime` const) ; `lib/infocutter/webview_adapter.dart` ; `lib/infocutter/webview_integration.dart` ; `lib/webview_tab_load_handlers.dart` ; `lib/models/webview_model.dart` ; test.
- [ ] JS `keywordCaptureUserScriptSource`: IIFE exposing `window.__infocutterKeywordCapture = { start(), stop() }`. While active, on `mouseup`/`touchend` with a non-empty trimmed `window.getSelection().toString()`, debounce → `window.flutter_inappwebview.callHandler('infocutter.keywordResult', text)`. Don't swallow normal selection (don't preventDefault — selection must work). Inactive = no-op.
- [ ] Add to `buildInfocutterUserScripts` so it's injected with the other runtimes.
- [ ] `webview_adapter.dart`: `const keywordResultHandlerName = 'infocutter.keywordResult';` + `attachKeywordHandler(controller, {void Function(String text)? onKeywordCapture})` (mirror `attachWatchHandler`) + `setKeywordCaptureActive(controller, {required bool active})` → evaluateJavascript `window.__infocutterKeywordCapture && .start()/.stop()`.
- [ ] `webview_integration.dart` `attachInfocutterHandlers`: add optional `onKeywordCapture` param → `_adapter.attachKeywordHandler(...)`. Export `keywordResultHandlerName`. Add a free fn `setInfocutterKeywordCaptureActive(controller, active)`.
- [ ] `webview_tab_load_handlers.dart`: wire `onKeywordCapture: (text) => _handleInfocutterKeywordCapture(...)` (forward to coordinator).
- [ ] `WebViewModel`: add `final ValueNotifier<String?> infocutterCapturedKeyword` (+ dispose).
- [ ] Test: `attachKeywordHandler` invokes callback on a string arg (unit, mirror existing adapter handler tests if any).

### K2 — coordinator capture mode + panel toggle + fill field (visible flow)
**Files:** `lib/infocutter/infocutter_webview_coordinator.dart` ; `lib/infocutter/ui/infocutter_text_block_panel.dart` ; sidebar wiring (`infocutter_sidebar*.dart`) ; test.
- [ ] coordinator: `startKeywordCapture()` (open panel keyword mode if needed + `setKeywordCaptureActive(active:true)`), `stopKeywordCapture()` (active:false), `handleKeywordCapture(String text)` → set `_webViewModel.infocutterCapturedKeyword.value = text` (+ ensure keyword panel open).
- [ ] Panel: add a **"키워드 잡기" 토글**(IconButton/Switch in the form header). On → coordinator.startKeywordCapture; Off → stop. Watch `infocutterCapturedKeyword` (via the sidebar data or a ValueListenableBuilder) → when it changes, set `_keywordController.text = captured` (focus-guard: only when not actively editing). Keep the existing 추가 flow (minMatchCount default 2).
- [ ] Wire the toggle + captured-keyword through `InfocutterSidebarData`/`Actions` (or pass the WebViewModel notifier) as needed.
- [ ] Widget test: capturedKeyword change populates the keyword field; toggle calls the start/stop action.

### K3 — MCP: capture mode + observability
**Files:** `lib/services/app_automation_infocutter_commands.dart` (+ session/browser cmds as needed) ; `lib/services/app_automation_controller.dart` ; `lib/services/app_automation_snapshot_builder.dart` ; test.
- [ ] `textBlock.setCaptureMode {enabled}` → coordinator start/stopKeywordCapture (or set active). Register case + capability.
- [ ] `/state.textBlocks`: add `captureMode` (bool) + `lastCapturedKeyword` (from `infocutterCapturedKeyword.value`).
- [ ] (optional) `textBlock.captureSelection` → read current page `window.getSelection()` via JS + add a rule (dangerous-tier, needs evalJs-like). Defer if it complicates; `textBlock.addRule {keyword}` already lets MCP add directly.
- [ ] Test: capabilities contains `textBlock.setCaptureMode`.

### K4 — verify + headless demo
- [ ] `fvm dart format --set-exit-if-changed` + `fvm flutter analyze` (0) + `fvm flutter test` (all green).
- [ ] Rebuild + via bridge (token): `textBlock.addRule {keyword:"광고", minMatchCount:1}` on a real page → `page.evalJs` confirm blocks containing "광고" got `data-infocutter-text-block-hidden` / display:none; `textBlock.listRules` shows it; `textBlock.setCaptureMode {enabled:true}` → `/state.textBlocks.captureMode==true`. Manual: 키워드 잡기 토글 → select page text → field populated → 추가 → block hidden.

## 범위 밖
- 크롬식 fingerprint(구조 잠금) — Flutter 모델엔 없음(별도). minMatchCount로 과차단 1차 방어.
- 헤드리스에서 실제 텍스트 selection 시뮬레이션(브리지 selection 주입) — addRule 직접 경로로 대체.
