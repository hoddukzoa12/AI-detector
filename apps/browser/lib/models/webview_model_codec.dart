import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/models/webview_model.dart';

class WebViewModelCodec {
  const WebViewModelCodec._();

  static WebViewModel? fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return null;
    }

    return WebViewModel(
      tabIndex: map["tabIndex"],
      url: map["url"] != null ? WebUri(map["url"]) : null,
      title: map["title"],
      favicon: _faviconFromMap(map["favicon"]),
      progress: map["progress"],
      isDesktopMode: map["isDesktopMode"],
      isIncognitoMode: map["isIncognitoMode"],
      javaScriptConsoleHistory: map["javaScriptConsoleHistory"]?.cast<String>(),
      isSecure: map["isSecure"],
      settings: InAppWebViewSettings.fromMap(map["settings"]),
      createdTime: _dateFromMap(map["createdTime"]),
      lastOpenedTime: _dateFromMap(map["lastOpenedTime"]),
    );
  }

  static Map<String, dynamic> toMap(WebViewModel model) {
    return {
      "tabIndex": model.tabIndex,
      "url": model.url?.toString(),
      "title": model.title,
      "favicon": model.favicon?.toMap(),
      "progress": model.progress,
      "isDesktopMode": model.isDesktopMode,
      "isIncognitoMode": model.isIncognitoMode,
      "javaScriptConsoleHistory": model.javaScriptConsoleHistory,
      "isSecure": model.isSecure,
      "settings": model.settings?.toMap(),
      "screenshot": model.screenshot,
      "createdTime": model.createdTime.toIso8601String(),
      "lastOpenedTime": model.lastOpenedTime.toIso8601String(),
    };
  }

  static Favicon? _faviconFromMap(dynamic map) {
    if (map == null) {
      return null;
    }

    return Favicon(
      url: WebUri(map["url"]),
      rel: map["rel"],
      width: map["width"],
      height: map["height"],
    );
  }

  static DateTime? _dateFromMap(dynamic value) {
    return value != null ? DateTime.tryParse(value) : null;
  }
}
