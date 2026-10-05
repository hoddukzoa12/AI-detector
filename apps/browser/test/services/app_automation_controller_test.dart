import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/application/block_rules/infocutter_service_block_rule_repository.dart';
import 'package:infocutter_app/infocutter/application/block_rules/save_picked_block_rule_use_case.dart';
import 'package:infocutter_app/infocutter/ai_config_service.dart';
import 'package:infocutter_app/infocutter/ai_masking_service.dart';
import 'package:infocutter_app/infocutter/ai_rule_service.dart';
import 'package:infocutter_app/infocutter/evidence_service.dart';
import 'package:infocutter_app/infocutter/infocutter_panel_mode.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/infocutter/network_filter_service.dart';
import 'package:infocutter_app/infocutter/storage.dart';
import 'package:infocutter_app/infocutter/text_block_service.dart';
import 'package:infocutter_app/infocutter/watch_service.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/services/app_automation_bridge.dart';
import 'package:infocutter_app/services/app_automation_controller.dart';

void main() {
  test('snapshot exposes AI-readable app state and capabilities', () {
    final harness = _AutomationHarness();
    harness.window.addTab(
      _webView(url: 'https://example.com/news', title: 'Example'),
    );

    final snapshot = harness.controller.snapshot();

    expect(snapshot['capabilities'], contains('tab.open'));
    expect(snapshot['capabilities'], contains('infocutter.addBlockRule'));
    expect((snapshot['window'] as Map)['tabCount'], 1);
    expect((snapshot['currentTab'] as Map)['url'], 'https://example.com/news');
    expect((snapshot['infocutter'] as Map)['templates'], isNotEmpty);
  });

  test('automation capabilities are unique', () {
    expect(
      AppAutomationController.capabilities.toSet(),
      hasLength(AppAutomationController.capabilities.length),
    );
  });

  test('capabilities list contains infocutter.session.setDepth', () {
    expect(
      AppAutomationController.capabilities,
      contains('infocutter.session.setDepth'),
    );
  });

  test('capabilities list contains textBlock.setCaptureMode', () {
    expect(
      AppAutomationController.capabilities,
      contains('textBlock.setCaptureMode'),
    );
  });

  test('run dispatch opens and selects tabs', () async {
    final harness = _AutomationHarness();

    final open = await harness.controller.run('tab.open', {
      'target': 'example.com',
    });
    await harness.controller.run('tab.open', {
      'target': 'search term',
      'incognito': true,
    });
    final select = await harness.controller.run('tab.select', {'index': 0});

    expect(open.ok, isTrue);
    expect(open.data['url'], 'https://example.com');
    expect(select.ok, isTrue);
    expect(harness.window.webViewModels, hasLength(2));
    expect(harness.window.getCurrentTabIndex(), 0);
  });

  test('run dispatch controls Infocutter rules and automation stores',
      () async {
    final harness = _AutomationHarness();
    harness.window.addTab(_webView(url: 'https://example.com/page'));

    final block = await harness.controller.run('infocutter.addBlockRule', {
      'selector': '.ad',
      'cardName': 'Ads',
    });
    final text = await harness.controller.run('textBlock.addRule', {
      'keyword': 'Sponsored',
      'objectName': 'Sponsored cards',
      'minMatchCount': 3,
    });
    final watch = await harness.controller.run('watch.addTarget', {
      'name': 'Jane Doe',
      'aliases': ['J. Doe'],
    });
    final network = await harness.controller.run('network.importFilters', {
      'rawList': '||ads.example.com^',
    });
    final ai = await harness.controller.run('ai.config', {
      'endpoint': 'https://example.com/ai',
      'apiKey': 'secret',
      'model': 'gpt-test',
    });

    expect(block.ok, isTrue);
    expect(harness.infocutter.profiles.single.rules.single.selector, '.ad');
    expect(text.ok, isTrue);
    expect(
        harness.textBlocks.profiles.single.rules.single.keyword, 'Sponsored');
    expect(watch.ok, isTrue);
    expect(harness.watch.targets.single.name, 'Jane Doe');
    expect(network.data['imported'], 1);
    expect(ai.data['configured'], isTrue);
  });

  test('unsupported commands fail without throwing', () async {
    final harness = _AutomationHarness();

    final result = await harness.controller.run('missing.command');

    expect(result.ok, isFalse);
    expect(result.error, contains('unsupported action'));
  });

  test('failures expose a stable machine-readable code', () async {
    final harness = _AutomationHarness();

    // Unsupported action -> 'unsupported_action'.
    final unsupported = await harness.controller.run('missing.command');
    expect(unsupported.ok, isFalse);
    expect(unsupported.code, 'unsupported_action');
    expect(unsupported.toJson()['code'], 'unsupported_action');

    // No current tab/controller -> 'no_current_tab' (no tab is open).
    final noTab = await harness.controller.run('page.reload');
    expect(noTab.ok, isFalse);
    expect(noTab.code, 'no_current_tab');

    // Controller missing on an open tab -> 'no_controller'.
    harness.window.addTab(_webView(url: 'https://example.com/page'));
    final noController = await harness.controller.run('page.reload');
    expect(noController.ok, isFalse);
    expect(noController.code, 'no_controller');

    // Out-of-range tab index -> 'out_of_range'.
    final outOfRange = await harness.controller.run('tab.select', {
      'index': 99,
    });
    expect(outOfRange.ok, isFalse);
    expect(outOfRange.code, 'out_of_range');
  });

  test(
      'addBlockRule returns addressing and created flag; listProfiles '
      'exposes rule contents; removeRule deletes it', () async {
    final harness = _AutomationHarness();
    harness.window.addTab(_webView(url: 'https://example.com/page'));

    final add = await harness.controller.run('infocutter.addBlockRule', {
      'selector': '.ad',
      'cardName': 'Ads',
    });
    expect(add.ok, isTrue, reason: add.error);
    expect(add.data['created'], isTrue);
    final profileId = add.data['profileId'] as String;
    final cardId = add.data['cardId'] as String;
    expect(profileId, isNotEmpty);
    expect(cardId, isNotEmpty);

    final again = await harness.controller.run('infocutter.addBlockRule', {
      'selector': '.ad',
      'cardName': 'Ads',
    });
    expect(again.data['created'], isFalse);

    final list = await harness.controller.run('infocutter.listProfiles');
    final profiles = list.data['profiles'] as List;
    final profile =
        profiles.firstWhere((p) => (p as Map)['id'] == profileId) as Map;
    final rules = profile['rules'] as List;
    expect(rules.any((r) => (r as Map)['selector'] == '.ad'), isTrue);

    final remove = await harness.controller.run('infocutter.removeRule', {
      'profileId': profileId,
      'cardId': cardId,
      'selector': '.ad',
    });
    expect(remove.ok, isTrue, reason: remove.error);
    expect(remove.data['removed'], isTrue);
    expect(
      harness.infocutter.profiles.firstWhere((p) => p.id == profileId).rules,
      isEmpty,
    );
  });

  test('infocutter.addBlockRule uses shared save policy', () async {
    final harness = _AutomationHarness();
    harness.window.addTab(_webView(url: 'https://example.com/page'));

    final add = await harness.controller.run('infocutter.addBlockRule', {
      'selector': '  .promo  ',
      'cardName': '   ',
    });

    expect(add.ok, isTrue, reason: add.error);
    expect(add.data['selector'], '.promo');
    expect(add.data['cardName'], 'example.com');
    expect(harness.infocutter.profiles.single.rules.single.selector, '.promo');
  });

  test('infocutter.setCardEnabled, setProfileEnabled and removeProfile',
      () async {
    final harness = _AutomationHarness();
    harness.window.addTab(_webView(url: 'https://example.com/page'));
    final add = await harness.controller.run('infocutter.addBlockRule', {
      'selector': '.x',
    });
    final profileId = add.data['profileId'] as String;
    final cardId = add.data['cardId'] as String;

    final cardOff = await harness.controller.run('infocutter.setCardEnabled', {
      'profileId': profileId,
      'cardId': cardId,
      'enabled': false,
    });
    expect(cardOff.ok, isTrue, reason: cardOff.error);
    expect(
      harness.infocutter.profiles
          .firstWhere((p) => p.id == profileId)
          .cards
          .firstWhere((c) => c.id == cardId)
          .enabled,
      isFalse,
    );

    final disable = await harness.controller.run(
      'infocutter.setProfileEnabled',
      {'profileId': profileId, 'enabled': false},
    );
    expect(disable.ok, isTrue, reason: disable.error);
    expect(
      harness.infocutter.profiles.firstWhere((p) => p.id == profileId).enabled,
      isFalse,
    );

    final removed = await harness.controller.run('infocutter.removeProfile', {
      'profileId': profileId,
    });
    expect(removed.data['removed'], isTrue);
    expect(harness.infocutter.profiles.any((p) => p.id == profileId), isFalse);
  });

  test('watch list/remove/enable round trip', () async {
    final harness = _AutomationHarness();
    final add = await harness.controller.run('watch.addTarget', {
      'name': 'Jane Doe',
      'aliases': ['J. Doe'],
    });
    final id = add.data['id'] as String;

    final list = await harness.controller.run('watch.listTargets');
    final targets = list.data['targets'] as List;
    expect(targets.single, containsPair('name', 'Jane Doe'));

    await harness.controller.run('watch.setTargetEnabled', {
      'id': id,
      'enabled': false,
    });
    expect(harness.watch.targets.single.enabled, isFalse);

    final remove = await harness.controller.run('watch.removeTarget', {
      'id': id,
    });
    expect(remove.data['removed'], isTrue);
    expect(harness.watch.targets, isEmpty);
  });

  test('textBlock list/remove/enable round trip', () async {
    final harness = _AutomationHarness();
    harness.window.addTab(_webView(url: 'https://example.com/page'));
    final add = await harness.controller.run('textBlock.addRule', {
      'keyword': 'Sponsored',
      'minMatchCount': 3,
    });
    final ruleId = add.data['id'] as String;

    final list = await harness.controller.run('textBlock.listRules');
    final profiles = list.data['profiles'] as List;
    final profileId = (profiles.first as Map)['id'] as String;
    final listedRules = (profiles.first as Map)['rules'] as List;
    expect((listedRules.single as Map)['keyword'], 'Sponsored');

    await harness.controller.run('textBlock.setRuleEnabled', {
      'profileId': profileId,
      'ruleId': ruleId,
      'enabled': false,
    });
    expect(harness.textBlocks.profiles.first.rules.single.enabled, isFalse);

    final remove = await harness.controller.run('textBlock.removeRule', {
      'profileId': profileId,
      'ruleId': ruleId,
    });
    expect(remove.data['removed'], isTrue);
    expect(harness.textBlocks.profiles.first.rules, isEmpty);
  });

  test('network list/remove/enable round trip', () async {
    final harness = _AutomationHarness();
    final imp = await harness.controller.run('network.importFilters', {
      'rawList': '||ads.example.com^',
    });
    expect(imp.data['imported'], 1);

    final list = await harness.controller.run('network.listRules');
    final rules = list.data['rules'] as List;
    expect(rules, hasLength(1));
    final id = (rules.single as Map)['id'] as String;

    await harness.controller.run('network.setRuleEnabled', {
      'id': id,
      'enabled': false,
    });
    expect(harness.networkFilters.rules.single.enabled, isFalse);

    final remove = await harness.controller.run('network.removeRule', {
      'id': id,
    });
    expect(remove.data['removed'], isTrue);
    expect(harness.networkFilters.rules, isEmpty);
  });

  test(
      'requiredInt coerces JSON double and numeric string; rejects '
      'non-integral', () async {
    final harness = _AutomationHarness();
    await harness.controller.run('tab.open', {'target': 'a.com'});
    await harness.controller.run('tab.open', {'target': 'b.com'});

    final byDouble = await harness.controller.run('tab.select', {'index': 0.0});
    expect(byDouble.ok, isTrue, reason: byDouble.error);
    expect(harness.window.getCurrentTabIndex(), 0);

    final byString = await harness.controller.run('tab.select', {'index': '1'});
    expect(byString.ok, isTrue, reason: byString.error);
    expect(harness.window.getCurrentTabIndex(), 1);

    final bad = await harness.controller.run('tab.select', {'index': 1.5});
    expect(bad.ok, isFalse);
  });

  test('ai.listSuggestions returns pending suggestions for the current host',
      () async {
    final harness = _AutomationHarness();
    harness.window.addTab(_webView(url: 'https://example.com/page'));
    await harness.aiRules.addSuggestions(
      url: Uri.parse('https://example.com/page'),
      suggestions: const [
        AiMaskingSuggestion(
          selector: '.promo',
          label: 'Promo',
          reason: 'advert',
          confidence: 0.9,
        ),
      ],
    );

    final list = await harness.controller.run('ai.listSuggestions');
    expect(list.ok, isTrue, reason: list.error);
    final suggestions = list.data['suggestions'] as List;
    expect(suggestions.single, containsPair('selector', '.promo'));
    expect(suggestions.single, containsPair('applied', false));
  });

  test('ai.applySuggestion adds a hide rule and marks the suggestion applied',
      () async {
    final harness = _AutomationHarness();
    harness.window.addTab(_webView(url: 'https://example.com/page'));
    await harness.aiRules.addSuggestions(
      url: Uri.parse('https://example.com/page'),
      suggestions: const [AiMaskingSuggestion(selector: '.promo')],
    );

    final apply = await harness.controller.run('ai.applySuggestion', {
      'selector': '.promo',
    });
    expect(apply.ok, isTrue, reason: apply.error);
    expect(apply.data['profileId'], isNotEmpty);

    expect(
      harness.infocutter.profiles
          .expand((p) => p.rules)
          .any((r) => r.selector == '.promo'),
      isTrue,
    );
    expect(harness.aiRules.rulesForHost('example.com').single.applied, isTrue);
  });

  test('page interaction commands are wired and need a live controller',
      () async {
    final harness = _AutomationHarness();
    harness.window.addTab(_webView(url: 'https://example.com/page'));

    for (final action in const [
      'page.click',
      'page.fill',
      'page.getText',
      'page.waitForSelector',
    ]) {
      final args = action == 'page.fill'
          ? {'selector': '.x', 'value': 'hi'}
          : {'selector': '.x'};
      final res = await harness.controller.run(action, args);
      expect(res.ok, isFalse, reason: action);
      expect(res.error, contains('controller'),
          reason: '$action: ${res.error}');
    }
  });

  test('page.candidates is wired and needs a live controller', () async {
    final harness = _AutomationHarness();
    harness.window.addTab(_webView(url: 'https://example.com/page'));

    expect(
      AppAutomationController.capabilities,
      contains('page.candidates'),
    );

    final res = await harness.controller.run('page.candidates');
    expect(res.ok, isFalse);
    expect(res.error, contains('controller'));
    expect(res.code, 'no_controller');
  });

  test('page.waitForLoad reports a loaded tab', () async {
    final harness = _AutomationHarness();
    harness.window.addTab(_webView(url: 'https://example.com/page'));

    final res = await harness.controller.run('page.waitForLoad', {
      'timeoutMs': 1000,
    });

    expect(res.ok, isTrue, reason: res.error);
    expect(res.data['loaded'], isTrue);
  });

  test('infocutter.pick is wired and needs a live controller', () async {
    final harness = _AutomationHarness();
    harness.window.addTab(_webView(url: 'https://example.com/page'));

    final res = await harness.controller.run('infocutter.pick', {
      'selector': '.ad',
    });

    expect(res.ok, isFalse);
    expect(res.error, contains('controller'));
  });

  test('infocutter.session add/toggle/rename/apply round trip', () async {
    final harness = _AutomationHarness();
    harness.window.addTab(_webView(url: 'https://example.com/page'));

    final add = await harness.controller.run('infocutter.session.add', {
      'selector': '.ad',
    });
    expect(add.ok, isTrue, reason: add.error);
    expect(add.data['count'], 1);

    await harness.controller.run('infocutter.session.add', {
      'selector': '.promo',
    });
    // re-adding the same selector toggles it off
    final toggleOff = await harness.controller.run('infocutter.session.add', {
      'selector': '.ad',
    });
    expect(toggleOff.data['count'], 1);

    // snapshot reflects the live session
    final session =
        (harness.controller.snapshot()['infocutter'] as Map)['session'] as List;
    expect(session.single, containsPair('selector', '.promo'));
    final cardId = (session.single as Map)['id'] as String;

    await harness.controller.run('infocutter.session.rename', {
      'cardId': cardId,
      'name': 'Promos',
    });

    final apply = await harness.controller.run('infocutter.session.apply');
    expect(apply.ok, isTrue, reason: apply.error);
    expect(apply.data['applied'], 1);
    expect(
      (harness.controller.snapshot()['infocutter'] as Map)['session'],
      isEmpty,
    );
    expect(
      harness.infocutter.profiles
          .expand((p) => p.rules)
          .any((r) => r.selector == '.promo'),
      isTrue,
    );
  });

  test('infocutter.openPanel requests the panel on the current tab', () async {
    final harness = _AutomationHarness();
    harness.window.addTab(_webView(url: 'https://example.com/page'));

    final res = await harness.controller.run('infocutter.openPanel', {
      'mode': 'keyword',
    });

    expect(res.ok, isTrue, reason: res.error);
    expect(res.data['mode'], 'keyword');
    expect(
      harness.window.getCurrentWebViewModel()!.infocutterPanelRequest.value,
      InfocutterPanelMode.keyword,
    );
  });

  test('snapshot reports the open infocutter panel', () {
    final harness = _AutomationHarness();
    final tab = _webView(url: 'https://example.com/page');
    tab.infocutterOpenPanel = InfocutterPanelMode.manage;
    harness.window.addTab(tab);

    final snap = harness.controller.snapshot();

    expect((snap['infocutter'] as Map)['openPanel'], 'manage');
  });

  test('cookie.* and browser.clearData are in capabilities', () {
    for (final action in const [
      'cookie.list',
      'cookie.get',
      'cookie.set',
      'cookie.delete',
      'browser.clearData',
    ]) {
      expect(
        AppAutomationController.capabilities,
        contains(action),
        reason: '$action missing from capabilities',
      );
    }
  });

  test('cookie.* and browser.clearData are dangerous-tier', () {
    for (final action in const [
      'cookie.list',
      'cookie.get',
      'cookie.set',
      'cookie.delete',
      'browser.clearData',
    ]) {
      expect(
        AppAutomationBridge.dangerousActions,
        contains(action),
        reason: '$action missing from dangerousActions',
      );
    }
  });

  test('snapshot reports AI suggestion count', () async {
    final harness = _AutomationHarness();
    await harness.aiRules.addSuggestions(
      url: Uri.parse('https://example.com/page'),
      suggestions: const [
        AiMaskingSuggestion(selector: '.a'),
        AiMaskingSuggestion(selector: '.b'),
      ],
    );
    final snap = harness.controller.snapshot();
    expect((snap['ai'] as Map)['suggestions'], 2);
  });

  test('textBlock.setCaptureMode sets infocutterKeywordCaptureActive on tab',
      () async {
    final harness = _AutomationHarness();
    final tab = _webView(url: 'https://example.com/page');
    harness.window.addTab(tab);

    expect(tab.infocutterKeywordCaptureActive.value, isFalse);

    final on = await harness.controller
        .run('textBlock.setCaptureMode', {'enabled': true});
    expect(on.ok, isTrue, reason: on.error);
    expect(on.data['captureMode'], isTrue);
    expect(tab.infocutterKeywordCaptureActive.value, isTrue);

    final off = await harness.controller
        .run('textBlock.setCaptureMode', {'enabled': false});
    expect(off.ok, isTrue, reason: off.error);
    expect(off.data['captureMode'], isFalse);
    expect(tab.infocutterKeywordCaptureActive.value, isFalse);
  });

  test(
      'snapshot textBlocks section includes captureMode and lastCapturedKeyword',
      () {
    final harness = _AutomationHarness();
    final tab = _webView(url: 'https://example.com/page');
    tab.infocutterKeywordCaptureActive.value = true;
    tab.infocutterCapturedKeyword.value = '광고';
    harness.window.addTab(tab);

    final snap = harness.controller.snapshot();
    final textBlocks = snap['textBlocks'] as Map;
    expect(textBlocks['captureMode'], isTrue);
    expect(textBlocks['lastCapturedKeyword'], '광고');
  });
}

class _AutomationHarness {
  _AutomationHarness()
      : browser = BrowserModel(),
        window = WindowModel(),
        infocutter = InfocutterService(store: _MemoryInfocutterStore()),
        watch = WatchService(store: _MemoryWatchStore()),
        evidence = EvidenceService(
          store: _MemoryEvidenceStore(),
          fileWriter: _MemoryEvidenceFileWriter(),
        ),
        textBlocks = TextBlockService(store: _MemoryTextBlockStore()),
        networkFilters =
            NetworkFilterService(store: _MemoryNetworkFilterStore()),
        aiConfig = AiConfigService(
          store: _MemoryAiConfigStore(),
          secretStore: _MemoryAiSecretStore(),
        ),
        aiRules = AiRuleService(store: _MemoryAiRuleStore()) {
    controller = AppAutomationController(
      browser: browser,
      window: window,
      infocutter: infocutter,
      watch: watch,
      evidence: evidence,
      textBlocks: textBlocks,
      networkFilters: networkFilters,
      aiConfig: aiConfig,
      aiRules: aiRules,
      savePickedBlockRule: SavePickedBlockRuleUseCase(
        InfocutterServiceBlockRuleRepository(infocutter),
      ),
    );
  }

  final BrowserModel browser;
  final WindowModel window;
  final InfocutterService infocutter;
  final WatchService watch;
  final EvidenceService evidence;
  final TextBlockService textBlocks;
  final NetworkFilterService networkFilters;
  final AiConfigService aiConfig;
  final AiRuleService aiRules;
  late final AppAutomationController controller;
}

WebViewModel _webView({required String url, String? title}) {
  return WebViewModel(url: WebUri(url), title: title, loaded: true);
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

class _MemoryWatchStore implements WatchStore {
  String? raw;

  @override
  Future<String?> loadWatchStoreJson() async => raw;

  @override
  Future<void> saveWatchStoreJson(String raw) async {
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

class _MemoryAiConfigStore implements AiConfigStore {
  String? raw;

  @override
  Future<String?> loadAiConfigJson() async => raw;

  @override
  Future<void> saveAiConfigJson(String raw) async {
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

class _MemoryEvidenceStore implements EvidenceStore {
  String? raw;

  @override
  Future<String?> loadEvidenceJson() async => raw;

  @override
  Future<void> saveEvidenceJson(String raw) async {
    this.raw = raw;
  }
}

class _MemoryEvidenceFileWriter implements EvidenceFileWriter {
  @override
  Future<EvidenceFileSet> writeEvidenceFiles({
    required String id,
    required String html,
    required Map<String, Object?> manifest,
    Uint8List? pngBytes,
  }) async {
    return EvidenceFileSet(
      htmlFilename: '/tmp/$id/page.html',
      manifestFilename: '/tmp/$id/manifest.json',
      pdfFilename: '/tmp/$id/summary.pdf',
      pngFilename:
          pngBytes == null || pngBytes.isEmpty ? '' : '/tmp/$id/page.png',
    );
  }
}
