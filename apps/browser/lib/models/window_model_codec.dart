import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/services/browser_persistence.dart';

class WindowModelCodec {
  const WindowModelCodec._();

  static WindowModel fromMap(
    Map<String, dynamic> map, {
    WindowPersistence? persistence,
  }) {
    final window = WindowModel(
      id: map["id"],
      name: map["name"],
      shouldSave: map["shouldSave"],
      updatedTime: _dateFromMap(map["updatedTime"]),
      createdTime: _dateFromMap(map["createdTime"]),
      persistence: persistence,
    );
    window.addTabs(webViewModelsFromMap(map));
    return window;
  }

  static List<WebViewModel> webViewModelsFromMap(Map<String, dynamic> map) {
    final rawWebViewTabs = map["webViewTabs"];
    final List<Map<String, dynamic>> webViewTabList = rawWebViewTabs is List
        ? rawWebViewTabs.cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];
    final List<WebViewModel> webViewModels =
        webViewTabList.map((e) => WebViewModel.fromMap(e)!).toList();
    webViewModels.sort((a, b) => a.tabIndex!.compareTo(b.tabIndex!));
    return webViewModels;
  }

  static int currentTabIndexFromMap(
    Map<String, dynamic> map, {
    required int fallback,
    required int maxIndex,
  }) {
    final int currentTabIndex = map["currentTabIndex"] ?? fallback;
    return currentTabIndex > maxIndex ? maxIndex : currentTabIndex;
  }

  static Map<String, dynamic> toMap(WindowModel model) {
    return {
      "id": model.id,
      "name": model.name,
      "webViewTabs": model.webViewModels.map((e) => e.toMap()).toList(),
      "currentTabIndex": model.getCurrentTabIndex(),
      "currentWebViewModel": model.currentWebViewModelSnapshot.toMap(),
      "shouldSave": model.shouldSave,
      "updatedTime": model.updatedTime.toIso8601String(),
      "createdTime": model.createdTime.toIso8601String()
    };
  }

  static DateTime? _dateFromMap(dynamic value) {
    return value != null ? DateTime.tryParse(value) : null;
  }
}
