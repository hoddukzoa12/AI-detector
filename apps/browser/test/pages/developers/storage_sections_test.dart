// storage_manager 구조 리팩터용 회귀 그물 — 이미 추출된 섹션 위젯들.
//
// storage_manager.dart 는 425 줄이고 뒤이어 더 쪼개진다. 섹션 위젯이 옮겨지거나
// 다시 나뉘는 과정에서 행·컨트롤이 조용히 사라져도 analyze 는 초록이다. 그 구멍을
// 막는 것이 이 파일의 목적이다.
//
// 개수를 고정하는 이유: 추출은 동작 보존이므로 렌더되는 행·컨트롤 수가 변하면
// 그것은 리팩터가 아니라 재작성이다. 항목을 의도적으로 더하거나 뺐다면 이 기대값을
// 같은 커밋에서 함께 고쳐야 한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/pages/developers/storage/cookie_storage_section.dart';
import 'package:infocutter_app/pages/developers/storage/platform_storage_sections.dart';

import 'developers_test_host.dart';

// StorageManager 는 LayoutBuilder 안의 ListView 로 섹션을 만든다. ListView 는
// 가로를 tight 하게 주므로 실제 constraints 는 minWidth == maxWidth 다.
// minWidth 를 0 으로 두면 표 폭이 0 이 되어 DataTable 이 overflow 한다.
const _constraints = BoxConstraints(maxWidth: 1200.0, minWidth: 1200.0);

void main() {
  group('CookieStorageSection', () {
    testWidgets('쿠키 개수만큼 행을 만들고 폼 컨트롤 수가 유지된다', (tester) async {
      final cookies = FakeCookieStorage(cookies: <Cookie>[
        Cookie(name: 'session', value: 'abc'),
        Cookie(name: 'theme', value: 'dark'),
      ]);

      await pumpTall(
        tester,
        developersHost(
          CookieStorageSection(constraints: _constraints, cookies: cookies),
          wrapInBox: true,
        ),
      );
      await expandAll(tester);

      expect(tester.takeException(), isNull);
      // 쿠키 2개 → DataRow 2개. 헤더 행은 DataTable 의 columns 라 여기 안 센다.
      expect(find.byType(DataRow), findsNothing); // DataRow 는 위젯이 아니다
      expect(_dataTableRowCount(tester), 2);
      // 새 쿠키 폼: Name / Value / Domain / Path 4 필드 고정.
      expect(find.byType(TextFormField), findsNWidgets(_cookieFormFields));
      // Clear cookies / Clear all / Add Cookie 3 버튼 고정.
      expect(find.byType(TextButton), findsNWidgets(_cookieButtons));
      expect(find.byType(CheckboxListTile), findsOneWidget);
    });

    testWidgets('쿠키가 비어도 예외 없이 렌더되고 행이 0이다', (tester) async {
      await pumpTall(
        tester,
        developersHost(
          CookieStorageSection(
            constraints: _constraints,
            cookies: FakeCookieStorage(),
          ),
          wrapInBox: true,
        ),
      );
      await expandAll(tester);

      expect(tester.takeException(), isNull);
      expect(_dataTableRowCount(tester), 0);
      expect(find.byType(TextFormField), findsNWidgets(_cookieFormFields));
    });

    testWidgets('Clear cookies / Clear all 이 각각의 저장소 호출로 이어진다', (tester) async {
      final cookies = FakeCookieStorage();

      await pumpTall(
        tester,
        developersHost(
          CookieStorageSection(constraints: _constraints, cookies: cookies),
          wrapInBox: true,
        ),
      );
      await expandAll(tester);

      await tester.tap(find.text('Clear cookies'));
      await tester.pump();
      await tester.tap(find.text('Clear all'));
      await tester.pump();

      expect(cookies.deleteCookiesCalls, 1);
      expect(cookies.deleteAllCookiesCalls, 1);
    });
  });

  group('AndroidWebStorageSection', () {
    testWidgets('Quota / Usage 두 타일이 유지된다', (tester) async {
      await pumpTall(
        tester,
        developersHost(
          AndroidWebStorageSection(
            webStorage: FakeBrowserWebStorage(),
            onRefresh: () {},
          ),
          wrapInBox: true,
        ),
      );
      await expandAll(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Quota'), findsOneWidget);
      expect(find.text('Usage'), findsOneWidget);
      // Quota / Usage 2 타일 + ExpansionTile 이 헤더로 만드는 ListTile 1 = 3.
      expect(find.byType(ListTile), findsNWidgets(3));
      // fake 가 돌려주는 값이 그대로 표시된다.
      expect(find.text('1024'), findsOneWidget);
      expect(find.text('512'), findsOneWidget);
    });

    testWidgets('Usage 의 clear 가 deleteOrigin 을 부른다', (tester) async {
      final webStorage = FakeBrowserWebStorage();

      await pumpTall(
        tester,
        developersHost(
          AndroidWebStorageSection(
            webStorage: webStorage,
            onRefresh: () {},
          ),
          wrapInBox: true,
        ),
      );
      await expandAll(tester);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(webStorage.deletedOrigins, hasLength(1));
    });
  });

  group('AppleWebStorageSection', () {
    testWidgets('데이터 레코드 개수만큼 행을 만든다', (tester) async {
      final webStorage = FakeBrowserWebStorage(dataRecords: <WebsiteDataRecord>[
        WebsiteDataRecord(
          displayName: 'example.com',
          dataTypes: {WebsiteDataType.WKWebsiteDataTypeCookies},
        ),
        WebsiteDataRecord(
          displayName: 'other.com',
          dataTypes: {WebsiteDataType.WKWebsiteDataTypeLocalStorage},
        ),
      ]);

      await pumpTall(
        tester,
        developersHost(
          AppleWebStorageSection(
            constraints: _constraints,
            webStorage: webStorage,
            onRefresh: () {},
          ),
          wrapInBox: true,
        ),
      );
      await expandAll(tester);

      expect(tester.takeException(), isNull);
      expect(_dataTableRowCount(tester), 2);
      expect(find.text('example.com'), findsOneWidget);
      // Clear all 버튼 1개 고정.
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('Clear all 이 removeDataModifiedSince 를 부른다', (tester) async {
      final webStorage = FakeBrowserWebStorage();

      await pumpTall(
        tester,
        developersHost(
          AppleWebStorageSection(
            constraints: _constraints,
            webStorage: webStorage,
            onRefresh: () {},
          ),
          wrapInBox: true,
        ),
      );
      await expandAll(tester);

      await tester.tap(find.text('Clear all'));
      await tester.pump();

      expect(webStorage.removeDataModifiedSinceCalls, 1);
    });
  });

  group('HttpAuthCredentialsSection', () {
    testWidgets('protection space 별 표와 자격증명 행이 유지된다', (tester) async {
      final credentials = FakeHttpAuthCredentials(
        credentials: <URLProtectionSpaceHttpAuthCredentials>[
          URLProtectionSpaceHttpAuthCredentials(
            protectionSpace: URLProtectionSpace(
              host: 'example.com',
              protocol: 'https',
              realm: 'realm',
              port: 443,
            ),
            credentials: <URLCredential>[
              URLCredential(username: 'alice', password: 'pw1'),
              URLCredential(username: 'bob', password: 'pw2'),
            ],
          ),
        ],
      );

      await pumpTall(
        tester,
        developersHost(
          HttpAuthCredentialsSection(
            constraints: _constraints,
            httpAuthCredentials: credentials,
            onRefresh: () {},
          ),
          wrapInBox: true,
        ),
      );
      await expandAll(tester);

      expect(tester.takeException(), isNull);
      // protection space 1개 → DataTable 1개, 자격증명 2개 → 행 2개.
      expect(find.byType(DataTable), findsOneWidget);
      expect(_dataTableRowCount(tester), 2);
      expect(find.text('alice'), findsOneWidget);
      expect(
        find.text('Protocol: https, Host: example.com, Port: 443, '
            'Realm: realm'),
        findsOneWidget,
      );
    });

    testWidgets('Clear all 이 clearAllAuthCredentials 를 부른다', (tester) async {
      final credentials = FakeHttpAuthCredentials();

      await pumpTall(
        tester,
        developersHost(
          HttpAuthCredentialsSection(
            constraints: _constraints,
            httpAuthCredentials: credentials,
            onRefresh: () {},
          ),
          wrapInBox: true,
        ),
      );
      await expandAll(tester);

      await tester.tap(find.text('Clear all'));
      await tester.pump();

      expect(credentials.clearAllCalls, 1);
    });
  });
}

/// DataTable 은 위젯이지만 DataRow 는 아니다. 실제로 만들어진 행 수는
/// DataTable 의 rows 를 세어야 한다.
int _dataTableRowCount(WidgetTester tester) {
  return tester
      .widgetList<DataTable>(find.byType(DataTable))
      .fold<int>(0, (sum, table) => sum + table.rows.length);
}

// 실측 고정값. 폼 필드·버튼을 의도적으로 더하거나 뺐다면 같은 커밋에서 함께 고친다.
const int _cookieFormFields = 4; // Name, Value, Domain, Path
const int _cookieButtons = 3; // Clear cookies, Clear all, Add Cookie
