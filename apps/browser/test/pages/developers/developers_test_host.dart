// lib/pages/developers/ 회귀 그물의 공용 하네스.
//
// 이 구간의 위젯은 전부 WebViewModel(+ 일부는 WindowModel) provider 를 요구하고,
// 저장소 접근은 DeveloperStorageService 의 인터페이스(CookieStorage /
// BrowserWebStorage / HttpAuthCredentials)로만 이뤄진다. 그래서 플랫폼 채널 없이
// fake 를 주입해 렌더까지 갈 수 있다. 여기 fake 들은
// test/services/developer_storage_service_test.dart 의 fake 와 같은 모양이되,
// 개수 고정을 위해 데이터를 돌려주도록 만든 것이다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/services/developer_storage_service.dart';
import 'package:provider/provider.dart';

/// 개발자 도구 위젯 하나를 provider 와 함께 띄운다.
///
/// [wrapInBox] 는 스스로 ListView 를 만들지 않는 위젯(섹션 단품)용이다.
/// 스스로 ListView/Column 을 만드는 위젯(StorageManager, NetworkInfo,
/// JavaScriptConsole)은 여기서 또 감싸면 안 된다 — 높이가 무한이 되어 hasSize
/// assertion 이 터진다.
Widget developersHost(
  Widget child, {
  WebViewModel? webViewModel,
  bool wrapInBox = false,
}) {
  final model = webViewModel ?? buildWebViewModel();
  final windowModel = WindowModel()..addTab(model);

  final body = wrapInBox ? ListView(children: <Widget>[child]) : child;

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => BrowserModel()),
      ChangeNotifierProvider<WebViewModel>.value(value: model),
      ChangeNotifierProvider<WindowModel>.value(value: windowModel),
    ],
    child: MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: body),
    ),
  );
}

WebViewModel buildWebViewModel({
  List<LoadedResource>? loadedResources,
}) {
  return WebViewModel(
    url: WebUri('https://example.com/index.html'),
    loadedResources: loadedResources,
  )..tabIndex = 0;
}

/// ListView 는 보이는 항목만 만든다. 뷰포트를 세로로 크게 잡아 전 항목이 트리에
/// 올라오게 한다. settings_smoke_test.dart 와 같은 이유·같은 크기.
Future<void> pumpTall(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1200, 20000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump();
}

/// ExpansionTile 은 접힌 상태에서 children 을 만들지 않는다. 개수를 세려면
/// 먼저 펼쳐야 한다.
Future<void> expandAll(WidgetTester tester) async {
  final tiles = find.byType(ExpansionTile);
  for (var i = 0; i < tiles.evaluate().length; i++) {
    await tester.tap(find.byType(ExpansionTile).at(i));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

class FakeCookieStorage implements CookieStorage {
  FakeCookieStorage({List<Cookie>? cookies}) : cookies = cookies ?? <Cookie>[];

  final List<Cookie> cookies;
  final List<String> deletedNames = <String>[];
  final List<CookieSetRequest> setRequests = <CookieSetRequest>[];
  int deleteCookiesCalls = 0;
  int deleteAllCookiesCalls = 0;

  @override
  Future<void> deleteAllCookies() async {
    deleteAllCookiesCalls++;
  }

  @override
  Future<void> deleteCookie({
    required WebUri url,
    required String name,
  }) async {
    deletedNames.add(name);
  }

  @override
  Future<void> deleteCookies({required WebUri url}) async {
    deleteCookiesCalls++;
  }

  @override
  Future<Cookie?> getCookie({
    required WebUri url,
    required String name,
  }) async {
    for (final cookie in cookies) {
      if (cookie.name == name) return cookie;
    }
    return null;
  }

  @override
  Future<List<Cookie>> getCookies({required WebUri url}) async => cookies;

  @override
  Future<void> setCookie(CookieSetRequest request) async {
    setRequests.add(request);
  }
}

class FakeBrowserWebStorage implements BrowserWebStorage {
  FakeBrowserWebStorage({List<WebsiteDataRecord>? dataRecords})
      : dataRecords = dataRecords ?? <WebsiteDataRecord>[];

  final List<WebsiteDataRecord> dataRecords;
  final List<String> deletedOrigins = <String>[];
  int removeDataForCalls = 0;
  int removeDataModifiedSinceCalls = 0;

  @override
  Future<void> deleteOrigin({required String origin}) async {
    deletedOrigins.add(origin);
  }

  @override
  Future<List<WebsiteDataRecord>> fetchDataRecords({
    required Set<WebsiteDataType> dataTypes,
  }) async =>
      dataRecords;

  @override
  Future<int> getQuotaForOrigin({required String origin}) async => 1024;

  @override
  Future<int> getUsageForOrigin({required String origin}) async => 512;

  @override
  Future<void> removeDataFor({
    required Set<WebsiteDataType> dataTypes,
    required List<WebsiteDataRecord> dataRecords,
  }) async {
    removeDataForCalls++;
  }

  @override
  Future<void> removeDataModifiedSince({
    required Set<WebsiteDataType> dataTypes,
    required DateTime date,
  }) async {
    removeDataModifiedSinceCalls++;
  }
}

class FakeHttpAuthCredentials implements HttpAuthCredentials {
  FakeHttpAuthCredentials({
    List<URLProtectionSpaceHttpAuthCredentials>? credentials,
  }) : credentials = credentials ?? <URLProtectionSpaceHttpAuthCredentials>[];

  final List<URLProtectionSpaceHttpAuthCredentials> credentials;
  int clearAllCalls = 0;
  int removeCalls = 0;

  @override
  Future<void> clearAllAuthCredentials() async {
    clearAllCalls++;
  }

  @override
  Future<List<URLProtectionSpaceHttpAuthCredentials>>
      getAllAuthCredentials() async => credentials;

  @override
  Future<void> removeHttpAuthCredential({
    required URLProtectionSpace protectionSpace,
    required URLCredential credential,
  }) async {
    removeCalls++;
  }
}
