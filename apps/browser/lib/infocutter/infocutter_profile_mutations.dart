part of 'infocutter_service.dart';

extension InfocutterProfileMutations on InfocutterService {
  Future<StoredRule> addPickedRuleForUrl({
    required Uri url,
    required String selector,
    String cardName = 'Picked elements',
    String? frameScope,
  }) async {
    final host = url.host.toLowerCase();
    final normalizedSelector = selector.trim();
    if (host.isEmpty) {
      throw ArgumentError.value(
          url.toString(), 'url', 'URL must include a host');
    }
    if (normalizedSelector.isEmpty) {
      throw ArgumentError.value(
          selector, 'selector', 'selector must not be empty');
    }

    final profile = await _ensureEnabledProfileForUrl(url);

    final existingRule = profile.rules.where(
      (rule) =>
          rule.selector == normalizedSelector &&
          rule.mode == RuleMode.hide &&
          rule.frameScope == frameScope,
    );
    if (existingRule.isNotEmpty) {
      return existingRule.first;
    }

    return addRule(
      profileId: profile.id,
      cardName: cardName,
      selector: normalizedSelector,
      frameScope: frameScope,
    );
  }

  Future<void> setGlobalEnabled(bool value) async {
    if (_snapshot.globalEnabled == value) return;
    await _commitSnapshot(_snapshot.copyWith(globalEnabled: value));
  }

  Future<RuleProfile> upsertProfile({
    required String name,
    String? id,
    bool enabled = true,
    List<String> matchers = const [],
    String? sourceTemplateSlug,
  }) async {
    final now = DateTime.now().toUtc();
    final existingIdx =
        id == null ? -1 : _snapshot.profiles.indexWhere((p) => p.id == id);
    final profile = existingIdx >= 0
        ? _snapshot.profiles[existingIdx].copyWith(
            name: name,
            enabled: enabled,
            matchers: matchers,
            sourceTemplateSlug: sourceTemplateSlug,
            updatedAt: now,
          )
        : RuleProfile(
            id: id ?? 'ic-${_uuid.v4()}',
            name: name,
            enabled: enabled,
            matchers: matchers,
            cards: const [],
            rules: const [],
            sourceTemplateSlug: sourceTemplateSlug,
            updatedAt: now,
          );
    final next = [..._snapshot.profiles];
    if (existingIdx >= 0) {
      next[existingIdx] = profile;
    } else {
      next.add(profile);
    }
    await _commitProfiles(next);
    return profile;
  }

  Future<void> deleteProfile(String profileId) async {
    final next = _snapshot.profiles.where((p) => p.id != profileId).toList();
    if (next.length == _snapshot.profiles.length) return;
    await _commitProfiles(next);
  }

  Future<RuleProfile?> renameProfile(String profileId, String name) {
    return _updateProfile(profileId, (profile, now) {
      return profile.copyWith(
        name: _nonEmptyTrimmed(name) ?? profile.name,
        updatedAt: now,
      );
    });
  }

  Future<RuleProfile?> setProfileMatchers(
    String profileId,
    List<String> matchers,
  ) {
    return _updateProfile(
      profileId,
      (profile, now) => profile.copyWith(
        matchers: _sanitizeMatchers(matchers),
        updatedAt: now,
      ),
    );
  }

  Future<RuleProfile?> setProfileEnabled(
    String profileId,
    bool enabled,
  ) {
    return _updateProfile(
      profileId,
      (profile, now) => profile.copyWith(
        enabled: enabled,
        updatedAt: now,
      ),
    );
  }

  Future<void> moveProfile(
    String profileId,
    ProfileMoveDirection direction,
  ) async {
    final index = _profileIndexById(profileId);
    if (index < 0) return;

    final targetIndex =
        direction == ProfileMoveDirection.up ? index - 1 : index + 1;
    if (targetIndex < 0 || targetIndex >= _snapshot.profiles.length) return;

    final next = [..._snapshot.profiles];
    final profile = next.removeAt(index);
    next.insert(targetIndex, profile);
    await _commitProfiles(next);
  }

  Future<RuleProfile?> clearProfileRules(String profileId) {
    return _updateProfile(
      profileId,
      (profile, now) => profile.copyWith(
        cards: const [],
        rules: const [],
        updatedAt: now,
      ),
    );
  }

  Future<RuleProfile> _ensureEnabledProfileForUrl(Uri url) async {
    final host = url.host.toLowerCase();
    final profile = _findProfileForUrlInSnapshot(_snapshot, url);
    if (profile == null) {
      return upsertProfile(
        name: host,
        matchers: [hostnameMatcher(url)],
      );
    }

    if (profile.enabled) return profile;

    return upsertProfile(
      id: profile.id,
      name: profile.name,
      matchers: profile.matchers,
      sourceTemplateSlug: profile.sourceTemplateSlug,
    );
  }

  Future<RuleProfile?> _updateProfile(
    String profileId,
    RuleProfile Function(RuleProfile profile, DateTime now) update,
  ) async {
    final idx = _profileIndexById(profileId);
    if (idx < 0) return null;

    final now = DateTime.now().toUtc();
    final next = [..._snapshot.profiles];
    final profile = update(next[idx], now);
    next[idx] = profile;
    await _commitProfiles(next);
    return profile;
  }
}

String? _nonEmptyTrimmed(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _sanitizeMatchers(List<String> matchers) {
  return matchers
      .map((matcher) => matcher.trim())
      .where((matcher) => matcher.isNotEmpty)
      .toList();
}
