// javascript_console.dart 회귀 그물.
//
// 콘솔은 로그 목록 + 입력바(입력 필드 · 실행 · 히스토리 위/아래 · 지우기)로
// 이뤄진다. 구조를 쪼갤 때 컨트롤 하나가 조용히 빠져도 analyze 는 초록이므로,
// 로그 개수와 입력바 컨트롤 수를 고정한다.
//
// evaluateJavaScript 는 webViewController 를 요구하므로(테스트에서는 null) 여기서
// 실행 경로는 다루지 않는다. 히스토리 버튼과 지우기는 컨트롤러 없이도 동작한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/javascript_console_result.dart';
import 'package:infocutter_app/models/javascript_console_log.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/pages/developers/javascript_console.dart';

import 'developers_test_host.dart';

WebViewModel _consoleModel({
  List<JavaScriptConsoleLog>? logs,
  List<String>? history,
}) {
  return WebViewModel(
    url: WebUri('https://example.com/index.html'),
    javaScriptConsoleLogs: logs,
    javaScriptConsoleHistory: history,
  )..tabIndex = 0;
}

void main() {
  testWidgets('로그가 없어도 입력바 컨트롤 수가 유지된다', (tester) async {
    await pumpTall(
      tester,
      developersHost(const JavaScriptConsole(), webViewModel: _consoleModel()),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(JavaScriptConsoleResult), findsNothing);
    // 실행 / 히스토리 위 / 히스토리 아래 / 지우기 4 버튼 고정.
    expect(find.byType(IconButton), findsNWidgets(_inputBarButtons));
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('로그 개수만큼 결과 위젯이 만들어진다', (tester) async {
    await pumpTall(
      tester,
      developersHost(
        const JavaScriptConsole(),
        webViewModel: _consoleModel(logs: [
          JavaScriptConsoleLog(message: 'hello'),
          JavaScriptConsoleLog(message: 'world'),
        ]),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(JavaScriptConsoleResult), findsNWidgets(2));
    expect(find.byType(IconButton), findsNWidgets(_inputBarButtons));
  });

  testWidgets('히스토리 위 버튼이 직전 명령을 입력 필드에 채운다', (tester) async {
    await pumpTall(
      tester,
      developersHost(
        const JavaScriptConsole(),
        webViewModel: _consoleModel(history: ['first()', 'second()']),
      ),
    );

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await tester.pump();

    // 커서는 히스토리 끝(길이 2)에서 시작해 한 칸 올라가 index 1 을 집는다.
    expect(find.text('second()'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await tester.pump();
    expect(find.text('first()'), findsOneWidget);

    // 아래로 되돌리면 다시 최신 명령.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();
    expect(find.text('second()'), findsOneWidget);
  });

  testWidgets('히스토리 아래 버튼이 끝에 닿으면 입력 필드를 비운다', (tester) async {
    await pumpTall(
      tester,
      developersHost(
        const JavaScriptConsole(),
        webViewModel: _consoleModel(history: ['only()']),
      ),
    );

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await tester.pump();
    expect(find.text('only()'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();
    expect(find.text('only()'), findsNothing);
  });

  testWidgets('지우기 버튼이 로그를 비운다', (tester) async {
    final model = _consoleModel(logs: [
      JavaScriptConsoleLog(message: 'hello'),
    ]);

    await pumpTall(
      tester,
      developersHost(const JavaScriptConsole(), webViewModel: model),
    );
    expect(find.byType(JavaScriptConsoleResult), findsOneWidget);

    await tester.tap(find.byIcon(Icons.cancel));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(model.javaScriptConsoleLogs, isEmpty);
    expect(find.byType(JavaScriptConsoleResult), findsNothing);
  });
}

// 실측 고정값. 입력바 버튼을 의도적으로 더하거나 뺐다면 같은 커밋에서 함께 고친다.
const int _inputBarButtons = 4; // 실행, 히스토리 위, 히스토리 아래, 지우기
