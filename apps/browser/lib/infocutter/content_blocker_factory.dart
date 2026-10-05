import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'models.dart';
import 'url_matcher.dart';

class ContentBlockerFactory {
  const ContentBlockerFactory();

  /// 스냅샷의 모든 프로필을 ContentBlocker 리스트로 변환.
  /// globalEnabled / profile.enabled 둘 다 false 면 빈 리스트 반환.
  List<ContentBlocker> buildAll(RuleStoreSnapshot snapshot) {
    if (!snapshot.globalEnabled) return const [];
    return snapshot.profiles
        .where((p) => p.enabled)
        .expand(buildForProfile)
        .toList();
  }

  /// 단일 프로필을 ContentBlocker 리스트로 변환.
  /// hide 규칙은 CSS_DISPLAY_NONE 으로, unhide 규칙은 각 hide selector 에
  /// `:not(<unhide>)` 체인으로 제외 (CSS3 호환). 활성 카드의 룰만 포함.
  List<ContentBlocker> buildForProfile(
    RuleProfile profile, {
    Iterable<String>? matchers,
  }) {
    final activeMatchers = (matchers ?? profile.matchers)
        .where((matcher) => matcher.trim().isNotEmpty)
        .toList();
    if (activeMatchers.isEmpty) return const [];

    final activeCardIds =
        profile.cards.where((c) => c.enabled).map((c) => c.id).toSet();
    final activeRules = _activeRules(profile, activeCardIds);
    final hideSelectors = _selectorsForMode(activeRules, RuleMode.hide);
    final unhideSelectors = _selectorsForMode(activeRules, RuleMode.unhide);

    if (hideSelectors.isEmpty) return const [];

    final selector = _contentBlockerSelector(hideSelectors, unhideSelectors);

    return activeMatchers
        .map(
          (matcher) => ContentBlocker(
            trigger: ContentBlockerTrigger(
              urlFilter: matcherToUrlFilter(matcher),
              resourceType: [ContentBlockerTriggerResourceType.DOCUMENT],
            ),
            action: ContentBlockerAction(
              type: ContentBlockerActionType.CSS_DISPLAY_NONE,
              selector: selector,
            ),
          ),
        )
        .toList();
  }

  List<StoredRule> _activeRules(
    RuleProfile profile,
    Set<String> activeCardIds,
  ) {
    return profile.rules
        .where((r) => activeCardIds.contains(r.cardId))
        .where((r) => r.frameScope == null)
        .toList();
  }

  List<String> _selectorsForMode(
    List<StoredRule> rules,
    RuleMode mode,
  ) {
    return rules
        .where((r) => r.mode == mode)
        .map((r) => r.selector)
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String _contentBlockerSelector(
    List<String> hideSelectors,
    List<String> unhideSelectors,
  ) {
    if (unhideSelectors.isEmpty) {
      return hideSelectors.join(', ');
    }
    // Chain one :not() per unhide selector (CSS3) instead of the CSS4
    // selector-list form `:not(a, b)`, which some WebKit content-blocker
    // engines (older Safari / iOS) reject — silently dropping the whole rule.
    final unhideChain = unhideSelectors.map((u) => ':not($u)').join();
    return hideSelectors.map((hide) => '$hide$unhideChain').join(', ');
  }
}

/// chrome 의 matcher (`'https://example.com/*'`, `'*://*.example.com/*'`) 를
/// ContentBlocker.ifDomain 의 host 형식으로 변환. 기존 테스트/호출자 호환용.
String matcherToDomain(String matcher) {
  final m = RegExp(r'^(?:\*|https?)://([^/]+)').firstMatch(matcher);
  if (m == null) return matcher;
  final host = m.group(1)!;
  return host;
}
