import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/services/browser_user_agent.dart';
import 'package:infocutter_app/util.dart';

class WebViewSettingsFactory {
  const WebViewSettingsFactory();

  /// UA 에 노출할 앱 버전. pubspec 의 version 과 함께 올린다.
  static const appVersion = '3.1';

  void configureWebContentsDebugging(BrowserSettings browserSettings) {
    if (Util.isAndroid()) {
      InAppWebViewController.setWebContentsDebuggingEnabled(
        browserSettings.debuggingEnabled,
      );
    }
  }

  InAppWebViewSettings configureInitialTabSettings({
    required InAppWebViewSettings baseSettings,
    required BrowserSettings browserSettings,
    required String webArchiveDirectory,
  }) {
    final settings = baseSettings;
    settings.isInspectable = browserSettings.debuggingEnabled;
    settings.useOnDownloadStart = true;
    settings.useOnLoadResource = true;
    settings.useShouldOverrideUrlLoading = true;
    settings.useShouldInterceptRequest = true;
    settings.javaScriptCanOpenWindowsAutomatically = true;
    // 콜드 스타트 때 투명 배경은 순백 빈 화면으로 보인다. 첫 페인트부터 불투명.
    settings.transparentBackground = false;
    settings.safeBrowsingEnabled = true;
    settings.disableDefaultErrorPage = true;
    settings.supportMultipleWindows = true;
    settings.verticalScrollbarThumbColor = const Color.fromRGBO(0, 0, 0, 0.5);
    settings.horizontalScrollbarThumbColor = const Color.fromRGBO(0, 0, 0, 0.5);
    settings.allowsLinkPreview = false;
    settings.isFraudulentWebsiteWarningEnabled = true;
    settings.disableLongPressContextMenuOnLinks = true;
    settings.allowingReadAccessTo = WebUri('file://$webArchiveDirectory/');

    // 정식 브라우저로서 자기 토큰을 붙인 UA 를 쓴다. 상세는 browser_user_agent.dart.
    if (Util.isAndroid()) {
      settings.userAgent = androidUserAgent(appVersion: appVersion);
    } else if (Util.isIOS()) {
      settings.userAgent = iosUserAgent(appVersion: appVersion);
    }

    return settings;
  }
}
