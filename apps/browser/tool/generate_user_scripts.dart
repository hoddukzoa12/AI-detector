// assets/js/*.js 를 lib/infocutter/generated/user_scripts.g.dart 의 const 문자열로 굽는다.
//
// 왜 생성하는가: WebView 에 주입하는 JS 는 UserScript 계약상 const String 이어야
// 하므로 런타임 로딩(rootBundle)으로 바꾸면 초기화 경로가 흔들린다. 그래서 소스는
// 진짜 .js 파일로 두어 eslint·node 테스트를 받게 하고, Dart 쪽은 굽기만 한다.
//
// 실행:  fvm dart run tool/generate_user_scripts.dart
// 검사:  fvm dart run tool/generate_user_scripts.dart --check   (다르면 exit 1)

import 'dart:io';

const _outputPath = 'lib/infocutter/generated/user_scripts.g.dart';

/// (js 파일명, 생성할 Dart 상수명)
const _scripts = <(String, String)>[
  ('infocutter_runtime.js', 'infocutterRuntimeUserScriptSource'),
  ('picker.js', 'pickerUserScriptSource'),
  ('keyword_capture.js', 'keywordCaptureUserScriptSource'),
  ('lazy_image_promote.js', 'lazyImagePromoteUserScriptSource'),
];

String _build() {
  final buffer = StringBuffer()
    ..writeln('// GENERATED — 직접 고치지 마라.')
    ..writeln('// 원본은 assets/js/*.js 다. 고친 뒤 아래를 실행한다:')
    ..writeln('//   fvm dart run tool/generate_user_scripts.dart')
    ..writeln();

  for (final (file, name) in _scripts) {
    final body = File('assets/js/$file').readAsStringSync();
    if (body.contains("'''")) {
      stderr.writeln('assets/js/$file 에 삼중 따옴표가 있어 raw string 을 깨뜨린다.');
      exit(1);
    }
    buffer
      ..writeln("/// assets/js/$file")
      ..writeln("const String $name = r'''")
      ..write(body)
      ..writeln("''';")
      ..writeln();
  }
  // dart format 은 파일 끝의 빈 줄을 하나만 남긴다. 생성 결과가 곧바로
  // format 통과 상태여야 --check 와 format-check 가 서로 싸우지 않는다.
  return '${buffer.toString().trimRight()}\n';
}

void main(List<String> args) {
  final generated = _build();
  final output = File(_outputPath);

  if (args.contains('--check')) {
    final current = output.existsSync() ? output.readAsStringSync() : '';
    if (current == generated) {
      stdout.writeln('user_scripts.g.dart 는 assets/js 와 동기 상태다.');
      return;
    }
    stderr.writeln(
      'user_scripts.g.dart 가 assets/js 와 다르다. '
      'fvm dart run tool/generate_user_scripts.dart 를 실행할 것.',
    );
    exit(1);
  }

  output.parent.createSync(recursive: true);
  output.writeAsStringSync(generated);
  stdout.writeln('생성: $_outputPath');
}
