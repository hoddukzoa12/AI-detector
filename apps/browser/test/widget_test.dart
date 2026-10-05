import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/custom_popup_menu_item.dart';
import 'package:infocutter_app/empty_tab.dart';
import 'package:infocutter_app/infocutter/application/block_rules/infocutter_service_block_rule_repository.dart';
import 'package:infocutter_app/infocutter/application/block_rules/save_picked_block_rule_use_case.dart';
import 'package:infocutter_app/infocutter/ai_config_service.dart';
import 'package:infocutter_app/infocutter/ai_masking_service.dart';
import 'package:infocutter_app/infocutter/ai_rule_service.dart';
import 'package:infocutter_app/infocutter/evidence_service.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/network_filter_service.dart';
import 'package:infocutter_app/infocutter/storage.dart';
import 'package:infocutter_app/infocutter/text_block_service.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_ai_settings_panel.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_evidence_tab.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_network_filter_panel.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_rule_manager.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_sidebar_widgets.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_text_block_panel.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_watch_tab.dart';
import 'package:infocutter_app/infocutter/webview_integration.dart';
import 'package:infocutter_app/infocutter/watch_service.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/pages/settings/cross_platform_settings.dart';
import 'package:provider/provider.dart';

void main() {
  test('infocutter_app placeholder smoke test', () {
    expect(1 + 1, equals(2));
  });

  testWidgets('cross platform settings renders Korean default site control',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BrowserModel()),
          ChangeNotifierProvider(create: (_) => WindowModel()),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CrossPlatformSettings(
              defaultUserAgentLoader: _fakeDefaultUserAgent,
              currentWebViewPackageLoader: _fakeCurrentWebViewPackage,
            ),
          ),
        ),
      ),
    );

    expect(find.text('일반 설정'), findsOneWidget);
    expect(find.text('테마 모드'), findsOneWidget);
    expect(find.text('시스템 설정 따르기'), findsWidgets);
    expect(find.text('검색 엔진'), findsWidgets);
    expect(find.text('기본 사이트'), findsWidgets);
    expect(find.text('Google'), findsWidgets);
  });

  testWidgets('empty tab uses Infocutter home branding', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BrowserModel()),
          ChangeNotifierProvider(create: (_) => WindowModel()),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EmptyTab(),
        ),
      ),
    );

    expect(find.text('인포커터'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/icon/icon.png',
      ),
      findsOneWidget,
    );
    expect(find.text('검색어나 웹 주소를 입력하세요'), findsOneWidget);
  });

  testWidgets('popup icon toolbar fits desktop menu width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: CustomPopupMenuItem<void>(
                isIconButtonRow: true,
                child: Row(
                  children: List.generate(
                    8,
                    (index) => SizedBox(
                      width: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.content_cut),
                        onPressed: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('infocutter selected target summary names selected element',
      (tester) async {
    final result = PickerResult(
      selector: 'article.card',
      tag: 'ARTICLE',
      id: 'story',
      classes: const ['card'],
      matchCount: 2,
      alternatives: const [],
      selectorCandidates: const ['article.card', '.card'],
      candidates: const [
        PickerCandidate(
          index: 0,
          selector: 'article.card',
          selectorCandidates: ['article.card', '.card'],
          tag: 'ARTICLE',
          id: 'story',
          classes: ['card'],
          label: 'article.card',
          relationship: '현재 타깃',
          kind: '컨테이너',
          matchCount: 2,
          applyAllowed: true,
          qualityLabel: '같은 구조 여러 대상',
        ),
      ],
      depthTargets: const [
        PickerDepthTarget(
          index: 0,
          label: '현재 요소',
          elementLabel: 'article.card',
          selector: 'article.card',
          selectorCandidates: ['article.card', '.card'],
          tag: 'ARTICLE',
          id: 'story',
          classes: ['card'],
          matchCount: 2,
          applyAllowed: true,
          qualityLabel: '같은 구조 여러 대상',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InfocutterSelectedTargetSummary(
            result: result,
            selectedSelector: 'article.card',
            selectedCandidateIndex: 0,
            selectedDepthIndex: 0,
            canUseDepthTargets: true,
            matchCount: 2,
          ),
        ),
      ),
    );

    expect(find.text('선택한 대상'), findsOneWidget);
    expect(find.text('선택됨'), findsOneWidget);
    expect(find.text('article.card'), findsWidgets);
    expect(find.text('현재 요소'), findsOneWidget);
    expect(find.text('같은 구조 여러 대상'), findsOneWidget);
    expect(find.text('매치 2개'), findsOneWidget);
  });

  testWidgets('infocutter rule manager renders profiles', (tester) async {
    final service = InfocutterService(store: _MemoryInfocutterStore());
    await service.upsertProfile(
      id: 'p1',
      name: 'Example',
      matchers: ['https://example.com/*'],
    );
    await service.addRule(
      profileId: 'p1',
      cardName: 'Ads',
      selector: '.ad',
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InfocutterRuleManager(
            repository: InfocutterServiceBlockRuleRepository(service),
            url: Uri.parse('https://example.com/news/1'),
          ),
        ),
      ),
    );

    expect(find.text('인포커터 전역 사용'), findsOneWidget);
    expect(find.text('프로필 1개'), findsOneWidget);
    expect(find.text('Example'), findsOneWidget);
  });

  testWidgets(
      'infocutter current site rule manager filters profiles and hides active profile cards',
      (tester) async {
    final service = InfocutterService(store: _MemoryInfocutterStore());
    await service.upsertProfile(
      id: 'p1',
      name: 'Example',
      matchers: ['https://example.com/*'],
    );
    await service.addRule(
      profileId: 'p1',
      cardName: 'Ads',
      selector: '.ad',
    );
    await service.upsertProfile(
      id: 'p2',
      name: 'Other',
      matchers: ['https://other.test/*'],
    );
    await service.addRule(
      profileId: 'p2',
      cardName: 'Other Ads',
      selector: '.other-ad',
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InfocutterRuleManager(
            currentSiteOnly: true,
            repository: InfocutterServiceBlockRuleRepository(service),
            url: Uri.parse('https://example.com/news/1'),
          ),
        ),
      ),
    );

    // Only the matching profile is shown (current-site filter).
    expect(find.text('Example'), findsOneWidget);
    expect(find.text('Other'), findsNothing);

    // Example is the active profile for this site, so its cards are hidden in
    // the 숨긴 목록 view (they are edited in the 「고르기」 tab) and a hint is
    // shown in their place.
    await tester.tap(find.text('Example'));
    await tester.pumpAndSettle();
    expect(find.text('Ads'), findsNothing);
    expect(
      find.text("이 프로필의 카드는 '고르기' 탭에서 편집합니다"),
      findsOneWidget,
    );
  });

  testWidgets('infocutter delete confirmation can cancel destructive actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  final confirmed =
                      await showInfocutterDeleteConfirmation(context);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('confirmed: $confirmed')),
                  );
                },
                child: const Text('delete'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.text('confirmed: false'), findsOneWidget);
  });

  testWidgets('infocutter Chrome JSON import warns and requires pasted JSON',
      (tester) async {
    final service = InfocutterService(store: _MemoryInfocutterStore());

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InfocutterRuleManager(
            repository: InfocutterServiceBlockRuleRepository(service),
            url: Uri.parse('https://example.com/news/1'),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Chrome JSON 가져오기'));
    await tester.pumpAndSettle();

    expect(find.text('주의: 가져오면 지금 저장된 규칙을 덮어씁니다'), findsOneWidget);
    final importFinder = find.widgetWithText(FilledButton, 'Chrome JSON 가져오기');
    expect(tester.widget<FilledButton>(importFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '{"rules":[]}');
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(importFinder).onPressed, isNotNull);
  });

  testWidgets(
      'infocutter rule manager previews a stored hidden block from row tap',
      (tester) async {
    final service = InfocutterService(store: _MemoryInfocutterStore());
    StoredRule? previewedRule;
    await service.upsertProfile(
      id: 'p1',
      name: 'Example',
      matchers: ['https://example.com/*'],
    );
    await service.addRule(
      profileId: 'p1',
      cardName: 'Ads',
      selector: '.ad',
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InfocutterRuleManager(
            // The full manager (current-site filter off — the default) still
            // shows every card, so a rule row remains tappable for preview. The
            // current-site 숨긴 목록 moves active-profile cards to 「고르기」.
            onPreviewRule: (rule) async {
              previewedRule = rule;
            },
            repository: InfocutterServiceBlockRuleRepository(service),
            url: Uri.parse('https://example.com/news/1'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Example'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ads'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('.ad'));
    await tester.pumpAndSettle();

    expect(previewedRule?.selector, '.ad');
  });

  testWidgets('text block rule row tap toggles the rule', (tester) async {
    final service = TextBlockService(store: _MemoryTextBlockStore());
    var refreshCount = 0;
    await service.addRuleForUrl(
      TextBlockRuleRequest(
        url: Uri.parse('https://example.com/news/1'),
        keyword: 'Sponsored',
        objectName: 'Ads',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<TextBlockService>.value(
        value: service,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InfocutterTextBlockPanel(
              showHeader: false,
              url: Uri.parse('https://example.com/news/1'),
              onTextBlocksChanged: () async {
                refreshCount += 1;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ads'));
    await tester.pumpAndSettle();

    expect(service.profiles.single.rules.single.enabled, isFalse);
    expect(refreshCount, 1);
  });

  testWidgets('text block add button waits for valid required input',
      (tester) async {
    final service = TextBlockService(store: _MemoryTextBlockStore());

    await tester.pumpWidget(
      ChangeNotifierProvider<TextBlockService>.value(
        value: service,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InfocutterTextBlockPanel(
              showHeader: false,
              url: Uri.parse('https://example.com/news/1'),
              onTextBlocksChanged: () async {},
            ),
          ),
        ),
      ),
    );

    final addFinder = find.widgetWithText(FilledButton, '텍스트 블록 규칙 추가');
    expect(tester.widget<FilledButton>(addFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Sponsored');
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(addFinder).onPressed, isNotNull);

    await tester.enterText(find.byType(TextField).at(2), '1');
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(addFinder).onPressed, isNull);
  });

  testWidgets('network filter rule row tap toggles the rule', (tester) async {
    final service = NetworkFilterService(store: _MemoryNetworkFilterStore());
    var refreshCount = 0;
    await service.importRawList(r'||ads.example.com^');

    await tester.pumpWidget(
      ChangeNotifierProvider<NetworkFilterService>.value(
        value: service,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InfocutterNetworkFilterPanel(
              showHeader: false,
              onNetworkFiltersChanged: () async {
                refreshCount += 1;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text(r'||ads.example.com^'));
    await tester.pumpAndSettle();

    expect(service.rules.single.enabled, isFalse);
    expect(refreshCount, 1);
  });

  testWidgets('watch rows support tap actions', (tester) async {
    final service = WatchService(store: _MemoryWatchStore());
    var refreshCount = 0;
    WatchDetection? captured;
    await service.addTarget(name: 'Jane Doe');
    final detection = WatchDetection.tryParse([
      {
        'targetId': 't1',
        'term': 'Sensitive term',
        'url': 'https://example.com',
        'pageTitle': 'Example',
        'matchedText': 'Hello Sensitive term',
        'tag': 'p',
      }
    ])!;
    service.recordDetection(detection);

    await tester.pumpWidget(
      ChangeNotifierProvider<WatchService>.value(
        value: service,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InfocutterWatchTab(
              onCaptureDetectionEvidence: (detection) async {
                captured = detection;
              },
              onWatchChanged: () async {
                refreshCount += 1;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Sensitive term'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jane Doe'));
    await tester.pumpAndSettle();

    expect(captured?.term, 'Sensitive term');
    expect(service.targets.single.enabled, isFalse);
    expect(refreshCount, 1);
  });

  testWidgets('watch add button waits for a target name', (tester) async {
    final service = WatchService(store: _MemoryWatchStore());

    await tester.pumpWidget(
      ChangeNotifierProvider<WatchService>.value(
        value: service,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InfocutterWatchTab(
              onCaptureDetectionEvidence: (_) async {},
              onWatchChanged: () async {},
            ),
          ),
        ),
      ),
    );

    final addFinder = find.widgetWithText(FilledButton, '감시 대상 추가');
    expect(tester.widget<FilledButton>(addFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Jane Doe');
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(addFinder).onPressed, isNotNull);
  });

  testWidgets('evidence capture failure unlocks the capture button',
      (tester) async {
    final service = EvidenceService(store: _MemoryEvidenceStore());
    await service.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<EvidenceService>.value(
        value: service,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InfocutterEvidenceTab(
              onCaptureEvidence: () async {
                throw StateError('capture failed');
              },
            ),
          ),
        ),
      ),
    );

    final captureFinder = find.widgetWithText(FilledButton, '현재 페이지 캡처 저장');
    await tester.tap(captureFinder);
    await tester.pumpAndSettle();

    expect(find.text('페이지 캡처를 저장하지 못했습니다'), findsOneWidget);
    expect(tester.widget<FilledButton>(captureFinder).onPressed, isNotNull);
  });

  testWidgets('AI suggestion row tap applies the suggestion', (tester) async {
    final infocutter = InfocutterService(store: _MemoryInfocutterStore());
    final aiRules = AiRuleService(store: _MemoryAiRuleStore());
    var refreshCount = 0;
    await aiRules.addSuggestions(
      url: Uri.parse('https://example.com/news/1'),
      suggestions: const [
        AiMaskingSuggestion(selector: '.ad', label: 'Ads'),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AiConfigService>(
            create: (_) => AiConfigService(
              secretStore: _MemoryAiSecretStore(),
              store: _MemoryAiConfigStore(),
            ),
          ),
          ChangeNotifierProvider<AiRuleService>.value(value: aiRules),
          Provider<SavePickedBlockRuleUseCase>(
            create: (_) => SavePickedBlockRuleUseCase(
              InfocutterServiceBlockRuleRepository(infocutter),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InfocutterAiSettingsPanel(
              showHeader: false,
              url: Uri.parse('https://example.com/news/1'),
              onAnalyzeCurrentPage: () async => const <AiPageCandidate>[],
              onRulesChanged: () async {
                refreshCount += 1;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ads'));
    await tester.pumpAndSettle();

    expect(infocutter.profiles.single.rules.single.selector, '.ad');
    expect(aiRules.rules.single.applied, isTrue);
    expect(refreshCount, 1);
  });
}

Future<String> _fakeDefaultUserAgent() async {
  return 'InfoCutter Test Agent';
}

Future<WebViewPackageInfo?> _fakeCurrentWebViewPackage() async {
  return null;
}

class _MemoryInfocutterStore implements InfocutterStore {
  String? raw;

  @override
  Future<String?> loadRuleStoreJson() async => raw;

  @override
  Future<void> saveRuleStoreJson(String raw) async {
    this.raw = raw;
  }
}

class _MemoryTextBlockStore implements TextBlockStore {
  String? raw;

  @override
  Future<String?> loadTextBlockStoreJson() async => raw;

  @override
  Future<void> saveTextBlockStoreJson(String raw) async {
    this.raw = raw;
  }
}

class _MemoryNetworkFilterStore implements NetworkFilterStore {
  String? raw;

  @override
  Future<String?> loadNetworkFilterStoreJson() async => raw;

  @override
  Future<void> saveNetworkFilterStoreJson(String raw) async {
    this.raw = raw;
  }
}

class _MemoryWatchStore implements WatchStore {
  String? raw;

  @override
  Future<String?> loadWatchStoreJson() async => raw;

  @override
  Future<void> saveWatchStoreJson(String raw) async {
    this.raw = raw;
  }
}

class _MemoryEvidenceStore implements EvidenceStore {
  String? raw;

  @override
  Future<String?> loadEvidenceJson() async => raw;

  @override
  Future<void> saveEvidenceJson(String raw) async {
    this.raw = raw;
  }
}

class _MemoryAiRuleStore implements AiRuleStore {
  String? raw;

  @override
  Future<String?> loadAiRuleStoreJson() async => raw;

  @override
  Future<void> saveAiRuleStoreJson(String raw) async {
    this.raw = raw;
  }
}

class _MemoryAiConfigStore implements AiConfigStore {
  String? raw;

  @override
  Future<String?> loadAiConfigJson() async => raw;

  @override
  Future<void> saveAiConfigJson(String raw) async {
    this.raw = raw;
  }
}

class _MemoryAiSecretStore implements AiSecretStore {
  String? apiKey;

  @override
  Future<void> deleteApiKey() async {
    apiKey = null;
  }

  @override
  Future<String?> readApiKey() async => apiKey;

  @override
  Future<void> writeApiKey(String value) async {
    apiKey = value;
  }
}
