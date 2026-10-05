// network_info.dart 회귀 그물.
//
// 이 화면은 LoadedResource 를 행으로 펼치면서 이름·도메인·타입·시간 파생값을
// _NetworkResourceRow 안에서 계산한다. 그 파생 로직은 private 이라 직접 부를 수
// 없으므로 렌더 결과의 텍스트로 고정한다. 행 개수와 표시 문자열이 유지되는지가
// 이 파일의 관심사다.
//
// 아이콘 자산을 네트워크에서 가져오는 경로(CustomImage / SvgPicture.network)는
// 위젯 테스트에서 실제 요청이 나가므로 image/svg 리소스는 넣지 않는다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/pages/developers/network_info.dart';

import 'developers_test_host.dart';

LoadedResource _resource({
  required String url,
  String? initiatorType,
  double? duration,
}) {
  return LoadedResource(
    url: WebUri(url),
    initiatorType: initiatorType,
    startTime: 0.0,
    duration: duration,
  );
}

void main() {
  testWidgets('로드된 리소스가 없어도 헤더 행만으로 예외 없이 렌더된다', (tester) async {
    await pumpTall(
      tester,
      developersHost(const NetworkInfo(), webViewModel: buildWebViewModel()),
    );

    expect(tester.takeException(), isNull);
    // 헤더 셀 4개는 리소스가 없어도 항상 있다.
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Domain'), findsOneWidget);
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    // 헤더 Row 1개뿐 — 리소스 행이 없다.
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('리소스 개수만큼 행을 만들고 파생 텍스트가 유지된다', (tester) async {
    await pumpTall(
      tester,
      developersHost(
        const NetworkInfo(),
        webViewModel: buildWebViewModel(loadedResources: [
          _resource(
            url: 'https://www.example.com/assets/app.js',
            initiatorType: 'script',
            duration: 12.345,
          ),
          _resource(
            url: 'https://cdn.other.com/style.css',
            initiatorType: 'css',
            duration: 3.0,
          ),
        ]),
      ),
    );

    expect(tester.takeException(), isNull);
    // 리소스 2개 → 이름 셀(InkWell) 2개. 헤더는 InkWell 이 아니다.
    expect(find.byType(InkWell), findsNWidgets(2));

    // 이름은 경로의 마지막 세그먼트.
    expect(find.text('app.js'), findsOneWidget);
    expect(find.text('style.css'), findsOneWidget);
    // 도메인은 host 에서 앞의 "www." 만 제거한다.
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('cdn.other.com'), findsOneWidget);
    // 시간은 소수 둘째 자리 + " ms".
    expect(find.text('12.35 ms'), findsOneWidget);
    expect(find.text('3.00 ms'), findsOneWidget);
    // initiatorType 별 아이콘 매핑.
    expect(find.byIcon(Icons.format_align_left), findsOneWidget); // script
    expect(find.byIcon(Icons.color_lens), findsOneWidget); // css
  });

  testWidgets('duration·initiatorType 이 없으면 빈 문자열과 기본 아이콘으로 떨어진다',
      (tester) async {
    await pumpTall(
      tester,
      developersHost(
        const NetworkInfo(),
        webViewModel: buildWebViewModel(loadedResources: [
          _resource(url: 'https://example.com/data'),
        ]),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('data'), findsOneWidget);
    expect(find.byIcon(Icons.insert_drive_file), findsOneWidget);
  });

  testWidgets('리소스는 최신순(역순)으로 쌓인다', (tester) async {
    await pumpTall(
      tester,
      developersHost(
        const NetworkInfo(),
        webViewModel: buildWebViewModel(loadedResources: [
          _resource(url: 'https://example.com/first.js', initiatorType: 'link'),
          _resource(
              url: 'https://example.com/second.js', initiatorType: 'link'),
        ]),
      ),
    );

    expect(tester.takeException(), isNull);
    // 나중에 로드된 것이 위에 온다. y 좌표로 순서를 고정한다.
    final firstY = tester.getTopLeft(find.text('first.js')).dy;
    final secondY = tester.getTopLeft(find.text('second.js')).dy;
    expect(secondY, lessThan(firstY));
  });
}
