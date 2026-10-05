final RegExp _urlMatcherPattern =
    RegExp(r'^(\*|https?|http)://([^/*:]+)(:\d+)?(/.*)$');
final RegExp _regexSpecials = RegExp(r'[.+?^${}()|[\]\\]');

String _escapeRegex(String value) =>
    value.replaceAllMapped(_regexSpecials, (match) => '\\${match.group(0)}');

String matcherToUrlFilter(String matcher) {
  final match = _urlMatcherPattern.firstMatch(matcher);
  if (match != null) {
    final scheme = match.group(1);
    final host = match.group(2);
    final port = match.group(3);
    final path = match.group(4);
    if (scheme != null && host != null && path != null) {
      final schemePattern = scheme == '*' ? 'https?' : _escapeRegex(scheme);
      final hostPattern = _escapeRegex(host);
      final portPattern = port == null ? r'(:[0-9]+)?' : _escapeRegex(port);
      final pathPattern = _escapeRegex(path).replaceAll('*', '.*');
      return '^$schemePattern://$hostPattern$portPattern$pathPattern\$';
    }
  }

  return '^${_escapeRegex(matcher).replaceAll('*', '.*')}\$';
}

bool matchesUrl(String matcher, Uri url) {
  try {
    return RegExp(matcherToUrlFilter(matcher)).hasMatch(url.toString());
  } on FormatException {
    return false;
  }
}

String profileNameFromMatcher(String matcher) => matcher
    .replaceFirst(RegExp(r'^\*?:?//'), '')
    .replaceFirst(RegExp(r'/\*$'), '');

String hostnameMatcher(Uri url) => '${url.origin}/*';
