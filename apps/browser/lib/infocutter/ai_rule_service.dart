import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'ai_masking_service.dart';

const String infocutterAiRuleStoreKey = 'infocutter.aiGeneratedRules';
const int aiRuleStorageVersion = 1;
const _uuid = Uuid();

@immutable
class GeneratedAiRule {
  const GeneratedAiRule({
    required this.confidence,
    required this.createdAt,
    required this.host,
    required this.id,
    required this.label,
    required this.reason,
    required this.selector,
    required this.url,
    this.appliedAt,
  });

  final DateTime? appliedAt;
  final double confidence;
  final DateTime createdAt;
  final String host;
  final String id;
  final String label;
  final String reason;
  final String selector;
  final String url;

  bool get applied => appliedAt != null;
}

@immutable
class AiRuleStoreSnapshot {
  const AiRuleStoreSnapshot({
    required this.rules,
  });

  static const empty = AiRuleStoreSnapshot(rules: []);

  final List<GeneratedAiRule> rules;
}

abstract interface class AiRuleStore {
  Future<String?> loadAiRuleStoreJson();

  Future<void> saveAiRuleStoreJson(String raw);
}

class SharedPreferencesAiRuleStore implements AiRuleStore {
  const SharedPreferencesAiRuleStore({
    this.storageKey = infocutterAiRuleStoreKey,
  });

  final String storageKey;

  @override
  Future<String?> loadAiRuleStoreJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey);
  }

  @override
  Future<void> saveAiRuleStoreJson(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, raw);
  }
}

class AiRuleService extends ChangeNotifier {
  AiRuleService({
    AiRuleStore? store,
  }) : _store = store ?? const SharedPreferencesAiRuleStore();

  final AiRuleStore _store;

  AiRuleStoreSnapshot _snapshot = AiRuleStoreSnapshot.empty;
  bool _loaded = false;

  AiRuleStoreSnapshot get snapshot => _snapshot;
  bool get isLoaded => _loaded;
  List<GeneratedAiRule> get rules => List.unmodifiable(_snapshot.rules);

  Future<void> load() async {
    final raw = await _store.loadAiRuleStoreJson();
    if (raw != null && raw.isNotEmpty) {
      _snapshot = _decodeJson(raw);
    }
    _loaded = true;
    notifyListeners();
  }

  List<GeneratedAiRule> rulesForHost(String host) {
    final normalized = host.trim().toLowerCase();
    return _snapshot.rules
        .where((rule) => rule.host == normalized)
        .toList(growable: false);
  }

  Future<List<GeneratedAiRule>> addSuggestions({
    required Uri url,
    required List<AiMaskingSuggestion> suggestions,
  }) async {
    final host = url.host.toLowerCase();
    final now = DateTime.now().toUtc();
    final next = [..._snapshot.rules];
    for (final suggestion in suggestions) {
      final selector = suggestion.selector.trim();
      if (selector.isEmpty) continue;
      final existingIndex = next.indexWhere(
        (rule) => rule.host == host && rule.selector == selector,
      );
      final generated = GeneratedAiRule(
        appliedAt: existingIndex >= 0 ? next[existingIndex].appliedAt : null,
        confidence: suggestion.confidence,
        createdAt: existingIndex >= 0 ? next[existingIndex].createdAt : now,
        host: host,
        id: existingIndex >= 0 ? next[existingIndex].id : 'iar-${_uuid.v4()}',
        label: suggestion.label,
        reason: suggestion.reason,
        selector: selector,
        url: url.toString(),
      );
      if (existingIndex >= 0) {
        next[existingIndex] = generated;
      } else {
        next.insert(0, generated);
      }
    }
    await _commit(AiRuleStoreSnapshot(rules: next));
    return rulesForHost(host);
  }

  Future<void> markAppliedForSelector({
    required String host,
    required String selector,
  }) {
    final normalizedHost = host.trim().toLowerCase();
    final normalizedSelector = selector.trim();
    final now = DateTime.now().toUtc();
    return _commit(
      AiRuleStoreSnapshot(
        rules: _snapshot.rules
            .map(
              (rule) => rule.host == normalizedHost &&
                      rule.selector == normalizedSelector
                  ? GeneratedAiRule(
                      appliedAt: now,
                      confidence: rule.confidence,
                      createdAt: rule.createdAt,
                      host: rule.host,
                      id: rule.id,
                      label: rule.label,
                      reason: rule.reason,
                      selector: rule.selector,
                      url: rule.url,
                    )
                  : rule,
            )
            .toList(),
      ),
    );
  }

  Future<void> _commit(AiRuleStoreSnapshot snapshot) async {
    _snapshot = snapshot;
    await _store.saveAiRuleStoreJson(_encodeJson(snapshot));
    notifyListeners();
  }

  static AiRuleStoreSnapshot _decodeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return AiRuleStoreSnapshot.empty;
      if (decoded['version'] != null &&
          decoded['version'] != aiRuleStorageVersion) {
        return AiRuleStoreSnapshot.empty;
      }
      final rawRules = decoded['rules'];
      return AiRuleStoreSnapshot(
        rules: rawRules is List
            ? rawRules.map(_decodeRule).whereType<GeneratedAiRule>().toList()
            : const [],
      );
    } on FormatException {
      return AiRuleStoreSnapshot.empty;
    }
  }

  static GeneratedAiRule? _decodeRule(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final selector = raw['selector'];
    final host = raw['host'];
    final createdAt = DateTime.tryParse(raw['createdAt'] as String? ?? '');
    if (id is! String ||
        selector is! String ||
        host is! String ||
        createdAt == null) {
      return null;
    }
    return GeneratedAiRule(
      appliedAt: DateTime.tryParse(raw['appliedAt'] as String? ?? ''),
      confidence:
          raw['confidence'] is num ? (raw['confidence'] as num).toDouble() : 0,
      createdAt: createdAt.toUtc(),
      host: host,
      id: id,
      label: raw['label'] is String ? raw['label'] as String : '',
      reason: raw['reason'] is String ? raw['reason'] as String : '',
      selector: selector,
      url: raw['url'] is String ? raw['url'] as String : '',
    );
  }

  static String _encodeJson(AiRuleStoreSnapshot snapshot) => jsonEncode({
        'version': aiRuleStorageVersion,
        'rules': snapshot.rules
            .map(
              (rule) => {
                'appliedAt': rule.appliedAt?.toUtc().toIso8601String(),
                'confidence': rule.confidence,
                'createdAt': rule.createdAt.toUtc().toIso8601String(),
                'host': rule.host,
                'id': rule.id,
                'label': rule.label,
                'reason': rule.reason,
                'selector': rule.selector,
                'url': rule.url,
              },
            )
            .toList(),
      });
}
