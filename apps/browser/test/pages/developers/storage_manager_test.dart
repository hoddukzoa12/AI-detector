// storage_manager.dart 회귀 그물 — 섹션 구성 자체.
//
// StorageManager 는 위젯 테스트로 렌더할 수 없다. didChangeDependencies 에서
// DeveloperStorageService.fromRuntime 을 부르고, 그 안에서
// CookieManager.instance() 가 InAppWebViewPlatform.instance 를 요구해
// 'A platform implementation for flutter_inappwebview has not been set' assertion
// 이 터진다. 서비스를 주입받게 바꾸면 렌더 테스트가 가능해지지만 그것은 lib/
// 변경이라 여기서 하지 않는다.
//
// 그래서 이 파일은 test/infocutter/webview_integration_test.dart 와 같은 방식으로
// 소스 텍스트에 계약을 건다. 섹션 목록과 플랫폼 분기는 이 화면의 핵심이고,
// 구조 리팩터에서 조용히 사라지거나 뒤집히기 쉬운 부분이다.
//
// 이 기대값을 고쳐도 되는 때: 섹션을 의도적으로 더하거나 빼거나, 플랫폼 분기를
// 의도적으로 바꾼 같은 커밋. 그 외에 빨간불이 켜지면 리팩터가 동작을 바꾼 것이다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source =
      File('lib/pages/developers/storage_manager.dart').readAsStringSync();
  // 줄바꿈·들여쓰기는 포매터가 언제든 바꾼다. 계약은 코드의 모양이 아니라
  // 분기 구조이므로 공백을 하나로 눌러서 비교한다.
  final flat = source.replaceAll(RegExp(r'\s+'), ' ');

  group('StorageManager 섹션 구성', () {
    test('항상 만들어지는 세 섹션이 이 순서로 유지된다', () {
      final cookies = source.indexOf('_buildCookiesExpansionTile(constraints)');
      final local =
          source.indexOf('_buildWebLocalStorageExpansionTile(constraints)');
      final session =
          source.indexOf('_buildWebSessionStorageExpansionTile(constraints)');

      expect(cookies, greaterThan(-1));
      expect(local, greaterThan(cookies));
      expect(session, greaterThan(local));
    });

    test('Http Auth 섹션은 Windows 가 아닐 때만 붙는다', () {
      expect(
        flat,
        contains('if (!Util.isWindows()) { entryItems '
            '.add(_buildHttpAuthCredentialDatabaseExpansionTile(constraints)); '
            '}'),
      );
    });

    test('플랫폼별 web storage 섹션 분기가 유지된다', () {
      expect(
        flat,
        contains('if (Util.isAndroid()) { '
            'entryItems.add(_buildAndroidWebStorageExpansionTile(constraints)); '
            '} else if (Util.isIOS() || Util.isMacOS()) { '
            'entryItems.add(_buildIOSWebStorageExpansionTile(constraints)); '
            '}'),
      );
    });

    test('섹션은 entryItems 개수만큼 ListView.builder 로 만들어진다', () {
      expect(source, contains('itemCount: entryItems.length'));
      expect(source, contains('return entryItems[index];'));
    });

    test('섹션 위젯은 전부 storage/ 하위로 추출된 위젯에 위임한다', () {
      for (final widgetName in const <String>[
        'CookieStorageSection',
        'AndroidWebStorageSection',
        'AppleWebStorageSection',
        'HttpAuthCredentialsSection',
        'AddWebStorageItemForm',
      ]) {
        expect(source, contains(widgetName), reason: '$widgetName 이 사라졌다');
      }
    });

    test('Local / Session Storage 표는 Key / Value / Delete 3열을 유지한다', () {
      // 두 표가 같은 _buildWebStorageContent 를 공유하므로 열 정의는 한 벌이다.
      // 열이 늘거나 줄면 여기가 깨진다.
      expect(
          flat,
          contains('columns: const <DataColumn>[ DataColumn( label: '
              'Text( "Key",'));
      expect(RegExp(r'DataColumn\(').allMatches(source).length, 3);
      expect(source, contains('"Value"'));
      expect(source, contains('"Delete"'));
      expect(source, contains('title: "Local Storage"'));
      expect(source, contains('title: "Session Storage"'));
    });
  });
}
