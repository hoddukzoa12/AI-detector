part of 'app_automation_controller.dart';

class _AppAutomationSnapshotBuilder {
  const _AppAutomationSnapshotBuilder({
    required BrowserModel browser,
    required WindowModel window,
    required InfocutterService infocutter,
    required WatchService watch,
    required EvidenceService evidence,
    required TextBlockService textBlocks,
    required NetworkFilterService networkFilters,
    required AiConfigService aiConfig,
    required AiRuleService aiRules,
  })  : _browser = browser,
        _window = window,
        _infocutter = infocutter,
        _watch = watch,
        _evidence = evidence,
        _textBlocks = textBlocks,
        _networkFilters = networkFilters,
        _aiConfig = aiConfig,
        _aiRules = aiRules;

  final BrowserModel _browser;
  final WindowModel _window;
  final InfocutterService _infocutter;
  final WatchService _watch;
  final EvidenceService _evidence;
  final TextBlockService _textBlocks;
  final NetworkFilterService _networkFilters;
  final AiConfigService _aiConfig;
  final AiRuleService _aiRules;

  Map<String, Object?> build(List<String> capabilities) {
    final settings = _browser.getSettings();
    final currentTab = _currentTab();
    return {
      'capabilities': capabilities,
      'browser': {
        'searchEngine': settings.searchEngine.name,
        'defaultSite': settings.defaultSite.name,
        'homePageEnabled': settings.homePageEnabled,
        'homePage': settings.startPageUrl,
        'debuggingEnabled': settings.debuggingEnabled,
      },
      'window': {
        'id': _window.id,
        'name': _window.name,
        'currentTabIndex': _window.getCurrentTabIndex(),
        'tabCount': _window.webViewModels.length,
        'shouldSave': _window.shouldSave,
      },
      'currentTab': currentTab == null ? null : _tabSnapshot(currentTab),
      'tabs': _window.webViewModels.map(_tabSnapshot).toList(),
      'infocutter': _infocutterSnapshot(),
      'watch': _watchSnapshot(),
      'textBlocks': _textBlockSnapshot(),
      'networkFilters': _networkFilterSnapshot(),
      'ai': _aiSnapshot(),
      'evidence': {
        'records': _evidence.records.length,
      },
    };
  }

  WebViewModel? _currentTab() => _window.getCurrentWebViewModel();

  Map<String, Object?> _tabSnapshot(WebViewModel tab) => {
        'index': tab.tabIndex,
        'url': tab.url?.toString(),
        'title': tab.title,
        'loaded': tab.loaded,
        'progress': tab.progress,
        'isSecure': tab.isSecure,
        'isIncognito': tab.isIncognitoMode,
        'hasController': tab.webViewController != null,
        'consoleLogCount': tab.javaScriptConsoleLogs.length,
        'loadedResourceCount': tab.loadedResources.length,
      };

  Map<String, Object?> _infocutterSnapshot() {
    final rules = _infocutter.profiles.fold<int>(
      0,
      (count, profile) => count + profile.rules.length,
    );
    return {
      'loaded': _infocutter.isLoaded,
      'globalEnabled': _infocutter.globalEnabled,
      'openPanel': _currentTab()?.infocutterOpenPanel?.name,
      'session': _currentTab()
              ?.infocutterSelectionSession
              .value
              .map((card) => card.toJson())
              .toList() ??
          const [],
      'profiles': _infocutter.profiles.length,
      'rules': rules,
      'templates': bundledInfocutterTemplates
          .map((template) => {
                'slug': template.slug,
                'name': template.name,
                'matchers': template.matchers,
              })
          .toList(),
    };
  }

  Map<String, Object?> _watchSnapshot() => {
        'loaded': _watch.isLoaded,
        'globalEnabled': _watch.globalEnabled,
        'autoMask': _watch.autoMask,
        'targets': _watch.targets.length,
        'recentDetections': _watch.recentDetections.length,
      };

  Map<String, Object?> _textBlockSnapshot() {
    final currentTab = _currentTab();
    return {
      'loaded': _textBlocks.isLoaded,
      'globalEnabled': _textBlocks.globalEnabled,
      'profiles': _textBlocks.profiles.length,
      'rules': _textBlocks.profiles.fold<int>(
        0,
        (count, profile) => count + profile.rules.length,
      ),
      'captureMode': currentTab?.infocutterKeywordCaptureActive.value ?? false,
      'lastCapturedKeyword': currentTab?.infocutterCapturedKeyword.value,
    };
  }

  Map<String, Object?> _networkFilterSnapshot() => {
        'loaded': _networkFilters.isLoaded,
        'globalEnabled': _networkFilters.globalEnabled,
        'rules': _networkFilters.rules.length,
      };

  Map<String, Object?> _aiSnapshot() => {
        'loaded': _aiConfig.isLoaded,
        'configured': _aiConfig.isConfigured,
        'endpoint': _aiConfig.snapshot.endpoint,
        'model': _aiConfig.snapshot.model,
        'prompt': _aiConfig.snapshot.prompt,
        'hasApiKey': _aiConfig.snapshot.apiKey.trim().isNotEmpty,
        'analyzedHosts': _aiConfig.snapshot.analyzedHosts,
        'suggestions': _aiRules.rules.length,
        'suggestionsLoaded': _aiRules.isLoaded,
      };
}
