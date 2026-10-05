import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'storage.dart';
import 'text_block_models.dart';
import 'url_matcher.dart';

const _uuid = Uuid();

@immutable
class TextBlockRuleRequest {
  const TextBlockRuleRequest({
    required this.url,
    required this.keyword,
    this.objectName = '',
    this.objectTags = defaultHiddenObjectTags,
    this.minMatchCount = 2,
    this.fingerprint,
  });

  final Uri url;
  final String keyword;
  final String objectName;
  final List<String> objectTags;
  final int minMatchCount;
  final String? fingerprint;
}

class TextBlockService extends ChangeNotifier {
  TextBlockService({
    TextBlockCodec? codec,
    TextBlockStore? store,
  })  : _codec = codec ?? const TextBlockCodec(),
        _store = store ?? const SharedPreferencesTextBlockStore();

  final TextBlockCodec _codec;
  final TextBlockStore _store;

  TextBlockStoreSnapshot _snapshot = TextBlockStoreSnapshot.empty;
  bool _loaded = false;

  TextBlockStoreSnapshot get snapshot => _snapshot;
  bool get isLoaded => _loaded;
  bool get globalEnabled => _snapshot.globalEnabled;
  List<TextBlockProfile> get profiles => List.unmodifiable(_snapshot.profiles);

  Future<void> load() async {
    final raw = await _store.loadTextBlockStoreJson();
    if (raw != null && raw.isNotEmpty) {
      _snapshot = _codec.decodeJson(raw);
    }
    _loaded = true;
    notifyListeners();
  }

  /// Serialize the whole module (keyword rules + global toggle) for the bundle.
  String exportJson() => _codec.encodeJson(_snapshot);

  /// Replace the whole module from a previously [exportJson]-ed string.
  Future<void> importJson(String raw) => _commit(_codec.decodeJson(raw));

  Future<void> setGlobalEnabled(bool enabled) {
    return _commit(
      TextBlockStoreSnapshot(
        globalEnabled: enabled,
        hiddenObjectTags: _snapshot.hiddenObjectTags,
        profiles: _snapshot.profiles,
      ),
    );
  }

  Future<void> setHiddenObjectTags(List<String> tags) {
    return _commit(
      TextBlockStoreSnapshot(
        globalEnabled: _snapshot.globalEnabled,
        hiddenObjectTags: normalizeObjectTags(tags),
        profiles: _snapshot.profiles,
      ),
    );
  }

  Future<TextBlockRule> addRuleForUrl(TextBlockRuleRequest request) async {
    final normalizedKeyword = request.keyword.trim();
    _validateRuleRequest(request, normalizedKeyword);
    final now = DateTime.now().toUtc();
    final profiles = [..._snapshot.profiles];
    final profileIndex = _ensureProfileForUrl(profiles, request.url, now);
    final profile = profiles[profileIndex];
    final rule = _buildRule(request, normalizedKeyword, now);

    profiles[profileIndex] = _profileWithRule(profile, rule, now);
    await _commit(_snapshotWithProfiles(profiles));
    return rule;
  }

  void _validateRuleRequest(
    TextBlockRuleRequest request,
    String normalizedKeyword,
  ) {
    if (request.url.host.isEmpty) {
      throw ArgumentError.value(
        request.url.toString(),
        'url',
        'URL must include host',
      );
    }
    if (normalizedKeyword.isEmpty) {
      throw ArgumentError.value(
        request.keyword,
        'keyword',
        'keyword must not be empty',
      );
    }
  }

  int _ensureProfileForUrl(
    List<TextBlockProfile> profiles,
    Uri url,
    DateTime now,
  ) {
    final existingIndex = profiles.indexWhere(
      (profile) => profile.matchers.any((matcher) => matchesUrl(matcher, url)),
    );
    if (existingIndex >= 0) return existingIndex;

    profiles.add(
      TextBlockProfile(
        enabled: true,
        id: 'itb-${_uuid.v4()}',
        matchers: [hostnameMatcher(url)],
        name: url.host.toLowerCase(),
        rules: const [],
        updatedAt: now,
      ),
    );
    return profiles.length - 1;
  }

  TextBlockRule _buildRule(
    TextBlockRuleRequest request,
    String normalizedKeyword,
    DateTime now,
  ) =>
      TextBlockRule(
        createdAt: now,
        enabled: true,
        fingerprint: _normalizedFingerprint(request.fingerprint),
        id: 'itb-${_uuid.v4()}',
        keyword: normalizedKeyword,
        minMatchCount: request.minMatchCount < 2 ? 2 : request.minMatchCount,
        objectId: 'itb-${_uuid.v4()}',
        objectName: request.objectName.trim().isEmpty
            ? normalizedKeyword
            : request.objectName,
        objectTags: normalizeObjectTags(request.objectTags),
        updatedAt: now,
      );

  String? _normalizedFingerprint(String? fingerprint) {
    if (fingerprint == null || fingerprint.trim().isEmpty) return null;
    return fingerprint;
  }

  TextBlockProfile _profileWithRule(
    TextBlockProfile profile,
    TextBlockRule rule,
    DateTime now,
  ) =>
      TextBlockProfile(
        enabled: profile.enabled,
        id: profile.id,
        matchers: profile.matchers,
        name: profile.name,
        rules: [...profile.rules, rule],
        updatedAt: now,
      );

  TextBlockStoreSnapshot _snapshotWithProfiles(
    List<TextBlockProfile> profiles,
  ) =>
      TextBlockStoreSnapshot(
        globalEnabled: _snapshot.globalEnabled,
        hiddenObjectTags: _snapshot.hiddenObjectTags,
        profiles: profiles,
      );

  Future<void> setProfileEnabled(String profileId, bool enabled) {
    return _updateProfile(
      profileId,
      (profile, now) => TextBlockProfile(
        enabled: enabled,
        id: profile.id,
        matchers: profile.matchers,
        name: profile.name,
        rules: profile.rules,
        updatedAt: now,
      ),
    );
  }

  Future<void> setRuleEnabled(String profileId, String ruleId, bool enabled) {
    return _updateProfile(
      profileId,
      (profile, now) => TextBlockProfile(
        enabled: profile.enabled,
        id: profile.id,
        matchers: profile.matchers,
        name: profile.name,
        rules: profile.rules
            .map(
              (rule) => rule.id == ruleId
                  ? TextBlockRule(
                      createdAt: rule.createdAt,
                      enabled: enabled,
                      fingerprint: rule.fingerprint,
                      id: rule.id,
                      keyword: rule.keyword,
                      minMatchCount: rule.minMatchCount,
                      objectId: rule.objectId,
                      objectName: rule.objectName,
                      objectTags: rule.objectTags,
                      updatedAt: now,
                    )
                  : rule,
            )
            .toList(),
        updatedAt: now,
      ),
    );
  }

  Future<void> removeRule(String profileId, String ruleId) {
    return _updateProfile(
      profileId,
      (profile, now) => TextBlockProfile(
        enabled: profile.enabled,
        id: profile.id,
        matchers: profile.matchers,
        name: profile.name,
        rules: profile.rules.where((rule) => rule.id != ruleId).toList(),
        updatedAt: now,
      ),
    );
  }

  ActiveTextBlockState buildActiveStateForUrl(Uri url) {
    return buildActiveTextBlockState(_snapshot, url);
  }

  Map<String, Object?> buildRuntimeStateForUrl(Uri? url) {
    if (url == null) {
      return {
        'version': textBlockStorageVersion,
        'globalEnabled': _snapshot.globalEnabled,
        'profileEnabled': false,
        'hiddenObjectTags': _snapshot.hiddenObjectTags,
        'rules': const <Object?>[],
      };
    }
    final activeState = buildActiveStateForUrl(url);
    final tagSet = activeState.hiddenObjectTags.toSet();
    return {
      'version': textBlockStorageVersion,
      'url': url.toString(),
      'globalEnabled': activeState.globalEnabled,
      'profileEnabled': activeState.profileEnabled,
      'hiddenObjectTags': activeState.hiddenObjectTags,
      'rules': activeState.rules
          .where((rule) => rule.enabled)
          .where((rule) => rule.objectTags.any(tagSet.contains))
          .map(
            (rule) => {
              'id': rule.id,
              'keyword': rule.keyword,
              'minMatchCount': rule.minMatchCount,
              'fingerprint': rule.fingerprint,
              'objectName': rule.objectName,
              'objectTags': rule.objectTags,
            },
          )
          .toList(),
    };
  }

  Future<void> _updateProfile(
    String profileId,
    TextBlockProfile Function(TextBlockProfile profile, DateTime now) update,
  ) async {
    final index = _snapshot.profiles.indexWhere((p) => p.id == profileId);
    if (index < 0) return;
    final now = DateTime.now().toUtc();
    final profiles = [..._snapshot.profiles];
    profiles[index] = update(profiles[index], now);
    await _commit(
      TextBlockStoreSnapshot(
        globalEnabled: _snapshot.globalEnabled,
        hiddenObjectTags: _snapshot.hiddenObjectTags,
        profiles: profiles,
      ),
    );
  }

  Future<void> _commit(TextBlockStoreSnapshot snapshot) async {
    _snapshot = snapshot;
    await _store.saveTextBlockStoreJson(_codec.encodeJson(snapshot));
    notifyListeners();
  }
}
