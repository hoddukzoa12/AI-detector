// design/design-tokens.json 을 lib/theme/infocutter_tokens.g.dart 로 굽는다.
//
// 왜 스냅샷을 거치는가: 토큰 정본은 design-system-studio(macOS 앱)이지만 그 CLI 는
// 이 맥에만 있다. 생성기가 CLI 를 직접 부르면 CI·다른 기여자 환경에서 빌드도 검사도
// 못 한다. 그래서 export 결과를 레포에 스냅샷으로 두고, 생성기는 그 파일만 읽는다.
//
// 토큰을 바꿀 때:
//   design-system-studio tokens export <set> --format json > design/design-tokens.json
//   fvm dart run tool/generate_theme_tokens.dart
//
// 실행:  fvm dart run tool/generate_theme_tokens.dart
// 검사:  fvm dart run tool/generate_theme_tokens.dart --check   (다르면 exit 1)

import 'dart:convert';
import 'dart:io';

const _inputPath = 'design/design-tokens.json';
const _outputPath = 'lib/theme/infocutter_tokens.g.dart';

/// `muted-text` → `mutedText`
String _camelCase(String name) {
  final parts = name.split('-').where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) {
    throw FormatException('토큰 이름이 비어 있다: "$name"');
  }
  return parts.first +
      parts
          .skip(1)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join();
}

/// `#4F46E5` → `0xFF4F46E5`
String _colorLiteral(String hex, String tokenName) {
  final value = hex.trim();
  if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
    throw FormatException('color 토큰 "$tokenName" 의 값이 #RRGGBB 가 아니다: "$hex"');
  }
  return '0xFF${value.substring(1).toUpperCase()}';
}

/// `16px` → `16`
String _dimensionLiteral(String raw, String tokenName) {
  final value = raw.trim().replaceAll('px', '');
  final parsed = double.tryParse(value);
  if (parsed == null) {
    throw FormatException('치수 토큰 "$tokenName" 의 값을 읽을 수 없다: "$raw"');
  }
  return parsed == parsed.roundToDouble()
      ? '${parsed.toInt()}.0'
      : parsed.toString();
}

String _build(String rawJson) {
  final decoded = jsonDecode(rawJson);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('$_inputPath 의 최상위가 JSON 객체가 아니다.');
  }
  final tokens = decoded['tokens'];
  if (tokens is! List || tokens.isEmpty) {
    throw const FormatException('$_inputPath 에 tokens 배열이 없다.');
  }

  final colors = <(String, String, String)>[]; // (이름, light, dark)
  final dimensions = <(String, String, String)>[]; // (이름, 값, 종류)
  final seen = <String>{};

  for (final entry in tokens) {
    if (entry is! Map<String, Object?>) {
      throw const FormatException('tokens 의 원소가 객체가 아니다.');
    }
    final name = entry['name'];
    final type = entry['type'];
    final value = entry['value'];
    if (name is! String || type is! String || value is! String) {
      throw const FormatException('토큰에 name·type·value 문자열이 모두 있어야 한다.');
    }
    final dartName = _camelCase(name);
    if (!seen.add(dartName)) {
      throw FormatException('Dart 이름이 겹친다: "$dartName" ("$name")');
    }

    switch (type) {
      case 'color':
        final dark = entry['darkValue'];
        colors.add((
          dartName,
          _colorLiteral(value, name),
          _colorLiteral(dark is String ? dark : value, name),
        ));
      case 'spacing':
      case 'radius':
        dimensions.add((dartName, _dimensionLiteral(value, name), type));
      default:
        throw FormatException('모르는 토큰 종류다: "$type" ("$name")');
    }
  }

  final buffer = StringBuffer()
    ..writeln('// GENERATED — 직접 고치지 마라.')
    ..writeln('// 원본은 $_inputPath 다. 고친 뒤 아래를 실행한다:')
    ..writeln('//   fvm dart run tool/generate_theme_tokens.dart')
    ..writeln()
    ..writeln("import 'package:flutter/material.dart';")
    ..writeln()
    ..writeln('/// 디자인 토큰. 정본은 design-system-studio 이며 이 파일은 생성물이다.')
    ..writeln('///')
    ..writeln('/// 색은 [brightness] 에 따라 라이트/다크 값을 고른다. 치수는 모드와 무관하다.')
    ..writeln('class InfocutterTokens {')
    ..writeln('  const InfocutterTokens(this.brightness);')
    ..writeln()
    ..writeln('  final Brightness brightness;')
    ..writeln()
    ..writeln('  bool get isDark => brightness == Brightness.dark;')
    ..writeln();

  for (final (name, light, dark) in colors) {
    // dart format 의 80칸 규칙을 그대로 흉내낸다. 생성 결과가 곧바로 format 통과
    // 상태가 아니면 --check 와 format-check 가 서로를 무한히 되돌린다.
    final oneLine =
        '  Color get $name => isDark ? const Color($dark) : const Color($light);';
    if (oneLine.length <= 80) {
      buffer.writeln(oneLine);
    } else {
      buffer
        ..writeln('  Color get $name =>')
        ..writeln('      isDark ? const Color($dark) : const Color($light);');
    }
    buffer.writeln();
  }

  for (final (name, value, kind) in dimensions) {
    buffer
      ..writeln('  /// $kind')
      ..writeln('  static const double $name = $value;')
      ..writeln();
  }

  // 마지막 멤버 뒤의 빈 줄은 닫는 괄호와 붙는다.
  final body = buffer.toString().trimRight();
  return '$body\n}\n';
}

void main(List<String> args) {
  final input = File(_inputPath);
  if (!input.existsSync()) {
    stderr.writeln('$_inputPath 가 없다. 앱 디렉터리에서 실행할 것.');
    exit(1);
  }

  final String generated;
  try {
    generated = _build(input.readAsStringSync());
  } on FormatException catch (error) {
    stderr.writeln('$_inputPath 를 읽지 못했다: ${error.message}');
    exit(1);
  }

  final output = File(_outputPath);

  if (args.contains('--check')) {
    final current = output.existsSync() ? output.readAsStringSync() : '';
    if (current == generated) {
      stdout.writeln('infocutter_tokens.g.dart 는 $_inputPath 와 동기 상태다.');
      return;
    }
    stderr.writeln(
      'infocutter_tokens.g.dart 가 $_inputPath 와 다르다. '
      'fvm dart run tool/generate_theme_tokens.dart 를 실행할 것.',
    );
    exit(1);
  }

  output.parent.createSync(recursive: true);
  output.writeAsStringSync(generated);
  stdout.writeln('생성: $_outputPath');
}
