import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/auth_origin_policy.dart';

void main() {
  group('isAuthOrigin — 인증 origin 으로 인정', () {
    test('알려진 인증 호스트', () {
      expect(isAuthOrigin(Uri.parse('https://accounts.google.com/')), isTrue);
      expect(
        isAuthOrigin(
            Uri.parse('https://accounts.google.com/signin/v2/identifier'
                '?flowName=GlifWebSignIn')),
        isTrue,
      );
      expect(
        isAuthOrigin(
            Uri.parse('https://login.microsoftonline.com/common/oauth2')),
        isTrue,
      );
      expect(
          isAuthOrigin(Uri.parse('https://appleid.apple.com/auth/authorize')),
          isTrue);
    });

    test('서브도메인도 인증 origin', () {
      expect(
        isAuthOrigin(Uri.parse('https://x.accounts.google.com/')),
        isTrue,
      );
      expect(
        isAuthOrigin(Uri.parse('https://a.b.login.microsoftonline.com/x')),
        isTrue,
      );
    });

    test('대소문자·루트 점·포트는 판정에 영향이 없다', () {
      expect(isAuthOrigin(Uri.parse('https://ACCOUNTS.Google.COM/')), isTrue);
      expect(isAuthOrigin(Uri.parse('https://accounts.google.com./')), isTrue);
      expect(
          isAuthOrigin(Uri.parse('https://accounts.google.com:443/')), isTrue);
      expect(
          isAuthOrigin(Uri.parse('http://accounts.google.com:8080/')), isTrue);
    });

    test('경로 한정 호스트는 인증 경로에서만', () {
      expect(isAuthOrigin(Uri.parse('https://github.com/login')), isTrue);
      expect(isAuthOrigin(Uri.parse('https://github.com/login/')), isTrue);
      expect(
        isAuthOrigin(Uri.parse('https://github.com/login/oauth/authorize'
            '?client_id=abc')),
        isTrue,
      );
      expect(isAuthOrigin(Uri.parse('https://github.com/login?return_to=%2F')),
          isTrue);
      expect(
          isAuthOrigin(Uri.parse('https://gitlab.com/users/sign_in')), isTrue);
      expect(
        isAuthOrigin(Uri.parse('https://gitlab.com/users/sign_in/two_factor')),
        isTrue,
      );
    });
  });

  group('isAuthOrigin — 인증 origin 이 아님', () {
    test('null 과 비 http(s) 스킴', () {
      expect(isAuthOrigin(null), isFalse);
      expect(isAuthOrigin(Uri.parse('about:blank')), isFalse);
      expect(isAuthOrigin(Uri.parse('data:text/html,hi')), isFalse);
      expect(isAuthOrigin(Uri.parse('file:///accounts.google.com')), isFalse);
      expect(
        isAuthOrigin(Uri.parse('javascript:alert(1)')),
        isFalse,
      );
    });

    test('접미사만 같은 유사 도메인은 인증 origin 이 아니다', () {
      expect(
        isAuthOrigin(Uri.parse('https://accounts.google.com.evil.com/')),
        isFalse,
      );
      expect(
        isAuthOrigin(Uri.parse('https://evilaccounts.google.com/')),
        isFalse,
      );
      expect(
        isAuthOrigin(Uri.parse('https://xappleid.apple.com/')),
        isFalse,
      );
      expect(
        isAuthOrigin(Uri.parse('https://evil.com/accounts.google.com')),
        isFalse,
      );
      expect(
        isAuthOrigin(Uri.parse('https://evil.com/?next=accounts.google.com')),
        isFalse,
      );
    });

    test('같은 등록 도메인의 다른 호스트는 대상이 아니다', () {
      expect(isAuthOrigin(Uri.parse('https://www.google.com/search')), isFalse);
      expect(isAuthOrigin(Uri.parse('https://google.com/')), isFalse);
      expect(isAuthOrigin(Uri.parse('https://apple.com/')), isFalse);
      expect(
        isAuthOrigin(Uri.parse('https://microsoftonline.com/')),
        isFalse,
      );
    });

    test('경로 한정 호스트의 비인증 경로', () {
      expect(isAuthOrigin(Uri.parse('https://github.com/')), isFalse);
      expect(isAuthOrigin(Uri.parse('https://github.com/loginfoo')), isFalse);
      expect(
        isAuthOrigin(Uri.parse('https://github.com/anthropics/claude-code')),
        isFalse,
      );
      expect(isAuthOrigin(Uri.parse('https://gitlab.com/users')), isFalse);
      expect(
        isAuthOrigin(Uri.parse('https://gitlab.com/users/sign_in_now')),
        isFalse,
      );
      // 경로 규칙은 호스트에 묶인다 — 다른 호스트의 같은 경로는 아니다.
      expect(isAuthOrigin(Uri.parse('https://example.com/login')), isFalse);
      expect(
        isAuthOrigin(Uri.parse('https://example.com/users/sign_in')),
        isFalse,
      );
    });

    test('호스트가 없는 URL', () {
      expect(isAuthOrigin(Uri.parse('https:///login')), isFalse);
      expect(isAuthOrigin(Uri.parse('/login')), isFalse);
    });
  });
}
