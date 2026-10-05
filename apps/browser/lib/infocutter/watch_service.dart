import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const String infocutterWatchStoreKey = 'infocutter.watchStore';
const int watchStorageVersion = 1;
const _uuid = Uuid();

String _cleanWatchTerm(Object? value) {
  if (value is! String) return '';
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<String> _cleanWatchTerms(Iterable<String> values) {
  final seen = <String>{};
  final terms = <String>[];
  for (final value in values) {
    final term = _cleanWatchTerm(value);
    if (term.isEmpty || seen.contains(term)) continue;
    seen.add(term);
    terms.add(term);
  }
  return terms;
}

@immutable
class WatchTarget {
  const WatchTarget({
    required this.id,
    required this.name,
    required this.aliases,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> aliases;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  WatchTarget copyWith({
    String? id,
    String? name,
    List<String>? aliases,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      WatchTarget(
        id: id ?? this.id,
        name: name ?? this.name,
        aliases: aliases ?? this.aliases,
        enabled: enabled ?? this.enabled,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

@immutable
class WatchDetection {
  const WatchDetection({
    required this.targetId,
    required this.term,
    required this.url,
    required this.pageTitle,
    required this.matchedText,
    required this.tag,
    required this.detectedAt,
  });

  final String targetId;
  final String term;
  final String url;
  final String pageTitle;
  final String matchedText;
  final String tag;
  final DateTime detectedAt;

  static WatchDetection? tryParse(List<dynamic> args) {
    if (args.isEmpty || args.first is! Map) return null;
    final raw = args.first as Map;
    final term = _cleanWatchTerm(raw['term']);
    final url = _cleanWatchTerm(raw['url']);
    if (term.isEmpty || url.isEmpty) return null;
    return WatchDetection(
      targetId: _cleanWatchTerm(raw['targetId']),
      term: term,
      url: url,
      pageTitle: _cleanWatchTerm(raw['pageTitle']),
      matchedText: _cleanWatchTerm(raw['matchedText']),
      tag: _cleanWatchTerm(raw['tag']),
      detectedAt: DateTime.now().toUtc(),
    );
  }
}

@immutable
class WatchStoreSnapshot {
  const WatchStoreSnapshot({
    required this.globalEnabled,
    required this.autoMask,
    required this.targets,
  });

  final bool globalEnabled;
  final bool autoMask;
  final List<WatchTarget> targets;

  WatchStoreSnapshot copyWith({
    bool? globalEnabled,
    bool? autoMask,
    List<WatchTarget>? targets,
  }) =>
      WatchStoreSnapshot(
        globalEnabled: globalEnabled ?? this.globalEnabled,
        autoMask: autoMask ?? this.autoMask,
        targets: targets ?? this.targets,
      );

  static const empty = WatchStoreSnapshot(
    globalEnabled: true,
    autoMask: true,
    targets: [],
  );
}

abstract interface class WatchStore {
  Future<String?> loadWatchStoreJson();

  Future<void> saveWatchStoreJson(String raw);
}

class SharedPreferencesWatchStore implements WatchStore {
  const SharedPreferencesWatchStore({
    this.storageKey = infocutterWatchStoreKey,
  });

  final String storageKey;

  @override
  Future<String?> loadWatchStoreJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey);
  }

  @override
  Future<void> saveWatchStoreJson(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, raw);
  }
}

class WatchService extends ChangeNotifier {
  WatchService({
    WatchStore? store,
  }) : _store = store ?? const SharedPreferencesWatchStore();

  final WatchStore _store;

  WatchStoreSnapshot _snapshot = WatchStoreSnapshot.empty;
  bool _loaded = false;

  WatchStoreSnapshot get snapshot => _snapshot;
  bool get isLoaded => _loaded;
  bool get globalEnabled => _snapshot.globalEnabled;
  bool get autoMask => _snapshot.autoMask;
  List<WatchTarget> get targets => List.unmodifiable(_snapshot.targets);
  final List<WatchDetection> _detections = [];
  List<WatchDetection> get recentDetections => List.unmodifiable(_detections);

  Future<void> load() async {
    final raw = await _store.loadWatchStoreJson();
    if (raw != null && raw.isNotEmpty) {
      _snapshot = _decodeJson(raw);
    }
    _loaded = true;
    notifyListeners();
  }

  /// Serialize the whole module (watch targets + toggles) for the bundle.
  String exportJson() => _encodeJson(_snapshot);

  /// Replace the whole module from a previously [exportJson]-ed string.
  Future<void> importJson(String raw) => _commit(_decodeJson(raw));

  Future<void> setGlobalEnabled(bool value) {
    return _commit(_snapshot.copyWith(globalEnabled: value));
  }

  Future<void> setAutoMask(bool value) {
    return _commit(_snapshot.copyWith(autoMask: value));
  }

  Future<WatchTarget> addTarget({
    required String name,
    List<String> aliases = const [],
  }) async {
    final now = DateTime.now().toUtc();
    final target = WatchTarget(
      id: 'iw-${_uuid.v4()}',
      name: _cleanWatchTerm(name),
      aliases: _cleanWatchTerms(aliases),
      enabled: true,
      createdAt: now,
      updatedAt: now,
    );
    if (target.name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'name must not be empty');
    }
    await _commit(
      _snapshot.copyWith(targets: [..._snapshot.targets, target]),
    );
    return target;
  }

  Future<void> removeTarget(String id) {
    return _commit(
      _snapshot.copyWith(
        targets: _snapshot.targets.where((target) => target.id != id).toList(),
      ),
    );
  }

  Future<void> setTargetEnabled(String id, bool enabled) {
    final now = DateTime.now().toUtc();
    return _commit(
      _snapshot.copyWith(
        targets: _snapshot.targets
            .map(
              (target) => target.id == id
                  ? target.copyWith(enabled: enabled, updatedAt: now)
                  : target,
            )
            .toList(),
      ),
    );
  }

  void recordDetection(WatchDetection detection) {
    final duplicateIndex = _detections.indexWhere(
      (item) =>
          item.url == detection.url &&
          item.targetId == detection.targetId &&
          item.term.toLowerCase() == detection.term.toLowerCase() &&
          item.matchedText == detection.matchedText,
    );
    if (duplicateIndex >= 0) {
      _detections.removeAt(duplicateIndex);
    }
    _detections.insert(0, detection);
    if (_detections.length > 50) {
      _detections.removeRange(50, _detections.length);
    }
    notifyListeners();
  }

  Map<String, Object?> buildRuntimeState() => {
        'version': watchStorageVersion,
        'globalEnabled': _snapshot.globalEnabled,
        'autoMask': _snapshot.autoMask,
        'terms': _snapshot.targets
            .where((target) => target.enabled)
            .expand(
              (target) => [target.name, ...target.aliases].map(
                (term) => {
                  'targetId': target.id,
                  'term': term,
                },
              ),
            )
            .toList(),
      };

  List<String> activeTerms() {
    final terms = <String>{};
    if (!_snapshot.globalEnabled) return const [];
    for (final target in _snapshot.targets) {
      if (!target.enabled) continue;
      for (final term in [target.name, ...target.aliases]) {
        final normalized = term.toLowerCase();
        if (normalized.length >= 2) {
          terms.add(normalized);
        }
      }
    }
    return terms.toList();
  }

  Future<void> _commit(WatchStoreSnapshot snapshot) async {
    _snapshot = snapshot;
    await _store.saveWatchStoreJson(_encodeJson(snapshot));
    notifyListeners();
  }

  static WatchStoreSnapshot _decodeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return WatchStoreSnapshot.empty;
      if (decoded['version'] != null &&
          decoded['version'] != watchStorageVersion) {
        return WatchStoreSnapshot.empty;
      }
      final settings = decoded['settings'];
      final rawTargets = decoded['targets'];
      return WatchStoreSnapshot(
        globalEnabled: settings is Map && settings['globalEnabled'] is bool
            ? settings['globalEnabled'] as bool
            : true,
        autoMask: settings is Map && settings['autoMask'] is bool
            ? settings['autoMask'] as bool
            : true,
        targets: rawTargets is List
            ? rawTargets.map(_decodeTarget).whereType<WatchTarget>().toList()
            : const [],
      );
    } on FormatException {
      return WatchStoreSnapshot.empty;
    }
  }

  static WatchTarget? _decodeTarget(Object? raw) {
    if (raw is! Map) return null;
    final name = _cleanWatchTerm(raw['name']);
    if (name.isEmpty) return null;
    final now = DateTime.now().toUtc();
    return WatchTarget(
      id: raw['id'] is String && (raw['id'] as String).isNotEmpty
          ? raw['id'] as String
          : 'iw-${_uuid.v4()}',
      name: name,
      aliases: raw['aliases'] is List
          ? _cleanWatchTerms((raw['aliases'] as List).whereType<String>())
          : const [],
      enabled: raw['enabled'] is bool ? raw['enabled'] as bool : true,
      createdAt: _parseDate(raw['createdAt']) ?? now,
      updatedAt: _parseDate(raw['updatedAt']) ?? now,
    );
  }

  static String _encodeJson(WatchStoreSnapshot snapshot) => jsonEncode({
        'version': watchStorageVersion,
        'settings': {
          'globalEnabled': snapshot.globalEnabled,
          'autoMask': snapshot.autoMask,
        },
        'targets': snapshot.targets
            .map(
              (target) => {
                'id': target.id,
                'name': target.name,
                'aliases': target.aliases,
                'enabled': target.enabled,
                'createdAt': target.createdAt.toUtc().toIso8601String(),
                'updatedAt': target.updatedAt.toUtc().toIso8601String(),
              },
            )
            .toList(),
      });

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}
