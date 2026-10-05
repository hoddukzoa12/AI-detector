import 'package:meta/meta.dart';

enum RuleMode { hide, unhide }

enum ProfileMoveDirection { up, down }

@immutable
class ProfileCard {
  const ProfileCard({
    required this.id,
    required this.name,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProfileCard copyWith({
    String? id,
    String? name,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ProfileCard(
        id: id ?? this.id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

@immutable
class StoredRule {
  const StoredRule({
    required this.cardId,
    required this.cardName,
    required this.selector,
    required this.mode,
    required this.createdAt,
    this.frameScope,
  });

  final String cardId;
  final String cardName;
  final String selector;
  final RuleMode mode;
  final DateTime createdAt;
  final String? frameScope;

  StoredRule copyWith({
    String? cardId,
    String? cardName,
    String? selector,
    RuleMode? mode,
    DateTime? createdAt,
    String? frameScope,
  }) =>
      StoredRule(
        cardId: cardId ?? this.cardId,
        cardName: cardName ?? this.cardName,
        selector: selector ?? this.selector,
        mode: mode ?? this.mode,
        createdAt: createdAt ?? this.createdAt,
        frameScope: frameScope ?? this.frameScope,
      );
}

@immutable
class RuleProfile {
  const RuleProfile({
    required this.id,
    required this.name,
    required this.enabled,
    required this.matchers,
    required this.cards,
    required this.rules,
    required this.updatedAt,
    this.sourceTemplateSlug,
  });

  final String id;
  final String name;
  final bool enabled;
  final List<String> matchers;
  final List<ProfileCard> cards;
  final List<StoredRule> rules;
  final String? sourceTemplateSlug;
  final DateTime updatedAt;

  RuleProfile copyWith({
    String? id,
    String? name,
    bool? enabled,
    List<String>? matchers,
    List<ProfileCard>? cards,
    List<StoredRule>? rules,
    String? sourceTemplateSlug,
    DateTime? updatedAt,
  }) =>
      RuleProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        matchers: matchers ?? this.matchers,
        cards: cards ?? this.cards,
        rules: rules ?? this.rules,
        sourceTemplateSlug: sourceTemplateSlug ?? this.sourceTemplateSlug,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

@immutable
class SavedCard {
  const SavedCard({
    required this.cardId,
    required this.cardName,
    required this.createdAt,
    required this.enabled,
    required this.frameScopes,
    required this.mode,
    required this.ruleCount,
    required this.rules,
  });

  final String cardId;
  final String cardName;
  final DateTime createdAt;
  final bool enabled;
  final List<String?> frameScopes;
  final RuleMode mode;
  final int ruleCount;
  final List<StoredRule> rules;

  SavedCard copyWith({
    String? cardId,
    String? cardName,
    DateTime? createdAt,
    bool? enabled,
    List<String?>? frameScopes,
    RuleMode? mode,
    int? ruleCount,
    List<StoredRule>? rules,
  }) =>
      SavedCard(
        cardId: cardId ?? this.cardId,
        cardName: cardName ?? this.cardName,
        createdAt: createdAt ?? this.createdAt,
        enabled: enabled ?? this.enabled,
        frameScopes: frameScopes ?? this.frameScopes,
        mode: mode ?? this.mode,
        ruleCount: ruleCount ?? this.ruleCount,
        rules: rules ?? this.rules,
      );
}

@immutable
class ActiveSiteState {
  const ActiveSiteState({
    required this.activeProfileId,
    required this.activeProfileName,
    required this.cardCount,
    required this.cards,
    required this.enabledExceptionCount,
    required this.enabledSelectorCount,
    required this.exceptionCount,
    required this.globalEnabled,
    required this.hostname,
    required this.matchers,
    required this.profileEnabled,
    required this.rules,
    required this.selectorCount,
    required this.updatedAt,
    required this.url,
  });

  final String? activeProfileId;
  final String? activeProfileName;
  final int cardCount;
  final List<SavedCard> cards;
  final int enabledExceptionCount;
  final int enabledSelectorCount;
  final int exceptionCount;
  final bool globalEnabled;
  final String hostname;
  final List<String> matchers;
  final bool profileEnabled;
  final List<StoredRule> rules;
  final int selectorCount;
  final DateTime updatedAt;
  final Uri url;
}

@immutable
class RuleStoreSnapshot {
  const RuleStoreSnapshot({
    required this.globalEnabled,
    required this.profiles,
  });

  final bool globalEnabled;
  final List<RuleProfile> profiles;

  RuleStoreSnapshot copyWith({
    bool? globalEnabled,
    List<RuleProfile>? profiles,
  }) =>
      RuleStoreSnapshot(
        globalEnabled: globalEnabled ?? this.globalEnabled,
        profiles: profiles ?? this.profiles,
      );

  static const RuleStoreSnapshot empty = RuleStoreSnapshot(
    globalEnabled: true,
    profiles: [],
  );
}

List<SavedCard> groupRulesByCard(
  List<StoredRule> rules, [
  List<ProfileCard> profileCards = const [],
]) {
  final cards = <String, SavedCard>{};

  for (final card in profileCards) {
    cards[card.id] = SavedCard(
      cardId: card.id,
      cardName: card.name,
      createdAt: card.createdAt,
      enabled: card.enabled,
      frameScopes: const [],
      mode: RuleMode.hide,
      ruleCount: 0,
      rules: const [],
    );
  }

  for (final rule in rules) {
    final current = cards[rule.cardId];
    if (current != null) {
      cards[rule.cardId] = current.copyWith(
        cardName: rule.cardName,
        frameScopes: current.frameScopes.contains(rule.frameScope)
            ? current.frameScopes
            : [...current.frameScopes, rule.frameScope],
        mode: rule.mode,
        ruleCount: current.ruleCount + 1,
        rules: [...current.rules, rule],
      );
      continue;
    }

    cards[rule.cardId] = SavedCard(
      cardId: rule.cardId,
      cardName: rule.cardName,
      createdAt: rule.createdAt,
      enabled: true,
      frameScopes: [rule.frameScope],
      mode: rule.mode,
      ruleCount: 1,
      rules: [rule],
    );
  }

  return cards.values.toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
}

List<StoredRule> getEnabledRules(
  RuleProfile? profile, {
  RuleMode? mode,
}) {
  if (profile == null) return const [];

  final enabledCardIds = profile.cards
      .where((card) => card.enabled)
      .map((card) => card.id)
      .toSet();

  return profile.rules
      .where((rule) => enabledCardIds.contains(rule.cardId))
      .where((rule) => mode == null || rule.mode == mode)
      .toList();
}

bool isSameStoredRule(
  StoredRule rule,
  StoredRule targetRule,
) =>
    rule.cardId == targetRule.cardId &&
    rule.createdAt == targetRule.createdAt &&
    rule.frameScope == targetRule.frameScope &&
    rule.mode == targetRule.mode &&
    rule.selector == targetRule.selector;
