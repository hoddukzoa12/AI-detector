import 'package:flutter/foundation.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/models.dart';

class RecordedUpdate {
  RecordedUpdate(this.profileId, this.targetRule, this.selector, this.mode);
  final String profileId;
  final StoredRule targetRule;
  final String? selector;
  final RuleMode? mode;
}

class RecordedRemove {
  RecordedRemove(this.profileId, this.targetRule);
  final String profileId;
  final StoredRule targetRule;
}

/// Minimal fake for widget tests: returns a fixed ActiveSiteState and records
/// updateStoredRule / removeStoredRule. All other BlockRuleRepository members
/// are routed through noSuchMethod (they are not exercised by these tests).
/// Extends ChangeNotifier so it can be provided via ListenableProvider and
/// notify on mutation.
///
/// Optional [profiles] and [globalEnabled] support the rule-manager slim test.
/// When [profiles] is provided, [buildActiveSiteState] returns an
/// ActiveSiteState whose [activeProfileId] is the first profile whose matchers
/// contain the URL host; otherwise it falls back to the fixed [_state].
class FakeBlockRuleRepository extends ChangeNotifier
    implements BlockRuleRepository {
  FakeBlockRuleRepository(
    this._state, {
    List<RuleProfile> profiles = const [],
    bool globalEnabled = true,
  })  : _profiles = profiles,
        _globalEnabled = globalEnabled;

  final ActiveSiteState _state;
  final List<RuleProfile> _profiles;
  final bool _globalEnabled;

  RecordedUpdate? lastUpdate;
  RecordedRemove? lastRemove;

  @override
  bool get globalEnabled => _globalEnabled;

  @override
  List<RuleProfile> get profiles => _profiles;

  @override
  ActiveSiteState buildActiveSiteState(Uri url) {
    if (_profiles.isEmpty) return _state;
    final host = url.host;
    final firstMatch = _profiles.firstWhere(
      (p) => p.matchers.any((m) => m.contains(host) || host.contains(m)),
      orElse: () => _profiles.first,
    );
    return ActiveSiteState(
      activeProfileId: firstMatch.id,
      activeProfileName: firstMatch.name,
      cardCount: firstMatch.cards.length,
      cards: const [],
      enabledExceptionCount: 0,
      enabledSelectorCount: 0,
      exceptionCount: 0,
      globalEnabled: _globalEnabled,
      hostname: host,
      matchers: firstMatch.matchers,
      profileEnabled: firstMatch.enabled,
      rules: firstMatch.rules,
      selectorCount: firstMatch.rules.length,
      updatedAt: firstMatch.updatedAt,
      url: url,
    );
  }

  @override
  Future<RuleProfile?> updateStoredRule({
    required String profileId,
    required StoredRule targetRule,
    String? selector,
    RuleMode? mode,
    String? frameScope,
  }) async {
    lastUpdate = RecordedUpdate(profileId, targetRule, selector, mode);
    notifyListeners();
    return null;
  }

  @override
  Future<void> removeStoredRule({
    required String profileId,
    required StoredRule targetRule,
  }) async {
    lastRemove = RecordedRemove(profileId, targetRule);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
