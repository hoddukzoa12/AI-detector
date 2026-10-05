import 'dart:convert';

import 'package:meta/meta.dart';

import 'url_matcher.dart';

const int textBlockStorageVersion = 1;
const List<String> defaultHiddenObjectTags = ['ad'];

@immutable
class TextBlockRule {
  const TextBlockRule({
    required this.createdAt,
    required this.enabled,
    required this.fingerprint,
    required this.id,
    required this.keyword,
    required this.minMatchCount,
    required this.objectId,
    required this.objectName,
    required this.objectTags,
    required this.updatedAt,
  });

  final DateTime createdAt;
  final bool enabled;
  final String? fingerprint;
  final String id;
  final String keyword;
  final int minMatchCount;
  final String objectId;
  final String objectName;
  final List<String> objectTags;
  final DateTime updatedAt;
}

@immutable
class TextBlockProfile {
  const TextBlockProfile({
    required this.enabled,
    required this.id,
    required this.matchers,
    required this.name,
    required this.rules,
    required this.updatedAt,
  });

  final bool enabled;
  final String id;
  final List<String> matchers;
  final String name;
  final List<TextBlockRule> rules;
  final DateTime updatedAt;
}

@immutable
class TextBlockStoreSnapshot {
  const TextBlockStoreSnapshot({
    required this.globalEnabled,
    required this.hiddenObjectTags,
    required this.profiles,
  });

  final bool globalEnabled;
  final List<String> hiddenObjectTags;
  final List<TextBlockProfile> profiles;

  static const empty = TextBlockStoreSnapshot(
    globalEnabled: false,
    hiddenObjectTags: defaultHiddenObjectTags,
    profiles: [],
  );
}

@immutable
class ActiveTextBlockState {
  const ActiveTextBlockState({
    required this.activeProfileId,
    required this.activeProfileName,
    required this.globalEnabled,
    required this.hiddenObjectTags,
    required this.matchers,
    required this.profileEnabled,
    required this.ruleCount,
    required this.rules,
    required this.updatedAt,
    required this.url,
  });

  final String? activeProfileId;
  final String? activeProfileName;
  final bool globalEnabled;
  final List<String> hiddenObjectTags;
  final List<String> matchers;
  final bool profileEnabled;
  final int ruleCount;
  final List<TextBlockRule> rules;
  final DateTime updatedAt;
  final Uri url;
}

class TextBlockCodec {
  const TextBlockCodec();

  TextBlockStoreSnapshot decodeJson(String raw) {
    try {
      return decode(jsonDecode(raw));
    } on FormatException {
      return TextBlockStoreSnapshot.empty;
    }
  }

  TextBlockStoreSnapshot decode(Object? raw) {
    if (raw is! Map || raw['version'] != textBlockStorageVersion) {
      return TextBlockStoreSnapshot.empty;
    }
    final settings = raw['settings'];
    final profilesRaw = raw['profiles'];
    return TextBlockStoreSnapshot(
      globalEnabled: settings is Map && settings['globalEnabled'] == true,
      hiddenObjectTags: settings is Map
          ? normalizeObjectTags(settings['hiddenObjectTags'])
          : defaultHiddenObjectTags,
      profiles: profilesRaw is List
          ? profilesRaw
              .map(_decodeProfile)
              .whereType<TextBlockProfile>()
              .toList()
          : const [],
    );
  }

  String encodeJson(TextBlockStoreSnapshot snapshot) =>
      jsonEncode(encode(snapshot));

  Map<String, Object?> encode(TextBlockStoreSnapshot snapshot) => {
        'version': textBlockStorageVersion,
        'settings': {
          'globalEnabled': snapshot.globalEnabled,
          'hiddenObjectTags': normalizeObjectTags(snapshot.hiddenObjectTags),
        },
        'profiles': snapshot.profiles.map(_profileToJson).toList(),
      };

  TextBlockProfile? _decodeProfile(Object? raw) {
    if (raw is! Map) return null;
    final id = _string(raw['id']);
    final name = _string(raw['name']);
    final rulesRaw = raw['rules'];
    return TextBlockProfile(
      enabled: raw['enabled'] is bool ? raw['enabled'] as bool : true,
      id: id == null || id.isEmpty ? 'itb-profile' : id,
      matchers: _stringList(raw['matchers']),
      name: name == null || name.isEmpty ? '이름 없는 텍스트 프로필' : name,
      rules: rulesRaw is List
          ? rulesRaw.map(_decodeRule).whereType<TextBlockRule>().toList()
          : const [],
      updatedAt: _parseTime(raw['updatedAt']),
    );
  }

  TextBlockRule? _decodeRule(Object? raw) {
    if (raw is! Map) return null;
    final keyword = _string(raw['keyword'])?.trim();
    if (keyword == null || keyword.isEmpty) return null;
    final id = _string(raw['id']);
    final objectId = _string(raw['objectId']);
    final objectName = _string(raw['objectName']);
    final createdAt = _parseTime(raw['createdAt']);
    return TextBlockRule(
      createdAt: createdAt,
      enabled: raw['enabled'] is bool ? raw['enabled'] as bool : true,
      fingerprint: _nonEmptyString(raw['fingerprint']),
      id: id == null || id.isEmpty ? 'itb-rule' : id,
      keyword: keyword,
      minMatchCount: _minMatchCount(raw['minMatchCount']),
      objectId: objectId == null || objectId.isEmpty
          ? (id == null || id.isEmpty ? 'itb-object' : id)
          : objectId,
      objectName:
          objectName == null || objectName.isEmpty ? keyword : objectName,
      objectTags: normalizeObjectTags(raw['objectTags']),
      updatedAt:
          raw['updatedAt'] is String ? _parseTime(raw['updatedAt']) : createdAt,
    );
  }

  Map<String, Object?> _profileToJson(TextBlockProfile profile) => {
        'enabled': profile.enabled,
        'id': profile.id,
        'matchers': profile.matchers,
        'name': profile.name,
        'rules': profile.rules.map(_ruleToJson).toList(),
        'updatedAt': profile.updatedAt.toUtc().toIso8601String(),
      };

  Map<String, Object?> _ruleToJson(TextBlockRule rule) => {
        'createdAt': rule.createdAt.toUtc().toIso8601String(),
        'enabled': rule.enabled,
        'fingerprint': rule.fingerprint,
        'id': rule.id,
        'keyword': rule.keyword,
        'minMatchCount': rule.minMatchCount,
        'objectId': rule.objectId,
        'objectName': rule.objectName,
        'objectTags': normalizeObjectTags(rule.objectTags),
        'updatedAt': rule.updatedAt.toUtc().toIso8601String(),
      };
}

ActiveTextBlockState buildActiveTextBlockState(
  TextBlockStoreSnapshot snapshot,
  Uri url,
) {
  final profile = _findMatchingProfile(snapshot, url);
  return ActiveTextBlockState(
    activeProfileId: profile?.id,
    activeProfileName: profile?.name,
    globalEnabled: snapshot.globalEnabled,
    hiddenObjectTags: snapshot.hiddenObjectTags,
    matchers: profile?.matchers ?? const [],
    profileEnabled: profile?.enabled ?? false,
    ruleCount: profile?.rules.length ?? 0,
    rules: profile?.rules ?? const [],
    updatedAt: profile?.updatedAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    url: url,
  );
}

TextBlockProfile? _findMatchingProfile(
  TextBlockStoreSnapshot snapshot,
  Uri url,
) {
  for (final profile in snapshot.profiles) {
    if (profile.matchers.any((m) => matchesUrl(m, url))) {
      return profile;
    }
  }
  return null;
}

List<String> normalizeObjectTags(Object? raw) {
  if (raw is! List) return defaultHiddenObjectTags;
  final tags = raw
      .whereType<String>()
      .map((tag) => tag.trim().toLowerCase())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList();
  return tags.isEmpty ? defaultHiddenObjectTags : tags;
}

String? _string(Object? raw) => raw is String ? raw : null;

String? _nonEmptyString(Object? raw) {
  final value = _string(raw);
  return value == null || value.isEmpty ? null : value;
}

List<String> _stringList(Object? raw) => raw is List
    ? raw
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList()
    : const [];

DateTime _parseTime(Object? raw) {
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.toUtc();
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

int _minMatchCount(Object? raw) {
  if (raw is num && raw >= 2) return raw.floor();
  return 2;
}
