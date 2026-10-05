import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/models/favorite_model.dart';
import 'package:infocutter_app/services/address_suggestions.dart';

void main() {
  const engine = AddressSuggestions();

  test('empty query yields nothing', () {
    expect(
      engine.suggest(
        AddressSuggestionQuery(
          query: '  ',
          favorites: [
            FavoriteModel(url: WebUri('https://a.com'), title: 'A'),
          ],
          openTabUrls: const ['https://b.com'],
          recentUrls: const ['https://c.com'],
        ),
      ),
      isEmpty,
    );
  });

  test('matches favorites before open tabs and de-dupes', () {
    final out = engine.suggest(
      AddressSuggestionQuery(
        query: 'exam',
        favorites: [
          FavoriteModel(url: WebUri('https://example.com'), title: 'Example'),
        ],
        openTabUrls: const ['https://example.com/page', 'https://other.com'],
        recentUrls: const ['https://example.org'],
      ),
    );
    expect(out.map((e) => e.url).toList(), [
      'https://example.com',
      'https://example.com/page',
      'https://example.org',
    ]);
    expect(out.first.source, AddressSuggestionSource.favorite);
  });

  test('limit stops collecting after N hits', () {
    final out = engine.suggest(
      AddressSuggestionQuery(
        query: 'x',
        favorites: const [],
        openTabUrls: [
          for (var i = 0; i < 20; i++) 'https://x$i.example.com',
        ],
        recentUrls: const [],
        limit: 3,
      ),
    );
    expect(out, hasLength(3));
  });
}
