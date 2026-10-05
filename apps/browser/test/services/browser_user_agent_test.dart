// UA 는 조용히 썩는다. 사이트가 우리를 인앱 웹뷰로 보거나 레거시 경로로 떨어뜨려도
// 앱은 멀쩡히 뜨고 테스트도 초록이다. 그래서 형태를 못으로 박는다.

import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/services/browser_user_agent.dart';

void main() {
  group('Android UA', () {
    final ua = androidUserAgent(appVersion: '3.1');

    test('WebView 서명 Version/4.0 이 없다', () {
      // 이 토큰 하나로 "인앱 웹뷰" 로 분류된다. 되돌아오면 안 된다.
      expect(ua.contains('Version/4.0'), isFalse, reason: ua);
    });

    test('제품 토큰을 정직하게 밝힌다', () {
      expect(ua, contains('$browserUserAgentProduct/3.1'));
    });

    test('Chrome 모바일 형태를 유지한다', () {
      expect(ua, startsWith('Mozilla/5.0 (Linux; Android '));
      expect(ua, contains('AppleWebKit/537.36 (KHTML, like Gecko)'));
      expect(ua, endsWith('Mobile Safari/537.36'));
    });

    test('Chrome 버전이 낡지 않았다', () {
      final match = RegExp(r'Chrome/(\d+)\.').firstMatch(ua);
      expect(match, isNotNull, reason: 'Chrome 버전 토큰이 없다: $ua');
      // 낡은 메이저 버전은 사이트가 레거시로 취급한다. 올릴 때 이 하한도 함께 올린다.
      expect(int.parse(match!.group(1)!), greaterThanOrEqualTo(120));
    });
  });

  group('iOS UA', () {
    final ua = iosUserAgent(appVersion: '3.1');

    test('Safari 형태에 제품 토큰을 얹는다', () {
      // iOS 브라우저는 전부 WKWebView 이므로 Safari 형태가 정상이다.
      // Firefox for iOS 가 FxiOS 를 넣는 자리와 같다.
      expect(ua, startsWith('Mozilla/5.0 (iPhone; CPU iPhone OS '));
      expect(ua, contains('$browserUserAgentProduct/3.1'));
      expect(ua, endsWith('Safari/605.1.15'));
    });

    test('iOS 버전 표기는 밑줄이다', () {
      // "18.0" 이 아니라 "18_0" — 점을 남기면 UA 파서가 깨진다.
      expect(ua, contains('iPhone OS 18_0 like Mac OS X'));
      expect(ua.contains('OS 18.0 like'), isFalse);
    });
  });

  test('두 UA 모두 앱 버전을 반영한다', () {
    expect(androidUserAgent(appVersion: '9.9'), contains('/9.9 '));
    expect(iosUserAgent(appVersion: '9.9'), contains('/9.9 '));
  });
}
