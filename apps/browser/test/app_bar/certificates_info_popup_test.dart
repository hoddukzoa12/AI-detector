// certificates_info_popup 리팩터용 회귀 그물 (부분).
//
// 이 파일은 app_bar 구간 최대 파일(997줄)이지만 위젯 테스트로 닿을 수 있는
// 범위가 매우 좁다. 렌더 내용 전부가 webViewModel.webViewController.getCertificate()
// 가 돌려주는 실제 SslCertificate 에 달려 있고, InAppWebViewController 는
// 테스트에서 만들 수 없다 (InAppWebViewPlatform.instance 필요). 주입 지점도 없다.
//
// 그래서 여기서 고정하는 것은 컨트롤러가 없을 때의 경로 하나뿐이다:
// "인증서를 가져올 수 없으면 아무것도 그리지 않고, 예외도 내지 않는다."
// 인증서 본문(ISSUED TO / EXTENSIONS 등) 렌더는 이 그물이 덮지 못한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/app_bar/certificates_info_popup.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:provider/provider.dart';

Widget _host(WebViewModel webViewModel) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WebViewModel>.value(value: webViewModel),
    ],
    child: MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: CertificateInfoPopup()),
    ),
  );
}

void main() {
  testWidgets('webViewController 가 없으면 예외 없이 빈 화면을 그린다', (tester) async {
    final webViewModel = WebViewModel(url: WebUri('https://example.com/'))
      ..tabIndex = 0;

    await tester.pumpWidget(_host(webViewModel));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CertificateInfoPopup), findsOneWidget);
    // 인증서를 못 가져온 상태에서는 다이얼로그도 로딩 인디케이터도 없다.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // 인증서 본문이 그려졌다면 나올 섹션 헤더. 지금 경로에서는 없어야 한다.
    expect(find.text('ISSUED TO'), findsNothing);
  });

  testWidgets('url 이 바뀌어도 컨트롤러가 없으면 빈 화면을 유지한다', (tester) async {
    final webViewModel = WebViewModel(url: WebUri('https://example.com/'))
      ..tabIndex = 0;

    await tester.pumpWidget(_host(webViewModel));
    await tester.pump();

    webViewModel.url = WebUri('https://other.test/');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
