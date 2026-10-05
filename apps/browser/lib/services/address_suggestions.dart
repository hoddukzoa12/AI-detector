import 'package:infocutter_app/models/favorite_model.dart';

/// 주소창 제안 (#15). 즐겨찾기·열린 탭·최근 방문 문자열을 합쳐 필터한다.
class AddressSuggestion {
  const AddressSuggestion({
    required this.url,
    required this.label,
    required this.source,
  });

  final String url;
  final String label;
  final AddressSuggestionSource source;
}

enum AddressSuggestionSource { favorite, openTab, recent }

/// 제안 검색 입력. 메서드 인자 상한을 넘기지 않기 위해 묶는다.
class AddressSuggestionQuery {
  const AddressSuggestionQuery({
    required this.query,
    required this.favorites,
    required this.openTabUrls,
    required this.recentUrls,
    this.limit = 8,
  });

  final String query;
  final Iterable<FavoriteModel> favorites;
  final Iterable<String> openTabUrls;
  final Iterable<String> recentUrls;
  final int limit;
}

class AddressSuggestions {
  const AddressSuggestions();

  /// [query] 가 비면 빈 목록. 소문자 부분 일치, 최대 limit.
  List<AddressSuggestion> suggest(AddressSuggestionQuery input) {
    final q = input.query.trim().toLowerCase();
    if (q.isEmpty) {
      return const [];
    }

    final collector = _SuggestionCollector(query: q, limit: input.limit);
    collector.addFavorites(input.favorites);
    collector.addUrls(input.openTabUrls, AddressSuggestionSource.openTab);
    collector.addUrls(input.recentUrls, AddressSuggestionSource.recent);
    return collector.items;
  }
}

class _SuggestionCollector {
  _SuggestionCollector({required this.query, required this.limit});

  final String query;
  final int limit;
  final List<AddressSuggestion> items = <AddressSuggestion>[];
  final Set<String> _seen = <String>{};

  bool get _full => items.length >= limit;

  void addFavorites(Iterable<FavoriteModel> favorites) {
    for (final fav in favorites) {
      if (_full) {
        return;
      }
      final url = fav.url?.toString();
      final label = fav.title ?? url ?? '';
      _tryAdd(url, label, AddressSuggestionSource.favorite);
    }
  }

  void addUrls(Iterable<String> urls, AddressSuggestionSource source) {
    for (final url in urls) {
      if (_full) {
        return;
      }
      _tryAdd(url, url, source);
    }
  }

  void _tryAdd(
    String? rawUrl,
    String label,
    AddressSuggestionSource source,
  ) {
    final url = (rawUrl ?? '').trim();
    if (url.isEmpty) {
      return;
    }
    final key = url.toLowerCase();
    if (_seen.contains(key)) {
      return;
    }
    if (!'$url $label'.toLowerCase().contains(query)) {
      return;
    }
    _seen.add(key);
    items.add(AddressSuggestion(url: url, label: label, source: source));
  }
}
