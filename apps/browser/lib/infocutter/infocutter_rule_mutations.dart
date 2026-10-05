part of 'infocutter_service.dart';

extension InfocutterRuleMutations on InfocutterService {
  Future<StoredRule> addRule({
    required String profileId,
    required String cardName,
    required String selector,
    RuleMode mode = RuleMode.hide,
    String? frameScope,
  }) async {
    final idx = _profileIndexById(profileId);
    if (idx < 0) {
      throw StateError('profile not found: $profileId');
    }
    final profile = _snapshot.profiles[idx];
    final now = DateTime.now().toUtc();
    final existingCard = profile.cards.firstWhere(
      (card) => card.name == cardName,
      orElse: () => ProfileCard(
        id: 'ic-${_uuid.v4()}',
        name: cardName,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final cards = profile.cards.any((card) => card.id == existingCard.id)
        ? profile.cards
        : [...profile.cards, existingCard];
    final rule = StoredRule(
      cardId: existingCard.id,
      cardName: existingCard.name,
      selector: selector,
      mode: mode,
      createdAt: now,
      frameScope: frameScope,
    );
    final next = [..._snapshot.profiles];
    next[idx] = profile.copyWith(
      cards: cards,
      rules: [...profile.rules, rule],
      updatedAt: now,
    );
    await _commitProfiles(next);
    return rule;
  }

  Future<void> removeRule({
    required String profileId,
    required String cardId,
    required String selector,
  }) async {
    final idx = _profileIndexById(profileId);
    if (idx < 0) return;
    final profile = _snapshot.profiles[idx];
    final nextRules = profile.rules
        .where((rule) => !(rule.cardId == cardId && rule.selector == selector))
        .toList();
    if (nextRules.length == profile.rules.length) return;
    final next = [..._snapshot.profiles];
    next[idx] = profile.copyWith(
      rules: nextRules,
      updatedAt: DateTime.now().toUtc(),
    );
    await _commitProfiles(next);
  }

  Future<RuleProfile?> renameCard({
    required String profileId,
    required String cardId,
    required String cardName,
  }) {
    final nextName = _nonEmptyTrimmed(cardName);
    if (nextName == null) return Future.value();

    return _updateProfile(profileId, (profile, now) {
      final hasCard = profile.cards.any((card) => card.id == cardId);
      if (!hasCard) return profile;

      return profile.copyWith(
        cards: profile.cards
            .map(
              (card) => card.id == cardId
                  ? card.copyWith(name: nextName, updatedAt: now)
                  : card,
            )
            .toList(),
        rules: profile.rules
            .map(
              (rule) => rule.cardId == cardId
                  ? rule.copyWith(cardName: nextName)
                  : rule,
            )
            .toList(),
        updatedAt: now,
      );
    });
  }

  Future<RuleProfile?> setCardEnabled({
    required String profileId,
    required String cardId,
    required bool enabled,
  }) {
    return _updateProfile(profileId, (profile, now) {
      final hasCard = profile.cards.any((card) => card.id == cardId);
      if (!hasCard) return profile;

      return profile.copyWith(
        cards: profile.cards
            .map(
              (card) => card.id == cardId
                  ? card.copyWith(enabled: enabled, updatedAt: now)
                  : card,
            )
            .toList(),
        updatedAt: now,
      );
    });
  }

  Future<RuleProfile?> removeCard({
    required String profileId,
    required String cardId,
  }) {
    return _updateProfile(
      profileId,
      (profile, now) => profile.copyWith(
        cards: profile.cards.where((card) => card.id != cardId).toList(),
        rules: profile.rules.where((rule) => rule.cardId != cardId).toList(),
        updatedAt: now,
      ),
    );
  }

  Future<RuleProfile?> updateRuleSelector({
    required String profileId,
    required StoredRule targetRule,
    required String selector,
  }) {
    final nextSelector = _nonEmptyTrimmed(selector);
    if (nextSelector == null) return Future.value();

    return _updateProfile(profileId, (profile, now) {
      final updatedRules = profile.rules
          .map(
            (rule) => isSameStoredRule(rule, targetRule)
                ? rule.copyWith(selector: nextSelector)
                : rule,
          )
          .toList();

      return profile.copyWith(
        rules: updatedRules,
        updatedAt: now,
      );
    });
  }

  Future<RuleProfile?> updateStoredRule({
    required String profileId,
    required StoredRule targetRule,
    String? selector,
    RuleMode? mode,
    String? frameScope,
  }) {
    final nextSelector = selector == null ? null : _nonEmptyTrimmed(selector);
    return _updateProfile(profileId, (profile, now) {
      final updatedRules = profile.rules
          .map(
            (rule) => isSameStoredRule(rule, targetRule)
                ? StoredRule(
                    cardId: rule.cardId,
                    cardName: rule.cardName,
                    selector: nextSelector ?? rule.selector,
                    mode: mode ?? rule.mode,
                    createdAt: rule.createdAt,
                    frameScope: _nonEmptyTrimmed(frameScope ?? '') ??
                        (frameScope == null ? rule.frameScope : null),
                  )
                : rule,
          )
          .toList();

      return profile.copyWith(
        rules: updatedRules,
        updatedAt: now,
      );
    });
  }

  Future<RuleProfile?> removeStoredRule({
    required String profileId,
    required StoredRule targetRule,
  }) {
    return _updateProfile(profileId, (profile, now) {
      final remainingRules = profile.rules
          .where((rule) => !isSameStoredRule(rule, targetRule))
          .toList();
      final remainingCardIds =
          remainingRules.map((rule) => rule.cardId).toSet();

      return profile.copyWith(
        cards: profile.cards
            .where((card) => remainingCardIds.contains(card.id))
            .toList(),
        rules: remainingRules,
        updatedAt: now,
      );
    });
  }
}
