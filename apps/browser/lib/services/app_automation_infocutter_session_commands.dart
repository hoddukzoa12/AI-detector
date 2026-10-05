part of 'app_automation_controller.dart';

class _InfocutterSessionAutomationCommands {
  const _InfocutterSessionAutomationCommands({
    required WindowModel window,
    required SavePickedBlockRuleUseCase savePickedBlockRule,
    required Future<void> Function() refreshRuntime,
  })  : _window = window,
        _savePickedBlockRule = savePickedBlockRule,
        _refreshRuntime = refreshRuntime;

  final WindowModel _window;
  final SavePickedBlockRuleUseCase _savePickedBlockRule;
  final Future<void> Function() _refreshRuntime;

  Future<AppAutomationResult> add(
    String selector, {
    String? name,
    bool toggle = true,
  }) async {
    final tab = _requireCurrentTab();
    final normalized = selector.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(selector, 'selector', 'non-empty required');
    }

    final card = SelectionCard(
      id: _newCardId(tab),
      name: (name != null && name.trim().isNotEmpty) ? name.trim() : normalized,
      selector: normalized,
      frameScope: null,
      matchCount: await _matchCount(tab, normalized),
    );
    final current = tab.infocutterSelectionSession.value;
    tab.infocutterSelectionSession.value =
        toggle ? sessionToggle(current, card) : [...current, card];
    await _repaintHighlights(tab);
    return AppAutomationResult.success('infocutter.session.add', {
      'session': _sessionJson(tab),
      'count': tab.infocutterSelectionSession.value.length,
    });
  }

  Future<AppAutomationResult> remove(String cardId) async {
    final tab = _requireCurrentTab();
    tab.infocutterSelectionSession.value =
        sessionRemove(tab.infocutterSelectionSession.value, cardId);
    await _repaintHighlights(tab);
    return AppAutomationResult.success('infocutter.session.remove', {
      'session': _sessionJson(tab),
      'count': tab.infocutterSelectionSession.value.length,
    });
  }

  Future<AppAutomationResult> refine(String cardId, String selector) async {
    final tab = _requireCurrentTab();
    final normalized = selector.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(selector, 'selector', 'non-empty required');
    }

    tab.infocutterSelectionSession.value = sessionUpdateSelector(
      tab.infocutterSelectionSession.value,
      cardId,
      normalized,
      matchCount: await _matchCount(tab, normalized),
    );
    await _repaintHighlights(tab);
    return AppAutomationResult.success('infocutter.session.refine', {
      'session': _sessionJson(tab),
    });
  }

  Future<AppAutomationResult> setDepth(String cardId, int index) async {
    final tab = _requireCurrentTab();
    tab.infocutterSelectionSession.value = sessionSetDepthIndex(
      tab.infocutterSelectionSession.value,
      cardId,
      index,
    );
    await _repaintHighlights(tab);
    return AppAutomationResult.success('infocutter.session.setDepth', {
      'session': _sessionJson(tab),
    });
  }

  Future<AppAutomationResult> rename(String cardId, String name) async {
    final tab = _requireCurrentTab();
    tab.infocutterSelectionSession.value =
        sessionRename(tab.infocutterSelectionSession.value, cardId, name);
    return AppAutomationResult.success('infocutter.session.rename', {
      'session': _sessionJson(tab),
    });
  }

  Future<AppAutomationResult> clear() async {
    final tab = _requireCurrentTab();
    tab.infocutterSelectionSession.value = const [];
    await _repaintHighlights(tab);
    return AppAutomationResult.success('infocutter.session.clear', {
      'session': const [],
    });
  }

  Future<AppAutomationResult> apply() async {
    final url = _requireCurrentUri();
    final tab = _requireCurrentTab();
    final cards = tab.infocutterSelectionSession.value;
    final applied = <Map<String, Object?>>[];
    for (final card in cards) {
      final rule = await _savePickedBlockRule(
        SavePickedBlockRuleCommand(
          url: url,
          selector: card.selector,
          cardName: card.name,
          frameScope: card.frameScope,
        ),
      );
      applied.add({
        'selector': rule.selector,
        'cardId': rule.cardId,
        'cardName': rule.cardName,
      });
    }
    tab.infocutterSelectionSession.value = const [];
    await _repaintHighlights(tab);
    await _refreshRuntime();
    return AppAutomationResult.success('infocutter.session.apply', {
      'applied': applied.length,
      'rules': applied,
    });
  }

  List<Object?> _sessionJson(WebViewModel tab) =>
      tab.infocutterSelectionSession.value.map((c) => c.toJson()).toList();

  Future<int> _matchCount(WebViewModel tab, String selector) async {
    final controller = tab.webViewController;
    if (controller == null) return -1;
    final raw = await controller.evaluateJavascript(
      source: 'document.querySelectorAll(${jsonEncode(selector)}).length',
    );
    return raw is num ? raw.toInt() : -1;
  }

  /// 세션이 바뀐 직후 in-page 의 번호 매겨진 하이라이트를 갱신해, AI 가
  /// 스테이징한 블록이 사람 화면에도 즉시 보이게 함(빈 세션이면 지워짐).
  Future<void> _repaintHighlights(WebViewModel tab) async {
    final controller = tab.webViewController;
    if (controller == null) return;
    await applyInfocutterSessionHighlights(
      controller,
      tab.infocutterSelectionSession.value,
    );
  }

  String _newCardId(WebViewModel tab) => 'sel-'
      '${DateTime.now().microsecondsSinceEpoch}-'
      '${tab.infocutterSelectionSession.value.length}';

  WebViewModel? _currentTab() => _window.getCurrentWebViewModel();

  WebViewModel _requireCurrentTab() {
    final tab = _currentTab();
    if (tab == null) {
      throw StateError('no current tab');
    }
    return tab;
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
