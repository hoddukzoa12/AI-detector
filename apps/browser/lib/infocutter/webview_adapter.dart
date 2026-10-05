import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'application/runtime/apply_infocutter_runtime_use_case.dart';
import 'auth_origin_policy.dart';
import 'inappwebview_runtime_page.dart';
import 'infocutter_runtime_contracts.dart';
import 'infocutter_service.dart';
import 'network_filter_service.dart';
import 'selection_session.dart';
import 'selector_engine.dart';
import 'site_protection_bypass.dart';
import 'text_block_service.dart';
import 'watch_service.dart';
import 'webview_contributions.dart';

/// JS -> Dart 호출 핸들러 이름.
const String pickerResultHandlerName = 'infocutter.pickerResult';

/// Watch runtime JS -> Dart 호출 핸들러 이름.
const String watchDetectionHandlerName = 'infocutter.watchDetection';

/// Keyword-capture JS -> Dart 호출 핸들러 이름.
const String keywordResultHandlerName = 'infocutter.keywordResult';

class InfocutterWebViewAdapter {
  const InfocutterWebViewAdapter({
    ApplyInfocutterRuntimeUseCase applyRuntimeUseCase =
        const ApplyInfocutterRuntimeUseCase(
      runtimeObjectName: infocutterBlockRuntimeObjectName,
      runtimeUserScriptSource: infocutterBlockRuntimeUserScriptSource,
    ),
    ApplyInfocutterRuntimeUseCase applyWatchRuntimeUseCase =
        const ApplyInfocutterRuntimeUseCase(
      runtimeObjectName: infocutterWatchRuntimeObjectName,
      runtimeUserScriptSource: infocutterWatchRuntimeUserScriptSource,
    ),
    ApplyInfocutterRuntimeUseCase applyTextBlockRuntimeUseCase =
        const ApplyInfocutterRuntimeUseCase(
      runtimeObjectName: infocutterTextBlockRuntimeObjectName,
      runtimeUserScriptSource: infocutterTextBlockRuntimeUserScriptSource,
    ),
  })  : _applyRuntimeUseCase = applyRuntimeUseCase,
        _applyWatchRuntimeUseCase = applyWatchRuntimeUseCase,
        _applyTextBlockRuntimeUseCase = applyTextBlockRuntimeUseCase;

  final ApplyInfocutterRuntimeUseCase _applyRuntimeUseCase;
  final ApplyInfocutterRuntimeUseCase _applyWatchRuntimeUseCase;
  final ApplyInfocutterRuntimeUseCase _applyTextBlockRuntimeUseCase;

  /// URL 별로 적용할 ContentBlocker 목록을 InAppWebViewSettings 에 박음.
  /// 호출자는 setSettings + reload 흐름을 따로 호출해야 (URL 변경 시).
  void applySettings(
    InAppWebViewSettings settings,
    InfocutterService service,
    Uri? url,
    NetworkFilterService? networkFilters,
  ) {
    // 인증 origin 에서는 아무 것도 차단하지 않는다 — 로그인 흐름에 개입하면
    // 안 되고, 이전 페이지에서 남은 블로커도 여기서 비워진다.
    if (isAuthOrigin(url)) {
      settings.contentBlockers = const <ContentBlocker>[];
      return;
    }
    // #20 사이트 보호 일시 끄기 — 블로커를 비워 페이지를 원본으로 돌린다.
    if (SiteProtectionBypass.instance.isBypassed(url)) {
      settings.contentBlockers = const <ContentBlocker>[];
      return;
    }
    final infocutterBlockers = url == null
        ? service.buildContentBlockers()
        : service.buildContentBlockersForUrl(url);
    final networkBlockers = networkFilters == null
        ? const <ContentBlocker>[]
        : networkFilters.buildContentBlockers();
    settings.contentBlockers = [
      ...infocutterBlockers,
      ...networkBlockers,
    ];
  }

  /// InAppWebView 의 `initialUserScripts` 에 넘길 picker UserScript 목록.
  /// 호출자가 기존 user script 와 병합할지 결정.
  List<UserScript> buildUserScripts() => [
        for (final contribution in infocutterUserScriptContributions)
          contribution.buildUserScript(),
      ];

  /// controller 에 picker 결과 핸들러를 등록. 같은 컨트롤러에 중복 등록되어도 안전.
  void attachPickerHandler(
    InAppWebViewController controller, {
    void Function(PickerResult result)? onPickerResult,
  }) {
    controller.addJavaScriptHandler(
      handlerName: pickerResultHandlerName,
      callback: (args) {
        final result = PickerResult.tryParse(args);
        if (result == null) {
          if (kDebugMode) {
            debugPrint('[infocutter] picker payload 무효: $args');
          }
          return null;
        }
        if (kDebugMode) {
          debugPrint(
            '[infocutter] picker result selector=${result.selector} '
            'matches=${result.matchCount} '
            'candidate=${result.selectedCandidateIndex}/${result.candidates.length} '
            'depth=${result.selectedDepthIndex}/${result.depthTargets.length}',
          );
        }
        if (onPickerResult != null) {
          onPickerResult(result);
        }
        return null;
      },
    );
  }

  void attachWatchHandler(
    InAppWebViewController controller, {
    void Function(WatchDetection detection)? onWatchDetection,
  }) {
    controller.addJavaScriptHandler(
      handlerName: watchDetectionHandlerName,
      callback: (args) {
        final detection = WatchDetection.tryParse(args);
        if (detection == null) {
          if (kDebugMode) {
            debugPrint('[infocutter] watch payload 무효: $args');
          }
          return null;
        }
        onWatchDetection?.call(detection);
        return null;
      },
    );
  }

  void attachKeywordHandler(
    InAppWebViewController controller, {
    void Function(String text)? onKeywordCapture,
  }) {
    controller.addJavaScriptHandler(
      handlerName: keywordResultHandlerName,
      callback: (args) {
        final text = args.isNotEmpty && args.first is String
            ? (args.first as String).trim()
            : '';
        if (text.isEmpty) return null;
        if (kDebugMode) {
          debugPrint('[infocutter] keyword captured: "$text"');
        }
        onKeywordCapture?.call(text);
        return null;
      },
    );
  }

  /// 활성 keyword-capture 모드 토글 — JS 측의
  /// `window.__infocutterKeywordCapture.start/stop` 호출.
  Future<void> setKeywordCaptureActive(
    InAppWebViewController controller, {
    required bool active,
  }) async {
    final fn = active ? 'start' : 'stop';
    try {
      var result = await _evaluateKeywordCaptureToggle(controller, fn);
      if (result == 'missing' && active) {
        await controller.evaluateJavascript(
          source: keywordCaptureUserScriptSource,
        );
        result = await _evaluateKeywordCaptureToggle(controller, fn);
      }
      if (kDebugMode) {
        debugPrint('[infocutter] keywordCapture $fn result=$result');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[infocutter] keywordCapture $fn failed: $error');
      }
      rethrow;
    }
  }

  Future<Object?> _evaluateKeywordCaptureToggle(
    InAppWebViewController controller,
    String fn,
  ) {
    return controller.evaluateJavascript(
      source: '''
        (function () {
          var kc = window.$infocutterKeywordCaptureRuntimeObjectName;
          if (!kc || typeof kc.$fn !== 'function') {
            return 'missing';
          }
          kc.$fn();
          return 'ok';
        })()
      ''',
    );
  }

  /// 활성 picker 모드 토글 — JS 측의 `window.__infocutterPicker.start/stop` 호출.
  Future<void> setPickerActive(
    InAppWebViewController controller, {
    required bool active,
  }) async {
    final fn = active ? 'start' : 'stop';
    try {
      var result = await _evaluatePickerToggle(controller, fn);
      if (result == 'missing' && active) {
        await controller.evaluateJavascript(
          source: infocutterPickerRuntimeUserScriptSource,
        );
        result = await _evaluatePickerToggle(controller, fn);
      }
      if (kDebugMode) {
        debugPrint('[infocutter] picker $fn result=$result');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[infocutter] picker $fn failed: $error');
      }
      rethrow;
    }
  }

  Future<Object?> _evaluatePickerToggle(
    InAppWebViewController controller,
    String fn,
  ) {
    return controller.evaluateJavascript(
      source: '''
        (function () {
          var picker = window.$infocutterPickerRuntimeObjectName;
          if (!picker || typeof picker.$fn !== 'function') {
            return 'missing';
          }
          picker.$fn();
          return 'ok';
        })()
      ''',
    );
  }

  /// 멀티셀렉트 세션의 번호 매겨진 영구 하이라이트를 그림 — JS 측의
  /// `window.__infocutterPicker.applySessionHighlights(entries)` 호출.
  /// 세션이 바뀔 때마다(add/remove/refine/clear) 호출하면 picker 가 박스를
  /// 다시 그림. 빈 목록을 넘기면 하이라이트가 지워짐. 카드 순서가 1부터의
  /// 배지 번호 + 팔레트 색을 결정함(JS 와 동일 규칙).
  Future<void> applySessionHighlights(
    InAppWebViewController controller,
    List<SelectionCard> session,
  ) async {
    final entries = [
      for (var index = 0; index < session.length; index++)
        {
          'selector': session[index].selector,
          'index': index + 1,
          'name': session[index].name,
        },
    ];
    await controller.evaluateJavascript(
      source: 'window.$infocutterPickerRuntimeObjectName && '
          'window.$infocutterPickerRuntimeObjectName.applySessionHighlights(${jsonEncode(entries)})',
    );
  }

  Future<void> applyRuntimeState(
    InAppWebViewController controller,
    InfocutterService service,
    Uri? url,
  ) async {
    final state = url == null
        ? {
            'version': 1,
            'globalEnabled': service.globalEnabled,
            'profileEnabled': false,
            'rules': const <Object?>[],
          }
        : service.buildRuntimeStateForUrl(url);
    try {
      final result = await _applyRuntimeUseCase(
        ApplyInfocutterRuntimeCommand(
          page: InAppWebViewRuntimePage(controller),
          state: state,
        ),
      );
      if (kDebugMode) {
        debugPrint('[infocutter] runtime apply result=$result');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[infocutter] runtime apply failed: $error');
      }
      rethrow;
    }
  }

  Future<void> applyWatchState(
    InAppWebViewController controller,
    WatchService service,
  ) async {
    await _applyWatchRuntimeUseCase(
      ApplyInfocutterRuntimeCommand(
        page: InAppWebViewRuntimePage(controller),
        state: service.buildRuntimeState(),
      ),
    );
  }

  Future<void> applyTextBlockState(
    InAppWebViewController controller,
    TextBlockService service,
    Uri? url,
  ) async {
    await _applyTextBlockRuntimeUseCase(
      ApplyInfocutterRuntimeCommand(
        page: InAppWebViewRuntimePage(controller),
        state: service.buildRuntimeStateForUrl(url),
      ),
    );
  }
}
