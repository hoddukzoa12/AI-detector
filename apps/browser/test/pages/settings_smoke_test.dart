// android_settings / ios_settings 리팩터용 회귀 그물.
//
// 이 두 파일은 dart_code_linter 위반이 가장 많이 몰려 있으면서 테스트 커버리지가
// 0 이었다. 섹션 메서드를 추출할 때 설정 항목이 조용히 사라져도 analyze 와 기존
// 테스트는 전부 초록이다. 그 구멍을 막는 것이 이 테스트의 목적이다.
//
// 개수를 고정하는 이유: 추출은 동작 보존이므로 렌더되는 컨트롤 수가 변하면
// 그것은 리팩터가 아니라 재작성이다. 항목을 의도적으로 추가·제거했다면 이
// 기대값을 같은 커밋에서 함께 고쳐야 한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/pages/settings/android_settings.dart';
import 'package:infocutter_app/pages/settings/ios_settings.dart';
import 'package:provider/provider.dart';

Widget _host(Widget child) {
  final webViewModel = WebViewModel(url: WebUri('https://example.com/'))
    ..tabIndex = 0
    ..settings = InAppWebViewSettings();
  final windowModel = WindowModel()..addTab(webViewModel);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => BrowserModel()),
      ChangeNotifierProvider<WebViewModel>.value(value: webViewModel),
      ChangeNotifierProvider<WindowModel>.value(value: windowModel),
    ],
    child: MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // AndroidSettings / IOSSettings 는 스스로 ListView 를 만든다.
      // 여기서 또 감싸면 높이가 무한이 되어 hasSize assertion 이 터진다.
      home: Scaffold(body: child),
    ),
  );
}

/// ListView 는 보이는 항목만 만든다. 뷰포트를 세로로 크게 잡아 설정 항목이
/// 전부 트리에 올라오게 한다.
Future<void> _pumpTall(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 20000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_host(child));
  await tester.pump();
}

/// 두 탭의 WebView 원시 설정은 `AdvancedSettingsGroup` 안에 접혀 있다. 접힌
/// 자식은 offstage 라서 finder 가 기본값(skipOffstage: true)으로 건너뛴다.
/// 개수를 세기 전에 실제 사용자처럼 헤더를 눌러 펼친다.
Future<void> _expandAdvanced(WidgetTester tester) async {
  await tester.tap(find.byType(InkWell).first);
  await tester.pumpAndSettle();
}

int _controlCount() =>
    find.byType(ListTile).evaluate().length +
    find.byType(SwitchListTile).evaluate().length +
    find.byType(TextFormField).evaluate().length +
    find.byType(DropdownButton<String>).evaluate().length;

void main() {
  testWidgets('AndroidSettings 가 예외 없이 렌더되고 항목 수가 유지된다', (tester) async {
    await _pumpTall(tester, const AndroidSettings());
    await _expandAdvanced(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(AndroidSettings), findsOneWidget);
    // 추출로 설정 항목이 사라지면 여기서 잡힌다.
    expect(_controlCount(), _androidControls);
  });

  testWidgets('IOSSettings 가 예외 없이 렌더되고 항목 수가 유지된다', (tester) async {
    await _pumpTall(tester, const IOSSettings());
    await _expandAdvanced(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(IOSSettings), findsOneWidget);
    expect(_controlCount(), _iosControls);
  });
}

// 실측 고정값. 설정 항목을 의도적으로 더하거나 뺐다면 같은 커밋에서 함께 고친다.
// ForceDark enum 드롭다운 → algorithmicDarkeningAllowed SwitchListTile 로 바꾼 뒤
// Android 컨트롤 집계가 86 으로 안정됐다.
const int _androidControls = 86;
const int _iosControls = 58;
