import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/search_engine_model.dart';
import 'package:infocutter_app/services/browser_url_resolver.dart';

/// Regression net for the address-bar rule: "is this typed text a URL, or a
/// search query?". Fixes current behaviour so extracting the resolver (or
/// changing the heuristic) shows up as a failure here.
void main() {
  const resolver = BrowserUrlResolver();

  BrowserSettings settingsWith(SearchEngineModel engine) =>
      BrowserSettings(searchEngine: engine);

  final google = BrowserSettings();

  group('treats input as a URL', () {
    test('bare host gains https scheme', () {
      expect(
        resolver.resolve('example.com', google).toString(),
        'https://example.com',
      );
    });

    test('explicit scheme is preserved verbatim', () {
      expect(
        resolver.resolve('http://example.com/a?b=c', google).toString(),
        'http://example.com/a?b=c',
      );
    });

    test('surrounding whitespace is trimmed before resolving', () {
      expect(
        resolver.resolve('  example.com  ', google).toString(),
        'https://example.com',
      );
    });

    test('subdomain and path survive', () {
      expect(
        resolver.resolve('news.example.co.uk/latest', google).toString(),
        'https://news.example.co.uk/latest',
      );
    });

    test('localized-content schemes bypass the dot rule', () {
      // Util.isLocalizedContent: file/chrome/data/javascript/about.
      expect(resolver.resolve('about:blank', google).toString(), 'about:blank');
      expect(
        resolver.resolve('file:///tmp/page', google).toString(),
        'file:///tmp/page',
      );
      expect(
        resolver.resolve('chrome://settings', google).toString(),
        'chrome://settings',
      );
    });
  });

  group('falls back to search', () {
    test('multi-word input becomes a search URL with escaped spaces', () {
      // WebUri normalises the concatenated query, so spaces come back as %20.
      expect(
        resolver.resolve('flutter test net', google).toString(),
        'https://www.google.com/search?q=flutter%20test%20net',
      );
    });

    test('single dotless word becomes a search URL', () {
      expect(
        resolver.resolve('flutter', google).toString(),
        'https://www.google.com/search?q=flutter',
      );
    });

    test('search URL uses the configured engine', () {
      expect(
        resolver
            .resolve('privacy', settingsWith(DuckDuckGoSearchEngine))
            .toString(),
        'https://duckduckgo.com/?q=privacy',
      );
    });

    test('empty input searches for the empty string', () {
      // Current behaviour: an empty address bar does NOT short-circuit; it
      // produces the bare search-engine URL. Change this constant only if the
      // resolver gains an explicit empty-input branch.
      expect(
        resolver.resolve('   ', google).toString(),
        'https://www.google.com/search?q=',
      );
    });
  });
}
