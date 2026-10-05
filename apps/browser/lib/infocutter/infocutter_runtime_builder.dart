part of 'infocutter_service.dart';

extension InfocutterRuntimeBuilder on InfocutterService {
  /// 현재 스냅샷을 ContentBlocker 리스트로 변환. WebView 의 InAppWebViewSettings 에 넣음.
  List<ContentBlocker> buildContentBlockers() {
    return _blockerFactory.buildAll(_snapshot);
  }

  /// 단일 URL 에 활성인 프로필들만 ContentBlocker 로 (URL 별 좁힘 - 성능).
  List<ContentBlocker> buildContentBlockersForUrl(Uri url) {
    if (!_snapshot.globalEnabled) return const [];
    final blockers = <ContentBlocker>[];
    for (final profile in _snapshot.profiles) {
      if (!profile.enabled) continue;
      final matchingMatchers =
          profile.matchers.where((matcher) => matchesUrl(matcher, url));
      if (matchingMatchers.isEmpty) continue;
      blockers.addAll(
        _blockerFactory.buildForProfile(
          profile,
          matchers: matchingMatchers,
        ),
      );
    }
    return blockers;
  }

  ActiveSiteState buildActiveSiteState(Uri url) {
    final profile = _findProfileForUrlInSnapshot(_snapshot, url);
    final rules = profile?.rules.toList() ?? <StoredRule>[];
    final cards = groupRulesByCard(rules, profile?.cards ?? const []);
    final enabledHideRules = getEnabledRules(profile, mode: RuleMode.hide);
    final enabledExceptionRules =
        getEnabledRules(profile, mode: RuleMode.unhide);

    return ActiveSiteState(
      activeProfileId: profile?.id,
      activeProfileName: profile?.name,
      cardCount: cards.length,
      cards: cards,
      enabledExceptionCount: enabledExceptionRules.length,
      enabledSelectorCount: enabledHideRules.length,
      exceptionCount:
          rules.where((rule) => rule.mode == RuleMode.unhide).length,
      globalEnabled: _snapshot.globalEnabled,
      hostname: url.host.toLowerCase(),
      matchers: profile?.matchers ?? const [],
      profileEnabled: profile?.enabled ?? true,
      rules: rules,
      selectorCount: rules.length,
      updatedAt: profile?.updatedAt ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      url: url,
    );
  }

  Map<String, Object?> buildRuntimeStateForUrl(Uri url) {
    final profile = _findProfileForUrlInSnapshot(_snapshot, url);
    final enabledRules = getEnabledRules(profile);
    return {
      'version': 1,
      'url': url.toString(),
      'globalEnabled': _snapshot.globalEnabled,
      'profileEnabled': profile?.enabled ?? false,
      'activeProfileId': profile?.id,
      'activeProfileName': profile?.name,
      'rules': enabledRules
          .map(
            (rule) => {
              'cardId': rule.cardId,
              'cardName': rule.cardName,
              'selector': rule.selector,
              'mode': rule.mode == RuleMode.unhide ? 'unhide' : 'hide',
              'frameScope': rule.frameScope,
              'createdAt': rule.createdAt.toUtc().toIso8601String(),
            },
          )
          .toList(),
    };
  }
}

RuleProfile? _findProfileForUrlInSnapshot(
  RuleStoreSnapshot snapshot,
  Uri url,
) {
  for (final profile in snapshot.profiles) {
    if (profile.matchers.any((matcher) => matchesUrl(matcher, url))) {
      return profile;
    }
  }
  return null;
}
