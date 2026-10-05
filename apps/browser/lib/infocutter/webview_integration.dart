import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'infocutter_service.dart';
import 'network_filter_service.dart';
import 'selection_session.dart';
import 'selector_engine.dart';
import 'text_block_service.dart';
import 'watch_service.dart';
import 'webview_adapter.dart';

export 'infocutter_runtime_contracts.dart'
    show
        infocutterBlockRuntimeContract,
        infocutterBlockRuntimeObjectName,
        infocutterBlockRuntimeUserScriptSource,
        infocutterKeywordCaptureRuntimeContract,
        infocutterKeywordCaptureRuntimeObjectName,
        infocutterKeywordCaptureRuntimeUserScriptSource,
        infocutterPickerRuntimeContract,
        infocutterPickerRuntimeObjectName,
        infocutterPickerRuntimeUserScriptSource,
        infocutterTextBlockRuntimeContract,
        infocutterTextBlockRuntimeObjectName,
        infocutterTextBlockRuntimeUserScriptSource,
        infocutterWatchRuntimeContract,
        infocutterWatchRuntimeObjectName,
        infocutterWatchRuntimeUserScriptSource;
export 'selector_engine.dart'
    show
        PickerCandidate,
        PickerDepthTarget,
        PickerResult,
        keywordCaptureUserScriptSource,
        lazyImagePromoteUserScriptSource;
export 'watch_service.dart' show WatchDetection;
export 'webview_contributions.dart'
    show
        infocutterUserScriptContributions,
        keywordCaptureUserScriptId,
        lazyImagePromoteUserScriptId,
        pickerUserScriptId,
        runtimeUserScriptId,
        textBlockRuntimeUserScriptId,
        watchRuntimeUserScriptId;
export 'webview_adapter.dart'
    show
        pickerResultHandlerName,
        watchDetectionHandlerName,
        keywordResultHandlerName;

const _adapter = InfocutterWebViewAdapter();

/// URL 별로 적용할 ContentBlocker 목록을 InAppWebViewSettings 에 박음.
/// 호출자는 setSettings + reload 흐름을 따로 호출해야 (URL 변경 시).
void applyInfocutterSettings(
  InAppWebViewSettings settings,
  InfocutterService service,
  Uri? url, {
  NetworkFilterService? networkFilters,
}) {
  _adapter.applySettings(settings, service, url, networkFilters);
}

/// InAppWebView 의 `initialUserScripts` 에 넘길 picker UserScript 목록.
/// 호출자가 기존 user script 와 병합할지 결정.
List<UserScript> buildInfocutterUserScripts() => _adapter.buildUserScripts();

/// controller 에 picker / watch / keyword-capture 결과 핸들러를 등록.
/// 같은 컨트롤러에 중복 등록되어도 안전.
void attachInfocutterHandlers(
  InAppWebViewController controller,
  InfocutterService service, {
  void Function(PickerResult result)? onPickerResult,
  void Function(WatchDetection detection)? onWatchDetection,
  void Function(String text)? onKeywordCapture,
}) {
  _adapter.attachPickerHandler(controller, onPickerResult: onPickerResult);
  _adapter.attachWatchHandler(controller, onWatchDetection: onWatchDetection);
  _adapter.attachKeywordHandler(controller, onKeywordCapture: onKeywordCapture);
}

/// 활성 picker 모드 토글 — JS 측의 `window.__infocutterPicker.start/stop` 호출.
Future<void> setPickerActive(
  InAppWebViewController controller, {
  required bool active,
}) async {
  await _adapter.setPickerActive(controller, active: active);
}

/// 멀티셀렉트 세션의 번호 매겨진 영구 하이라이트를 그림. 세션 카드가 바뀔
/// 때마다 호출(예: `tab.infocutterSelectionSession.value` 전달). 빈 목록이면 지움.
Future<void> applyInfocutterSessionHighlights(
  InAppWebViewController controller,
  List<SelectionCard> session,
) async {
  await _adapter.applySessionHighlights(controller, session);
}

Future<void> applyInfocutterRuntimeForUrl(
  InAppWebViewController controller,
  InfocutterService service,
  Uri? url,
) async {
  await _adapter.applyRuntimeState(controller, service, url);
}

Future<void> applyInfocutterWatchRuntime(
  InAppWebViewController controller,
  WatchService service,
) async {
  await _adapter.applyWatchState(controller, service);
}

/// 활성 keyword-capture 모드 토글 — JS 측의
/// `window.__infocutterKeywordCapture.start/stop` 호출.
Future<void> setInfocutterKeywordCaptureActive(
  InAppWebViewController controller, {
  required bool active,
}) async {
  await _adapter.setKeywordCaptureActive(controller, active: active);
}

Future<void> applyInfocutterTextBlockRuntimeForUrl(
  InAppWebViewController controller,
  TextBlockService service,
  Uri? url,
) async {
  await _adapter.applyTextBlockState(controller, service, url);
}
