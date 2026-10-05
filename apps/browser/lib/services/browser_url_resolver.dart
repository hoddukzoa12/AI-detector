import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/util.dart';

class BrowserUrlResolver {
  const BrowserUrlResolver();

  WebUri resolve(String value, BrowserSettings settings) {
    final input = value.trim();
    var url = WebUri(input);

    if (Util.isLocalizedContent(url) ||
        (url.isValidUri && url.toString().split(".").length > 1)) {
      return url.scheme.isEmpty ? WebUri("https://$url") : url;
    }

    return WebUri(settings.searchEngine.searchUrl + input);
  }
}
