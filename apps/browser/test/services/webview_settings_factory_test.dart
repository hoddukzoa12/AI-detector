import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/services/webview_settings_factory.dart';

void main() {
  test('configureInitialTabSettings applies shared tab WebView settings', () {
    const factory = WebViewSettingsFactory();
    final baseSettings = InAppWebViewSettings();

    final settings = factory.configureInitialTabSettings(
      baseSettings: baseSettings,
      browserSettings: BrowserSettings(debuggingEnabled: true),
      webArchiveDirectory: '/tmp/infocutter',
    );

    expect(identical(settings, baseSettings), isTrue);
    expect(settings.isInspectable, isTrue);
    expect(settings.useOnDownloadStart, isTrue);
    expect(settings.useOnLoadResource, isTrue);
    expect(settings.useShouldOverrideUrlLoading, isTrue);
    expect(settings.javaScriptCanOpenWindowsAutomatically, isTrue);
    expect(settings.transparentBackground, isFalse);
    expect(settings.safeBrowsingEnabled, isTrue);
    expect(settings.disableDefaultErrorPage, isTrue);
    expect(settings.supportMultipleWindows, isTrue);
    expect(settings.allowsLinkPreview, isFalse);
    expect(settings.isFraudulentWebsiteWarningEnabled, isTrue);
    expect(settings.disableLongPressContextMenuOnLinks, isTrue);
    expect(settings.allowingReadAccessTo.toString(), 'file:///tmp/infocutter/');
  });
}
