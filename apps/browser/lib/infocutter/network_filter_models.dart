import 'package:meta/meta.dart';

enum NetworkFilterKind {
  network,
  cosmetic,
  cosmeticException,
  text,
  unsupported,
}

@immutable
class NetworkFilterRule {
  const NetworkFilterRule({
    required this.allow,
    required this.kind,
    required this.modifiers,
    required this.pattern,
    required this.raw,
    required this.skipReason,
  });

  final bool allow;
  final NetworkFilterKind kind;
  final List<String> modifiers;
  final String pattern;
  final String raw;
  final String? skipReason;

  bool get supported => kind == NetworkFilterKind.network && skipReason == null;
}

@immutable
class NetworkFilterImportResult {
  const NetworkFilterImportResult({
    required this.rules,
  });

  final List<NetworkFilterRule> rules;

  int get supportedCount => rules.where((rule) => rule.supported).length;
  int get skippedCount => rules.where((rule) => !rule.supported).length;
}

class NetworkFilterParser {
  const NetworkFilterParser();

  static const _unsupportedModifiers = {
    'badfilter',
    'csp',
    'cookie',
    'elemhide',
    'genericblock',
    'generichide',
    'header',
    'permissions',
    'popup',
    'redirect',
    'redirect-rule',
    'removeheader',
    'removeparam',
    'replace',
  };

  NetworkFilterImportResult parse(String rawList) {
    final rules = rawList
        .split('\n')
        .map(_parseLine)
        .whereType<NetworkFilterRule>()
        .toList();
    return NetworkFilterImportResult(rules: rules);
  }

  NetworkFilterRule? _parseLine(String rawLine) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('!') || line.startsWith('[')) {
      return null;
    }
    final cosmetic = _parseCosmetic(line);
    if (cosmetic != null) return cosmetic;
    return _parseNetwork(line);
  }

  NetworkFilterRule? _parseCosmetic(String line) {
    const markers = ['#@?#', '#?#', '#@#', '##'];
    final marker = markers.where(line.contains).firstOrNull;
    if (marker == null) return null;
    final selector = line.substring(line.indexOf(marker) + marker.length);
    final kind = marker == '#@#' || marker == '#@?#'
        ? NetworkFilterKind.cosmeticException
        : _hasTextCondition(selector)
            ? NetworkFilterKind.text
            : NetworkFilterKind.cosmetic;
    return NetworkFilterRule(
      allow: false,
      kind: kind,
      modifiers: const [],
      pattern: selector.trim(),
      raw: line,
      skipReason: 'not a network request rule',
    );
  }

  NetworkFilterRule _parseNetwork(String line) {
    final allow = line.startsWith('@@');
    final body = allow ? line.substring(2) : line;
    final split = body.split(r'$');
    final pattern = split.first.trim();
    final modifiers = split.length > 1
        ? split[1]
            .split(',')
            .map((modifier) => modifier.trim().toLowerCase())
            .where((modifier) => modifier.isNotEmpty)
            .toList()
        : const <String>[];
    final unsupported = modifiers
        .where((modifier) => _unsupportedModifiers.contains(modifier))
        .toList();
    return NetworkFilterRule(
      allow: allow,
      kind: NetworkFilterKind.network,
      modifiers: modifiers,
      pattern: pattern,
      raw: line,
      skipReason: unsupported.isEmpty
          ? _networkSkipReason(pattern)
          : 'unsupported modifier: ${unsupported.join(', ')}',
    );
  }

  String? _networkSkipReason(String pattern) {
    if (pattern.isEmpty) return 'empty network pattern';
    if (pattern.startsWith('/') && pattern.endsWith('/')) {
      return 'regex network filters are not supported yet';
    }
    return null;
  }

  bool _hasTextCondition(String selector) {
    return selector.contains(':contains(') ||
        selector.contains(':-abp-contains(') ||
        selector.contains(':has-text(');
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
