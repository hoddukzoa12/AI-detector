import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:uuid/uuid.dart';

import 'network_filter_models.dart';
import 'storage.dart';

const int networkFilterStorageVersion = 1;
const _uuid = Uuid();

@immutable
class StoredNetworkFilterRule {
  const StoredNetworkFilterRule({
    required this.enabled,
    required this.id,
    required this.rule,
  });

  final bool enabled;
  final String id;
  final NetworkFilterRule rule;

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'id': id,
        'rule': {
          'allow': rule.allow,
          'kind': rule.kind.name,
          'modifiers': rule.modifiers,
          'pattern': rule.pattern,
          'raw': rule.raw,
          'skipReason': rule.skipReason,
        },
      };

  static StoredNetworkFilterRule fromJson(Map<String, Object?> json) {
    final ruleJson = Map<String, Object?>.from(json['rule'] as Map);
    return StoredNetworkFilterRule(
      enabled: json['enabled'] as bool? ?? true,
      id: json['id'] as String? ?? 'inf-${_uuid.v4()}',
      rule: NetworkFilterRule(
        allow: ruleJson['allow'] as bool? ?? false,
        kind: NetworkFilterKind.values.firstWhere(
          (kind) => kind.name == ruleJson['kind'],
          orElse: () => NetworkFilterKind.unsupported,
        ),
        modifiers: (ruleJson['modifiers'] as List<dynamic>? ?? const [])
            .map((modifier) => modifier.toString())
            .toList(),
        pattern: ruleJson['pattern'] as String? ?? '',
        raw: ruleJson['raw'] as String? ?? '',
        skipReason: ruleJson['skipReason'] as String?,
      ),
    );
  }
}

@immutable
class NetworkFilterSnapshot {
  const NetworkFilterSnapshot({
    required this.globalEnabled,
    required this.rules,
  });

  static const empty = NetworkFilterSnapshot(
    globalEnabled: true,
    rules: [],
  );

  final bool globalEnabled;
  final List<StoredNetworkFilterRule> rules;

  Map<String, Object?> toJson() => {
        'version': networkFilterStorageVersion,
        'globalEnabled': globalEnabled,
        'rules': rules.map((rule) => rule.toJson()).toList(),
      };

  static NetworkFilterSnapshot fromJson(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final rules = (decoded['rules'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => StoredNetworkFilterRule.fromJson(
              Map<String, Object?>.from(item),
            ))
        .toList();
    return NetworkFilterSnapshot(
      globalEnabled: decoded['globalEnabled'] as bool? ?? true,
      rules: rules,
    );
  }
}

@immutable
class NetworkFilterImportSummary {
  const NetworkFilterImportSummary({
    required this.imported,
    required this.skipped,
  });

  final int imported;
  final int skipped;
}

@immutable
class NetworkFilterMatch {
  const NetworkFilterMatch({
    required this.rule,
  });

  final StoredNetworkFilterRule rule;
}

class NetworkFilterService extends ChangeNotifier {
  NetworkFilterService({
    NetworkFilterParser parser = const NetworkFilterParser(),
    NetworkFilterStore? store,
  })  : _parser = parser,
        _store = store ?? const SharedPreferencesNetworkFilterStore();

  final NetworkFilterParser _parser;
  final NetworkFilterStore _store;

  NetworkFilterSnapshot _snapshot = NetworkFilterSnapshot.empty;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  bool get globalEnabled => _snapshot.globalEnabled;
  List<StoredNetworkFilterRule> get rules => List.unmodifiable(_snapshot.rules);

  Future<void> load() async {
    final raw = await _store.loadNetworkFilterStoreJson();
    if (raw != null && raw.isNotEmpty) {
      _snapshot = NetworkFilterSnapshot.fromJson(raw);
    }
    _loaded = true;
    notifyListeners();
  }

  /// Serialize the whole module (rules + global toggle) for the config bundle.
  String exportJson() => jsonEncode(_snapshot.toJson());

  /// Replace the whole module from a previously [exportJson]-ed string.
  Future<void> importJson(String raw) =>
      _commit(NetworkFilterSnapshot.fromJson(raw));

  Future<void> setGlobalEnabled(bool enabled) {
    return _commit(
      NetworkFilterSnapshot(
        globalEnabled: enabled,
        rules: _snapshot.rules,
      ),
    );
  }

  Future<NetworkFilterImportSummary> importRawList(String rawList) async {
    final parsed = _parser.parse(rawList);
    final importedRules = parsed.rules
        .where((rule) => rule.supported)
        .map(
          (rule) => StoredNetworkFilterRule(
            enabled: true,
            id: 'inf-${_uuid.v4()}',
            rule: rule,
          ),
        )
        .toList();

    await _commit(
      NetworkFilterSnapshot(
        globalEnabled: _snapshot.globalEnabled,
        rules: [..._snapshot.rules, ...importedRules],
      ),
    );

    return NetworkFilterImportSummary(
      imported: importedRules.length,
      skipped: parsed.skippedCount,
    );
  }

  /// #16 필터 목록 URL 구독 — GET 후 [importRawList]. 오프라인·비-2xx 는 throw.
  Future<NetworkFilterImportSummary> importFromUrl(
    String listUrl, {
    HttpClient? client,
  }) async {
    final uri = Uri.tryParse(listUrl.trim());
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      throw ArgumentError.value(listUrl, 'listUrl', 'http(s) URL required');
    }
    final http = client ?? HttpClient();
    final owned = client == null;
    try {
      final request = await http.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'InfocutterBrowser/3.1');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'filter list HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      final body = await response.transform(utf8.decoder).join();
      return importRawList(body);
    } finally {
      if (owned) {
        http.close(force: true);
      }
    }
  }

  Future<void> setRuleEnabled(String ruleId, bool enabled) {
    return _commit(
      NetworkFilterSnapshot(
        globalEnabled: _snapshot.globalEnabled,
        rules: _snapshot.rules
            .map(
              (stored) => stored.id == ruleId
                  ? StoredNetworkFilterRule(
                      enabled: enabled,
                      id: stored.id,
                      rule: stored.rule,
                    )
                  : stored,
            )
            .toList(),
      ),
    );
  }

  Future<void> removeRule(String ruleId) {
    return _commit(
      NetworkFilterSnapshot(
        globalEnabled: _snapshot.globalEnabled,
        rules: _snapshot.rules.where((rule) => rule.id != ruleId).toList(),
      ),
    );
  }

  NetworkFilterMatch? match(Uri url) {
    if (!_snapshot.globalEnabled || !_isHttpUrl(url)) return null;
    final enabledRules = _snapshot.rules
        .where((stored) => stored.enabled && stored.rule.supported)
        .toList();
    final allowMatch = enabledRules
        .where((stored) => stored.rule.allow)
        .where((stored) => matchesNetworkFilterRule(stored.rule, url))
        .firstOrNull;
    if (allowMatch != null) return null;
    final blockMatch = enabledRules
        .where((stored) => !stored.rule.allow)
        .where((stored) => matchesNetworkFilterRule(stored.rule, url))
        .firstOrNull;
    return blockMatch == null ? null : NetworkFilterMatch(rule: blockMatch);
  }

  bool shouldBlock(Uri url) => match(url) != null;

  List<ContentBlocker> buildContentBlockers() {
    if (!_snapshot.globalEnabled) return const [];
    final enabledRules = _snapshot.rules
        .where((stored) => stored.enabled && stored.rule.supported)
        .toList();
    if (enabledRules.any((stored) => stored.rule.allow)) {
      return const [];
    }
    final blockRules = enabledRules.where((stored) => !stored.rule.allow);
    return [
      ...blockRules.map(
        (stored) => _buildContentBlocker(
          stored.rule,
          ContentBlockerActionType.BLOCK,
        ),
      ),
    ];
  }

  Future<void> _commit(NetworkFilterSnapshot snapshot) async {
    _snapshot = snapshot;
    await _store.saveNetworkFilterStoreJson(jsonEncode(snapshot.toJson()));
    notifyListeners();
  }
}

ContentBlocker _buildContentBlocker(
  NetworkFilterRule rule,
  ContentBlockerActionType actionType,
) =>
    ContentBlocker(
      trigger: ContentBlockerTrigger(
        urlFilter: networkFilterPatternToUrlFilter(rule.pattern),
      ),
      action: ContentBlockerAction(type: actionType),
    );

String networkFilterPatternToUrlFilter(String pattern) {
  final trimmed = pattern.trim();
  if (trimmed.isEmpty) return r'$.';
  if (trimmed.startsWith('||')) {
    final host = trimmed.substring(2).split(RegExp(r'[\^/$]')).first;
    if (host.isEmpty) return r'$.';
    final escapedHost = RegExp.escape(host).replaceAll(r'\*', '.*');
    return r'^[a-z][a-z0-9+.-]*://([^/?#]+\.)?'
        '$escapedHost'
        r'(?::\d+)?(?:[/?:#]|$).*';
  }
  if (trimmed.startsWith('|')) {
    return '^${_networkFilterPatternBodyToRegex(trimmed.substring(1))}';
  }
  return '.*${_networkFilterPatternBodyToRegex(trimmed)}.*';
}

String _networkFilterPatternBodyToRegex(String pattern) {
  final buffer = StringBuffer();
  for (var index = 0; index < pattern.length; index += 1) {
    final char = pattern[index];
    if (char == '*') {
      buffer.write('.*');
    } else if (char == '^') {
      buffer.write(r'(?:[^\w\d_.%-]|$)');
    } else {
      buffer.write(RegExp.escape(char));
    }
  }
  return buffer.toString();
}

bool matchesNetworkFilterRule(NetworkFilterRule rule, Uri url) {
  if (!rule.supported || !_isHttpUrl(url)) return false;
  final pattern = rule.pattern.trim();
  if (pattern.isEmpty) return false;
  if (pattern.startsWith('||')) {
    return _matchesDomainAnchoredPattern(pattern, url);
  }
  if (pattern.startsWith('|')) {
    return url.toString().startsWith(pattern.substring(1));
  }
  if (pattern.contains('*')) {
    final regex = RegExp(
      '^${pattern.split('*').map(RegExp.escape).join('.*')}\$',
      caseSensitive: false,
    );
    return regex.hasMatch(url.toString());
  }
  return url.toString().toLowerCase().contains(pattern.toLowerCase());
}

bool _matchesDomainAnchoredPattern(String pattern, Uri url) {
  final domainPattern =
      pattern.substring(2).split(RegExp(r'[\^/$]')).first.toLowerCase();
  if (domainPattern.isEmpty) return false;
  final host = url.host.toLowerCase();
  return host == domainPattern || host.endsWith('.$domainPattern');
}

bool _isHttpUrl(Uri url) => url.scheme == 'http' || url.scheme == 'https';

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
