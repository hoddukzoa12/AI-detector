part of 'app_automation_controller.dart';

class _AppAutomationInfocutterCommands {
  const _AppAutomationInfocutterCommands({
    required WindowModel window,
    required InfocutterService infocutter,
    required SavePickedBlockRuleUseCase savePickedBlockRule,
    required WatchService watch,
    required EvidenceService evidence,
    required TextBlockService textBlocks,
    required NetworkFilterService networkFilters,
    required AiConfigService aiConfig,
    required AiRuleService aiRules,
  })  : _window = window,
        _infocutter = infocutter,
        _savePickedBlockRule = savePickedBlockRule,
        _watch = watch,
        _evidence = evidence,
        _textBlocks = textBlocks,
        _networkFilters = networkFilters,
        _aiConfig = aiConfig,
        _aiRules = aiRules;

  final WindowModel _window;
  final InfocutterService _infocutter;
  final SavePickedBlockRuleUseCase _savePickedBlockRule;
  final WatchService _watch;
  final EvidenceService _evidence;
  final TextBlockService _textBlocks;
  final NetworkFilterService _networkFilters;
  final AiConfigService _aiConfig;
  final AiRuleService _aiRules;

  _InfocutterSessionAutomationCommands get _session =>
      _InfocutterSessionAutomationCommands(
        window: _window,
        savePickedBlockRule: _savePickedBlockRule,
        refreshRuntime: refreshCurrentInfocutterRuntime,
      );

  Future<AppAutomationResult> setInfocutterGlobalEnabled(bool enabled) async {
    await _infocutter.setGlobalEnabled(enabled);
    await refreshCurrentInfocutterRuntime();
    return AppAutomationResult.success(
      'infocutter.global',
      {'enabled': enabled},
    );
  }

  Future<AppAutomationResult> openInfocutterPanel(
    InfocutterPanelMode mode,
  ) async {
    final tab = _currentTab();
    if (tab == null) {
      throw StateError('no current tab');
    }
    // Same path the toolbar icons use: the tab listens to this notifier and
    // opens the requested sidebar panel on the current tab.
    tab.infocutterPanelRequest.value = mode;
    return AppAutomationResult.success('infocutter.openPanel', {
      'mode': mode.name,
    });
  }

  /// Deterministic, click-free element selection: drives the in-page picker's
  /// [pickSelector] which builds the full selector result and emits it, so the
  /// refine/save panel opens exactly as a human pick would. Robust against
  /// WKWebView not forwarding native click events to JS.
  Future<AppAutomationResult> pickElement(String selector) async {
    final picked = await _requireCurrentController().evaluateJavascript(
      source: 'window.__infocutterPicker && '
          'window.__infocutterPicker.pickSelector(${jsonEncode(selector)})',
    );
    return AppAutomationResult.success('infocutter.pick', {
      'selector': selector,
      'picked': picked == true,
    });
  }

  // --- Multi-select staging session (the extension's quick-pick model).
  // The session is owned per-tab on WebViewModel so the human picker and AI
  // commands share one source of truth; persisted all-at-once on apply. ---

  Future<AppAutomationResult> addToSession(
    String selector, {
    String? name,
    bool toggle = true,
  }) =>
      _session.add(selector, name: name, toggle: toggle);

  Future<AppAutomationResult> removeFromSession(String cardId) =>
      _session.remove(cardId);

  Future<AppAutomationResult> refineSessionCard(
    String cardId,
    String selector,
  ) =>
      _session.refine(cardId, selector);

  Future<AppAutomationResult> setSessionCardDepth(String cardId, int index) =>
      _session.setDepth(cardId, index);

  Future<AppAutomationResult> renameSessionCard(
    String cardId,
    String name,
  ) =>
      _session.rename(cardId, name);

  Future<AppAutomationResult> clearSession() => _session.clear();

  Future<AppAutomationResult> applySession() => _session.apply();

  Future<AppAutomationResult> addBlockRule({
    required String selector,
    String cardName = 'AI selected blocks',
    String? frameScope,
  }) async {
    final url = _requireCurrentUri();
    final before = _infocutter.profiles.expand((p) => p.rules).toList();
    final rule = await _savePickedBlockRule(
      SavePickedBlockRuleCommand(
        url: url,
        selector: selector,
        cardName: cardName,
        frameScope: frameScope,
      ),
    );
    final created = !before.any((existing) => isSameStoredRule(existing, rule));
    await refreshCurrentInfocutterRuntime();
    return AppAutomationResult.success('infocutter.addBlockRule', {
      'selector': rule.selector,
      'cardName': rule.cardName,
      'cardId': rule.cardId,
      'profileId': _profileIdForRule(rule),
      'created': created,
      'url': url.toString(),
    });
  }

  Future<AppAutomationResult> listProfiles() async {
    final profiles = _infocutter.profiles
        .map((profile) => {
              'id': profile.id,
              'name': profile.name,
              'enabled': profile.enabled,
              'matchers': profile.matchers,
              'sourceTemplateSlug': profile.sourceTemplateSlug,
              'cards': profile.cards
                  .map((card) => {
                        'id': card.id,
                        'name': card.name,
                        'enabled': card.enabled,
                      })
                  .toList(),
              'rules': profile.rules
                  .map((rule) => {
                        'cardId': rule.cardId,
                        'cardName': rule.cardName,
                        'selector': rule.selector,
                        'mode': rule.mode.name,
                        'frameScope': rule.frameScope,
                      })
                  .toList(),
            })
        .toList();
    return AppAutomationResult.success('infocutter.listProfiles', {
      'profiles': profiles,
      'count': profiles.length,
    });
  }

  Future<AppAutomationResult> removeBlockRule({
    required String profileId,
    required String cardId,
    required String selector,
  }) async {
    final before = _ruleCountForProfile(profileId);
    await _infocutter.removeRule(
      profileId: profileId,
      cardId: cardId,
      selector: selector,
    );
    final removed = _ruleCountForProfile(profileId) < before;
    await refreshCurrentInfocutterRuntime();
    return AppAutomationResult.success('infocutter.removeRule', {
      'profileId': profileId,
      'cardId': cardId,
      'selector': selector,
      'removed': removed,
    });
  }

  Future<AppAutomationResult> setBlockCardEnabled({
    required String profileId,
    required String cardId,
    required bool enabled,
  }) async {
    final profile = await _infocutter.setCardEnabled(
      profileId: profileId,
      cardId: cardId,
      enabled: enabled,
    );
    await refreshCurrentInfocutterRuntime();
    return AppAutomationResult.success('infocutter.setCardEnabled', {
      'profileId': profileId,
      'cardId': cardId,
      'enabled': enabled,
      'applied': profile != null,
    });
  }

  Future<AppAutomationResult> setBlockProfileEnabled({
    required String profileId,
    required bool enabled,
  }) async {
    final profile = await _infocutter.setProfileEnabled(profileId, enabled);
    await refreshCurrentInfocutterRuntime();
    return AppAutomationResult.success('infocutter.setProfileEnabled', {
      'profileId': profileId,
      'enabled': enabled,
      'applied': profile != null,
    });
  }

  Future<AppAutomationResult> removeProfile(String profileId) async {
    final before = _infocutter.profiles.length;
    await _infocutter.deleteProfile(profileId);
    final removed = _infocutter.profiles.length < before;
    await refreshCurrentInfocutterRuntime();
    return AppAutomationResult.success('infocutter.removeProfile', {
      'profileId': profileId,
      'removed': removed,
    });
  }

  String _profileIdForRule(StoredRule rule) {
    for (final profile in _infocutter.profiles) {
      if (profile.rules.any((existing) => isSameStoredRule(existing, rule))) {
        return profile.id;
      }
    }
    return '';
  }

  int _ruleCountForProfile(String profileId) {
    for (final profile in _infocutter.profiles) {
      if (profile.id == profileId) return profile.rules.length;
    }
    return 0;
  }

  Future<AppAutomationResult> importTemplate(String slug) async {
    final template = bundledInfocutterTemplates.firstWhere(
      (template) => template.slug == slug,
      orElse: () => throw ArgumentError.value(slug, 'slug', 'unknown template'),
    );
    final profile = await _infocutter.importTemplate(template);
    await refreshCurrentInfocutterRuntime();
    return AppAutomationResult.success('infocutter.importTemplate', {
      'slug': slug,
      'profileId': profile.id,
      'profileName': profile.name,
    });
  }

  Future<void> refreshCurrentInfocutterRuntime() async {
    final tab = _currentTab();
    final controller = tab?.webViewController;
    final url = _currentUri();
    if (tab == null || controller == null || url == null) return;
    final settings = await controller.getSettings() ?? tab.settings;
    if (settings != null) {
      applyInfocutterSettings(
        settings,
        _infocutter,
        url,
        networkFilters: _networkFilters,
      );
      await controller.setSettings(settings: settings);
      tab.settings = settings;
    }
    await applyInfocutterRuntimeForUrl(controller, _infocutter, url);
    await applyInfocutterTextBlockRuntimeForUrl(controller, _textBlocks, url);
    await applyInfocutterWatchRuntime(controller, _watch);
  }

  WebViewModel? _currentTab() => _window.getCurrentWebViewModel();

  WebViewModel _requireCurrentTab() {
    final tab = _currentTab();
    if (tab == null) {
      throw StateError('no current tab');
    }
    return tab;
  }

  InAppWebViewController _requireCurrentController() {
    final controller = _requireCurrentTab().webViewController;
    if (controller == null) {
      throw StateError('current tab has no WebView controller');
    }
    return controller;
  }

  Uri? _currentUri() {
    final url = _currentTab()?.url;
    if (url == null || url.host.isEmpty) return null;
    return Uri.parse(url.toString());
  }

  Uri _requireCurrentUri() {
    final uri = _currentUri();
    if (uri == null) {
      throw StateError('current tab has no URL with host');
    }
    return uri;
  }
}
