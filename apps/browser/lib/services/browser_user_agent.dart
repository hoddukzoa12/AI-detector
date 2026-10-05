/// Infocutter Browser 가 웹에 자기를 밝히는 방식.
///
/// 이 앱은 인앱 브라우저가 아니라 정식 브라우저다. 그런데 fork 시점부터 물려받은
/// UA 는 `Version/4.0` (Android WebView 의 서명) 과 Chrome/83 (2020년 버전) 을 달고
/// 있어서, 스스로 "낡은 인앱 웹뷰" 라고 광고하고 있었다.
///
/// Firefox for iOS 가 `FxiOS` 토큰을, Edge 가 `EdgA` 토큰을 다는 것과 같은 방식으로
/// 플랫폼 표준 UA 에 **자기 토큰을 정직하게 덧붙인다.** 위장이 아니라 신원 표시다.
/// 사이트가 우리를 알아보고 문제를 신고할 수 있어야 하므로 토큰을 숨기지 않는다.
library;

/// UA 에 노출할 제품 토큰. pubspec 의 name 이 아니라 제품 표시 이름을 따른다.
const String browserUserAgentProduct = 'InfocutterBrowser';

/// 사이트가 기대하는 엔진 버전. 낡은 값을 두면 레거시 경로로 떨어지거나
/// "지원하지 않는 브라우저" 안내를 받는다. 릴리스마다 함께 올린다.
const String _chromeVersion = '131.0.6778.135';
const String _iosWebKitVersion = '605.1.15';
const String _iosSafariVersion = '18.0';

/// Android 용 UA. Chrome 모바일 형태에 제품 토큰을 덧붙인다.
/// `Version/4.0` 은 넣지 않는다 — 그것이 WebView 서명이다.
String androidUserAgent({
  required String appVersion,
  String androidVersion = '15',
  String deviceModel = 'K',
}) =>
    'Mozilla/5.0 (Linux; Android $androidVersion; $deviceModel) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    '$browserUserAgentProduct/$appVersion '
    'Chrome/$_chromeVersion Mobile Safari/537.36';

/// iOS 용 UA. iOS 브라우저는 전부 WKWebView 를 쓰므로 Safari 형태가 정상이며,
/// Firefox for iOS 와 같은 자리에 제품 토큰을 넣는다.
String iosUserAgent({required String appVersion}) =>
    'Mozilla/5.0 (iPhone; CPU iPhone OS ${_iosSafariVersion.replaceAll('.', '_')} '
    'like Mac OS X) AppleWebKit/$_iosWebKitVersion (KHTML, like Gecko) '
    '$browserUserAgentProduct/$appVersion '
    'Mobile/15E148 Safari/$_iosWebKitVersion';
