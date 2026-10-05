import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'models.dart';

const int chromeStorageVersion = 4;

const _uuid = Uuid();

String _newId() => 'ic-${_uuid.v4()}';

DateTime _parseTime(Object? raw) {
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.toUtc();
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

RuleMode _parseMode(Object? raw) =>
    raw == 'unhide' ? RuleMode.unhide : RuleMode.hide;

String _modeToString(RuleMode m) => m == RuleMode.unhide ? 'unhide' : 'hide';

ProfileCard? _decodeCard(Object? raw) {
  if (raw is! Map) return null;
  final created = _parseTime(raw['createdAt']);
  return ProfileCard(
    id: raw['id'] is String && (raw['id'] as String).isNotEmpty
        ? raw['id'] as String
        : _newId(),
    name: raw['name'] is String && (raw['name'] as String).isNotEmpty
        ? raw['name'] as String
        : '기본 카드',
    enabled: raw['enabled'] is bool ? raw['enabled'] as bool : true,
    createdAt: created,
    updatedAt:
        raw['updatedAt'] is String ? _parseTime(raw['updatedAt']) : created,
  );
}

StoredRule? _decodeRule(Object? raw) {
  if (raw is String) {
    final now = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return StoredRule(
      cardId: _newId(),
      cardName: '기본 카드',
      selector: raw,
      mode: RuleMode.hide,
      createdAt: now,
    );
  }
  if (raw is! Map) return null;
  final selector = raw['selector'];
  if (selector is! String) return null;
  return StoredRule(
    cardId: raw['cardId'] is String && (raw['cardId'] as String).isNotEmpty
        ? raw['cardId'] as String
        : _newId(),
    cardName:
        raw['cardName'] is String && (raw['cardName'] as String).isNotEmpty
            ? raw['cardName'] as String
            : '기본 카드',
    selector: selector,
    mode: _parseMode(raw['mode']),
    createdAt: _parseTime(raw['createdAt']),
    frameScope:
        raw['frameScope'] is String ? raw['frameScope'] as String : null,
  );
}

RuleProfile? _decodeProfile(Object? raw) {
  if (raw is! Map) return null;
  final rulesRaw = raw['rules'];
  final rules = rulesRaw is List
      ? rulesRaw.map(_decodeRule).whereType<StoredRule>().toList()
      : <StoredRule>[];
  final cardsRaw = raw['cards'];
  final cards = cardsRaw is List
      ? cardsRaw.map(_decodeCard).whereType<ProfileCard>().toList()
      : _deriveCards(rules);
  final matchersRaw = raw['matchers'];
  final matchers = matchersRaw is List
      ? matchersRaw.whereType<String>().where((m) => m.isNotEmpty).toList()
      : <String>[];
  final name = raw['name'];
  return RuleProfile(
    id: raw['id'] is String && (raw['id'] as String).isNotEmpty
        ? raw['id'] as String
        : _newId(),
    name: name is String && name.isNotEmpty
        ? name
        : (matchers.isNotEmpty
            ? _matcherDisplayName(matchers.first)
            : '이름 없는 프로필'),
    enabled: raw['enabled'] is bool ? raw['enabled'] as bool : true,
    matchers: matchers,
    cards: cards,
    rules: _reconcileCards(rules, cards),
    sourceTemplateSlug: raw['sourceTemplateSlug'] is String &&
            (raw['sourceTemplateSlug'] as String).isNotEmpty
        ? raw['sourceTemplateSlug'] as String
        : null,
    updatedAt: _parseTime(raw['updatedAt']),
  );
}

List<ProfileCard> _deriveCards(List<StoredRule> rules) {
  final map = <String, ProfileCard>{};
  for (final rule in rules) {
    map.putIfAbsent(
      rule.cardId,
      () => ProfileCard(
        id: rule.cardId,
        name: rule.cardName,
        enabled: true,
        createdAt: rule.createdAt,
        updatedAt: rule.createdAt,
      ),
    );
  }
  final cards = map.values.toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return cards;
}

List<StoredRule> _reconcileCards(
  List<StoredRule> rules,
  List<ProfileCard> cards,
) {
  if (cards.isEmpty) return rules;
  final byId = {for (final c in cards) c.id: c};
  return rules
      .map((r) => byId[r.cardId] != null
          ? r.copyWith(cardName: byId[r.cardId]!.name)
          : r)
      .toList();
}

String _matcherDisplayName(String matcher) => matcher
    .replaceFirst(RegExp(r'^\*?:?//'), '')
    .replaceFirst(RegExp(r'/\*$'), '');

class RuleStoreCodec {
  const RuleStoreCodec();

  /// chrome 의 `chrome.storage.local.get('infocutter.ruleStore')` 결과 호환 JSON.
  Map<String, dynamic> encode(RuleStoreSnapshot snapshot) => {
        'version': chromeStorageVersion,
        'settings': {'globalEnabled': snapshot.globalEnabled},
        'profiles': snapshot.profiles.map(_profileToJson).toList(),
      };

  String encodeJson(RuleStoreSnapshot snapshot) => jsonEncode(encode(snapshot));

  /// chrome export JSON 을 안전하게 파싱. 모든 입력에 대해 throw 안 함.
  RuleStoreSnapshot decode(Object? raw) {
    if (raw is! Map) return RuleStoreSnapshot.empty;
    final settings = raw['settings'];
    final globalEnabled = settings is Map && settings['globalEnabled'] is bool
        ? settings['globalEnabled'] as bool
        : true;
    final rawProfiles = raw['profiles'];
    final profiles = rawProfiles is List
        ? rawProfiles.map(_decodeProfile).whereType<RuleProfile>().toList()
        : <RuleProfile>[];
    return RuleStoreSnapshot(
      globalEnabled: globalEnabled,
      profiles: profiles,
    );
  }

  RuleStoreSnapshot decodeJson(String raw) {
    try {
      return decode(jsonDecode(raw));
    } on FormatException {
      return RuleStoreSnapshot.empty;
    }
  }

  Map<String, dynamic> _profileToJson(RuleProfile p) => {
        'id': p.id,
        'name': p.name,
        'enabled': p.enabled,
        'matchers': p.matchers,
        'cards': p.cards.map(_cardToJson).toList(),
        'rules': p.rules.map(_ruleToJson).toList(),
        'sourceTemplateSlug': p.sourceTemplateSlug,
        'updatedAt': p.updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _cardToJson(ProfileCard c) => {
        'id': c.id,
        'name': c.name,
        'enabled': c.enabled,
        'createdAt': c.createdAt.toUtc().toIso8601String(),
        'updatedAt': c.updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _ruleToJson(StoredRule r) => {
        'cardId': r.cardId,
        'cardName': r.cardName,
        'selector': r.selector,
        'mode': _modeToString(r.mode),
        'frameScope': r.frameScope,
        'createdAt': r.createdAt.toUtc().toIso8601String(),
      };
}
