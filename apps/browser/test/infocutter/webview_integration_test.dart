import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/infocutter_runtime_contributors.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/infocutter/network_filter_service.dart';
import 'package:infocutter_app/infocutter/selector_engine.dart';
import 'package:infocutter_app/infocutter/text_block_runtime.dart';
import 'package:infocutter_app/infocutter/watch_runtime.dart';
import 'package:infocutter_app/infocutter/webview_integration.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('PickerResult.tryParse', () {
    test('빈 args / 첫 인자가 String 이 아니면 null', () {
      expect(PickerResult.tryParse([]), isNull);
      expect(PickerResult.tryParse([42]), isNull);
      expect(PickerResult.tryParse(['']), isNull);
    });

    test('selector 만 있을 때 default 값으로 채움', () {
      final r = PickerResult.tryParse(['.ad']);
      expect(r, isNotNull);
      expect(r!.selector, '.ad');
      expect(r.tag, '');
      expect(r.id, isNull);
      expect(r.classes, isEmpty);
      expect(r.matchCount, 0);
      expect(r.alternatives, isEmpty);
    });

    test('info Map 의 필드 파싱', () {
      final r = PickerResult.tryParse([
        '.ad',
        {
          'tag': 'DIV',
          'id': 'banner',
          'classes': ['ad', 'lazy'],
          'matchCount': 3
        },
      ]);
      expect(r, isNotNull);
      expect(r!.tag, 'DIV');
      expect(r.id, 'banner');
      expect(r.classes, ['ad', 'lazy']);
      expect(r.matchCount, 3);
    });

    test('alternatives 리스트 파싱', () {
      final r = PickerResult.tryParse([
        '.ad',
        {'tag': 'DIV'},
        ['#banner', 'div.ad', 'div'],
      ]);
      expect(r!.alternatives, ['#banner', 'div.ad', 'div']);
    });

    test('잘못된 타입은 default 로 fallback (throw 안 함)', () {
      final r = PickerResult.tryParse([
        '.ad',
        {'tag': 999, 'id': 42, 'classes': 'not-a-list', 'matchCount': 'nope'},
        'not-a-list',
      ]);
      expect(r, isNotNull);
      expect(r!.tag, '');
      expect(r.id, isNull);
      expect(r.classes, isEmpty);
      expect(r.matchCount, 0);
      expect(r.alternatives, isEmpty);
    });

    test('matchCount 가 double 일 때 int 로 변환', () {
      final r = PickerResult.tryParse([
        '.ad',
        {'matchCount': 3.7},
      ]);
      expect(r!.matchCount, 3);
    });

    test('deep picker payload 후보와 범위 정보를 파싱', () {
      final r = PickerResult.tryParse([
        'article.card',
        {
          'tag': 'ARTICLE',
          'frameScope': 'https://embed.example/frame',
          'matchCount': 1,
          'selectedCandidateIndex': 1,
          'selectedDepthIndex': 0,
          'selectorCandidates': ['article.card', '.card'],
          'candidates': [
            {
              'index': 0,
              'selector': 'span.title',
              'selectorCandidates': ['span.title'],
              'tag': 'SPAN',
              'label': 'span.title',
              'relationship': '자식 후보',
              'kind': '리프',
              'matchCount': 1,
              'applyAllowed': true,
              'qualityLabel': '정확히 1개 대상',
            },
            {
              'index': 1,
              'selector': 'article.card',
              'selectorCandidates': ['article.card', '.card'],
              'tag': 'ARTICLE',
              'id': 'story',
              'classes': ['card'],
              'label': 'article.card',
              'relationship': '현재 타깃',
              'kind': '컨테이너',
              'matchCount': 2,
              'applyAllowed': true,
              'qualityLabel': '같은 구조 여러 대상',
            },
          ],
          'depthTargets': [
            {
              'index': 0,
              'label': '현재 요소',
              'elementLabel': 'article.card',
              'selector': 'article.card',
              'selectorCandidates': ['article.card', '.card'],
              'tag': 'ARTICLE',
              'matchCount': 2,
              'applyAllowed': true,
              'qualityLabel': '같은 구조 여러 대상',
            },
          ],
        },
        ['article.card', '.card'],
      ]);

      expect(r, isNotNull);
      expect(r!.frameScope, 'https://embed.example/frame');
      expect(r.selectorCandidates, ['article.card', '.card']);
      expect(r.selectedCandidateIndex, 1);
      expect(r.candidates, hasLength(2));
      expect(r.selectedCandidate!.relationship, '현재 타깃');
      expect(r.selectedCandidate!.kind, '컨테이너');
      expect(r.depthTargets, hasLength(1));
      expect(r.selectedDepthTarget!.elementLabel, 'article.card');
    });
  });

  group('applyInfocutterSettings', () {
    test('빈 service 면 contentBlockers 가 빈 리스트', () async {
      final service = InfocutterService();
      // load() 호출 안 함 — empty snapshot 유지
      final settings = InAppWebViewSettings();
      applyInfocutterSettings(settings, service, null);
      expect(settings.contentBlockers, isEmpty);
    });

    test('URL 매칭 시 ContentBlocker 가 채워짐', () async {
      final service = InfocutterService();
      await service.upsertProfile(
        id: 'p1',
        name: 'Example',
        matchers: ['https://example.com/*'],
      );
      await service.addRule(
        profileId: 'p1',
        cardName: '광고',
        selector: '.ad',
      );

      final settings = InAppWebViewSettings();
      applyInfocutterSettings(
        settings,
        service,
        Uri.parse('https://example.com/some/path'),
      );
      expect(settings.contentBlockers, hasLength(1));
      expect(settings.contentBlockers!.first.action.selector, '.ad');
    });

    test('매칭 안 되는 URL 이면 빈 리스트', () async {
      final service = InfocutterService();
      await service.upsertProfile(
        id: 'p1',
        name: 'Example',
        matchers: ['https://example.com/*'],
      );
      await service.addRule(
        profileId: 'p1',
        cardName: '광고',
        selector: '.ad',
      );

      final settings = InAppWebViewSettings();
      applyInfocutterSettings(
        settings,
        service,
        Uri.parse('https://other.test/path'),
      );
      expect(settings.contentBlockers, isEmpty);
    });

    test('같은 host 여도 path matcher 가 다르면 빈 리스트', () async {
      final service = InfocutterService();
      await service.upsertProfile(
        id: 'p1',
        name: 'Example news',
        matchers: ['https://example.com/news/*'],
      );
      await service.addRule(
        profileId: 'p1',
        cardName: '광고',
        selector: '.ad',
      );

      final settings = InAppWebViewSettings();
      applyInfocutterSettings(
        settings,
        service,
        Uri.parse('https://example.com/mail'),
      );
      expect(settings.contentBlockers, isEmpty);
    });

    test('네트워크 필터를 ContentBlocker BLOCK 규칙으로 합친다', () async {
      final infocutter = InfocutterService();
      final networkFilters = NetworkFilterService();
      await networkFilters.importRawList('||ads.example.com^');

      final settings = InAppWebViewSettings();
      applyInfocutterSettings(
        settings,
        infocutter,
        Uri.parse('https://example.com'),
        networkFilters: networkFilters,
      );

      expect(settings.contentBlockers, hasLength(1));
      expect(
        settings.contentBlockers!.first.action.type,
        ContentBlockerActionType.BLOCK,
      );
      expect(
        settings.contentBlockers!.first.trigger.urlFilter,
        contains(r'ads\.example\.com'),
      );
    });

    test('네트워크 허용 필터가 섞이면 과차단 방지를 위해 ContentBlocker 변환을 건너뛴다', () async {
      final infocutter = InfocutterService();
      final networkFilters = NetworkFilterService();
      await networkFilters.importRawList('''
||example.com^
@@||safe.example.com^
''');

      final settings = InAppWebViewSettings();
      applyInfocutterSettings(
        settings,
        infocutter,
        Uri.parse('https://example.com'),
        networkFilters: networkFilters,
      );

      expect(settings.contentBlockers, isEmpty);
    });
  });

  group('buildInfocutterUserScripts', () {
    test('UserScript contributor registry keeps the expected order', () {
      expect(
        infocutterUserScriptContributions
            .map((contribution) => contribution.groupName),
        [
          runtimeUserScriptId,
          pickerUserScriptId,
          watchRuntimeUserScriptId,
          textBlockRuntimeUserScriptId,
          keywordCaptureUserScriptId,
          lazyImagePromoteUserScriptId,
        ],
      );
    });

    test(
        'runtime, picker, watch, text block, keyword-capture, lazy-image UserScript 등록',
        () {
      final scripts = buildInfocutterUserScripts();
      expect(scripts, hasLength(6));
      expect(scripts.map((script) => script.groupName), [
        runtimeUserScriptId,
        pickerUserScriptId,
        watchRuntimeUserScriptId,
        textBlockRuntimeUserScriptId,
        keywordCaptureUserScriptId,
        lazyImagePromoteUserScriptId,
      ]);
      expect(scripts.first.source, infocutterRuntimeUserScriptSource);
      expect(scripts[1].source, pickerUserScriptSource);
      expect(scripts[2].source, infocutterWatchUserScriptSource);
      expect(scripts[3].source, infocutterTextBlockUserScriptSource);
      expect(scripts[4].source, keywordCaptureUserScriptSource);
      expect(scripts.last.source, lazyImagePromoteUserScriptSource);
      // lazy image 는 가능한 한 이르게 붙인다.
      expect(
        scripts.last.injectionTime,
        UserScriptInjectionTime.AT_DOCUMENT_START,
      );
      for (final script in scripts.take(5)) {
        expect(script.injectionTime, UserScriptInjectionTime.AT_DOCUMENT_END);
        expect(script.forMainFrameOnly, isFalse);
      }
      expect(scripts.last.forMainFrameOnly, isFalse);
    });
  });

  group('infocutterRuntimeContributors', () {
    test('manual refresh applies block, text block, then watch runtime', () {
      expect(
        infocutterRuntimeContributors.map((contributor) => contributor.key),
        ['block', 'textBlocks', 'watch'],
      );
    });
  });

  group('setPickerActive', () {
    test('picker가 누락된 기존 WebView 에서는 즉시 재주입 후 다시 시작한다', () {
      final source = File(
        'lib/infocutter/webview_adapter.dart',
      ).readAsStringSync();
      expect(source, contains("result == 'missing' && active"));
      expect(
        source,
        contains(
          'source: infocutterPickerRuntimeUserScriptSource',
        ),
      );
      expect(source, contains('result = await _evaluatePickerToggle'));
    });
  });

  group('infocutter runtime contracts', () {
    test('runtime object names and UserScript sources come from one SSOT', () {
      expect(
        infocutterBlockRuntimeContract.objectName,
        infocutterBlockRuntimeObjectName,
      );
      expect(
        infocutterBlockRuntimeContract.userScriptSource,
        infocutterBlockRuntimeUserScriptSource,
      );
      expect(
        infocutterPickerRuntimeContract.objectName,
        infocutterPickerRuntimeObjectName,
      );
      expect(
        infocutterPickerRuntimeContract.userScriptSource,
        infocutterPickerRuntimeUserScriptSource,
      );
      expect(
        infocutterWatchRuntimeContract.objectName,
        infocutterWatchRuntimeObjectName,
      );
      expect(
        infocutterWatchRuntimeContract.userScriptSource,
        infocutterWatchRuntimeUserScriptSource,
      );
      expect(
        infocutterTextBlockRuntimeContract.objectName,
        infocutterTextBlockRuntimeObjectName,
      );
      expect(
        infocutterTextBlockRuntimeContract.userScriptSource,
        infocutterTextBlockRuntimeUserScriptSource,
      );
      expect(
        infocutterKeywordCaptureRuntimeContract.objectName,
        infocutterKeywordCaptureRuntimeObjectName,
      );
      expect(
        infocutterKeywordCaptureRuntimeContract.userScriptSource,
        infocutterKeywordCaptureRuntimeUserScriptSource,
      );
    });
  });

  group('applyRuntimeState', () {
    test('block/watch/text runtimes apply through the use case abstraction',
        () {
      final source = File(
        'lib/infocutter/webview_adapter.dart',
      ).readAsStringSync();
      expect(source, contains('ApplyInfocutterRuntimeUseCase'));
      expect(source, contains('ApplyInfocutterRuntimeCommand'));
      expect(source, contains('InAppWebViewRuntimePage(controller)'));
      expect(source, contains('infocutterBlockRuntimeObjectName'));
      expect(source, contains('infocutterWatchRuntimeObjectName'));
      expect(source, contains('infocutterTextBlockRuntimeObjectName'));
      expect(source, contains('infocutterWatchRuntimeUserScriptSource'));
      expect(source, contains('infocutterTextBlockRuntimeUserScriptSource'));
    });
  });

  group('Infocutter network filter refresh', () {
    test('네트워크 필터 변경은 현재 페이지를 reload 하도록 분리한다', () {
      // reload: true 호출은 part 파일에 있다 (webview_tab.dart 본문 길이 상한).
      final webViewTabSource = [
        File('lib/webview_tab.dart').readAsStringSync(),
        File('lib/webview_tab_infocutter.dart').readAsStringSync(),
      ].join('\n');
      final coordinatorSource = File(
        'lib/infocutter/infocutter_webview_coordinator.dart',
      ).readAsStringSync();
      final runtimeApplierSource = File(
        'lib/infocutter/infocutter_runtime_applier.dart',
      ).readAsStringSync();
      final sidebarModulesSource = File(
        'lib/infocutter/ui/infocutter_sidebar_modules.dart',
      ).readAsStringSync();

      expect(
        webViewTabSource,
        contains('refreshForCurrentUrl(reload: true)'),
      );
      expect(coordinatorSource, contains('bool reload = false'));
      expect(
        coordinatorSource,
        contains('refreshForCurrentUrl(_controller(), reload: reload)'),
      );
      expect(runtimeApplierSource, contains('await controller.reload()'));
      expect(
        sidebarModulesSource,
        contains('actions.onNetworkFiltersChanged'),
      );
    });
  });

  group('infocutterRuntimeUserScriptSource', () {
    test('DOM marker 기반 runtime 렌더링을 포함한다', () {
      expect(
        infocutterRuntimeUserScriptSource,
        contains("var HIDDEN_ATTR = 'data-infocutter-hidden';"),
      );
      expect(infocutterRuntimeUserScriptSource, contains('MutationObserver'));
      expect(
        infocutterRuntimeUserScriptSource,
        contains('window.__infocutterRuntime'),
      );
      expect(infocutterRuntimeUserScriptSource, contains('apply: function'));
      expect(infocutterRuntimeUserScriptSource, contains('setPeek: function'));
      expect(
        infocutterRuntimeUserScriptSource,
        contains('target.contains(exception)'),
      );
      expect(
        infocutterRuntimeUserScriptSource,
        contains('exception.contains(target)'),
      );
      expect(infocutterRuntimeUserScriptSource, contains('currentFrameScope'));
      expect(
        infocutterRuntimeUserScriptSource,
        contains('(rule.frameScope || null) === frameScope'),
      );
    });
  });

  group('pickerUserScriptSource', () {
    test('컷모드에서는 페이지 포인터 이벤트를 삼킨다', () {
      expect(pickerUserScriptSource, contains('ensureOverlay()'));
      expect(
        pickerUserScriptSource,
        contains(
            "overlay.addEventListener('mousedown', handlePointerStart, true)"),
      );
      expect(
        pickerUserScriptSource,
        contains("overlay.addEventListener('mouseup', handlePointerEnd, true)"),
      );
      expect(
        pickerUserScriptSource,
        contains("overlay.addEventListener('click', handleClick, true)"),
      );
      expect(
        pickerUserScriptSource,
        contains("document.addEventListener('pointerdown', handlePointerStart"),
      );
      expect(
        pickerUserScriptSource,
        contains("document.addEventListener('contextmenu', handleBlockedEvent"),
      );
      expect(pickerUserScriptSource, contains('e.preventDefault();'));
      expect(pickerUserScriptSource, contains('e.stopPropagation();'));
      expect(pickerUserScriptSource, contains('e.stopImmediatePropagation();'));
      expect(
        pickerUserScriptSource,
        contains("blocker.style.pointerEvents = 'none';"),
      );
      expect(pickerUserScriptSource, contains('document.elementsFromPoint'));
      expect(pickerUserScriptSource, contains('candidateTargetScore'));
      expect(pickerUserScriptSource, contains('depthTargets'));
      expect(
          pickerUserScriptSource, contains('frameScope: currentFrameScope()'));
    });

    test('기본 선택은 작은 leaf보다 숨길 만한 블록 depth를 우선한다', () {
      expect(
        pickerUserScriptSource,
        contains('selectorCandidateScoreForHiding'),
      );
      expect(pickerUserScriptSource, contains('sortSelectorsForHiding(out)'));
      expect(pickerUserScriptSource, contains('depthTargetScore'));
      expect(pickerUserScriptSource, contains('chooseDefaultDepthIndex'));
      expect(
        pickerUserScriptSource,
        contains('selectedDepthIndex = chooseDefaultDepthIndex(depthChain)'),
      );
      expect(
        pickerUserScriptSource,
        contains(
            'selectorScore = Math.min(selectorSpecificityScore(selector), 80)'),
      );
    });
  });

  group('infocutterWatchUserScriptSource', () {
    test('watch runtime scans text, reports detections, and can auto-mask', () {
      expect(infocutterWatchUserScriptSource, contains('__infocutterWatch'));
      expect(infocutterWatchUserScriptSource, contains('MutationObserver'));
      expect(
        infocutterWatchUserScriptSource,
        contains("var HIDDEN_ATTR = 'data-infocutter-watch-hidden';"),
      );
      expect(
        infocutterWatchUserScriptSource,
        contains("callHandler('infocutter.watchDetection'"),
      );
      expect(infocutterWatchUserScriptSource, contains('autoMask'));
    });
  });

  group('infocutterTextBlockUserScriptSource', () {
    test('text block runtime groups matching text and hides repeated blocks',
        () {
      expect(
        infocutterTextBlockUserScriptSource,
        contains('__infocutterTextBlocks'),
      );
      expect(
        infocutterTextBlockUserScriptSource,
        contains("var HIDDEN_ATTR = 'data-infocutter-text-block-hidden';"),
      );
      expect(infocutterTextBlockUserScriptSource, contains('MutationObserver'));
      expect(infocutterTextBlockUserScriptSource, contains('minMatchCount'));
      expect(infocutterTextBlockUserScriptSource, contains('fingerprint'));
      expect(infocutterTextBlockUserScriptSource, contains('nextTargetSet'));
      expect(
          infocutterTextBlockUserScriptSource, isNot(contains('clearMarkers')));
    });
  });
}
