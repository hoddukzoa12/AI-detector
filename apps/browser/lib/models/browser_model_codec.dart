import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/favorite_model.dart';
import 'package:infocutter_app/models/web_archive_model.dart';

class BrowserModelCodec {
  const BrowserModelCodec._();

  static List<FavoriteModel> favoritesFromMap(Map<String, dynamic> map) {
    final rawFavorites = map["favorites"];
    final List<Map<String, dynamic>> favoritesList = rawFavorites is List
        ? rawFavorites.cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];
    return favoritesList.map((e) => FavoriteModel.fromMap(e)!).toList();
  }

  static Map<String, WebArchiveModel> webArchivesFromMap(
    Map<String, dynamic> map,
  ) {
    final rawWebArchives = map["webArchives"];
    final Map<String, dynamic> webArchivesMap = rawWebArchives is Map
        ? rawWebArchives.cast<String, dynamic>()
        : <String, dynamic>{};
    return webArchivesMap.map(
      (key, value) => MapEntry(
        key,
        WebArchiveModel.fromMap(value?.cast<String, dynamic>())!,
      ),
    );
  }

  static BrowserSettings settingsFromMap(Map<String, dynamic> map) {
    final rawSettings = map["settings"];
    final settingsMap =
        rawSettings is Map ? rawSettings.cast<String, dynamic>() : null;
    return BrowserSettings.fromMap(settingsMap) ?? BrowserSettings();
  }

  static Map<String, dynamic> toMap(BrowserModel model) {
    return {
      "favorites": model.favorites.map((e) => e.toMap()).toList(),
      "webArchives":
          model.webArchives.map((key, value) => MapEntry(key, value.toMap())),
      "settings": model.settingsSnapshot.toMap()
    };
  }
}
