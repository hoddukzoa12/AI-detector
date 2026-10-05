import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'application/runtime/infocutter_runtime_page.dart';

class InAppWebViewRuntimePage implements InfocutterRuntimePage {
  const InAppWebViewRuntimePage(this._controller);

  final InAppWebViewController _controller;

  @override
  Future<Object?> evaluateJavascript(String source) {
    return _controller.evaluateJavascript(source: source);
  }
}
