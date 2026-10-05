import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/models/javascript_console_log.dart';
import 'package:infocutter_app/models/webview_model.dart';

void main() {
  group('WebViewModel console logs', () {
    test('stores JavaScript console output as data', () {
      final model = WebViewModel(url: WebUri('https://example.com'));

      model.addJavaScriptConsoleLog(const JavaScriptConsoleLog(
        message: 'warned',
        level: JavaScriptConsoleLogLevel.warning,
      ));

      expect(model.javaScriptConsoleLogs, hasLength(1));
      expect(model.javaScriptConsoleLogs.single.message, 'warned');
      expect(
        model.javaScriptConsoleLogs.single.level,
        JavaScriptConsoleLogLevel.warning,
      );
    });

    test('copies console log data when updating from another model', () {
      final source = WebViewModel(url: WebUri('https://example.com'))
        ..addJavaScriptConsoleLog(const JavaScriptConsoleLog(
          message: 'copied',
          level: JavaScriptConsoleLogLevel.error,
        ));
      final target = WebViewModel();

      target.updateWithValue(source);
      source.setJavaScriptConsoleLogs([]);

      expect(target.javaScriptConsoleLogs, hasLength(1));
      expect(target.javaScriptConsoleLogs.single.message, 'copied');
      expect(
        target.javaScriptConsoleLogs.single.level,
        JavaScriptConsoleLogLevel.error,
      );
    });
  });
}
