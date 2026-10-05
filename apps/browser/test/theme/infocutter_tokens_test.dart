import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/theme/infocutter_theme.dart';
import 'package:infocutter_app/theme/infocutter_tokens.g.dart';

/// 토큰을 옮기기 **전에** 화면에 나가던 값이다. 이 표가 회귀 그물이다 —
/// 토큰 경유로 바꾸면서 색이 한 칸이라도 달라지면 여기서 걸린다.
///
/// 브랜드 색을 의도적으로 바꾸는 날에는 이 표도 같이 고친다. 그때는 "왜 바뀌는가" 가
/// 커밋에 남아야 하며, 조용히 흘러가서는 안 된다.
const _expectedLight = <String, int>{
  'primary': 0xFF0F766E,
  'accent': 0xFF0D9488,
  'onPrimary': 0xFFFFFFFF,
  'secondary': 0xFF0284C7,
  'base': 0xFFF8FAFC,
  'surface': 0xFFFFFFFF,
  'surfaceHigh': 0xFFF1F5F9,
  'inputFill': 0xFFFFFFFF,
  'outline': 0xFFD0D7DE,
  'text': 0xFF111827,
  'mutedText': 0xFF64748B,
  'tooltipBackground': 0xFF111827,
  'error': 0xFFDC2626,
};

const _expectedDark = <String, int>{
  'primary': 0xFF5EEAD4,
  'accent': 0xFF2DD4BF,
  'onPrimary': 0xFF0D1117,
  'secondary': 0xFF7DD3FC,
  'base': 0xFF0D1117,
  'surface': 0xFF161B22,
  'surfaceHigh': 0xFF21262D,
  'inputFill': 0xFF0F141A,
  'outline': 0xFF30363D,
  'text': 0xFFE6EDF3,
  'mutedText': 0xFF8B949E,
  'tooltipBackground': 0xFF010409,
  'error': 0xFFF87171,
};

Map<String, Color> _actual(Brightness brightness) {
  final tokens = InfocutterTokens(brightness);
  return {
    'primary': tokens.primary,
    'accent': tokens.accent,
    'onPrimary': tokens.onPrimary,
    'secondary': tokens.secondary,
    'base': tokens.base,
    'surface': tokens.surface,
    'surfaceHigh': tokens.surfaceHigh,
    'inputFill': tokens.inputFill,
    'outline': tokens.outline,
    'text': tokens.text,
    'mutedText': tokens.mutedText,
    'tooltipBackground': tokens.tooltipBackground,
    'error': tokens.error,
  };
}

void main() {
  group('생성된 토큰', () {
    test('라이트 값이 토큰 이관 전과 같다', () {
      final actual = _actual(Brightness.light);
      for (final entry in _expectedLight.entries) {
        expect(
          actual[entry.key]?.toARGB32(),
          entry.value,
          reason: '${entry.key} 라이트 값이 달라졌다',
        );
      }
    });

    test('다크 값이 토큰 이관 전과 같다', () {
      final actual = _actual(Brightness.dark);
      for (final entry in _expectedDark.entries) {
        expect(
          actual[entry.key]?.toARGB32(),
          entry.value,
          reason: '${entry.key} 다크 값이 달라졌다',
        );
      }
    });

    test('darkValue 가 없는 치수 토큰은 모드와 무관하다', () {
      expect(InfocutterTokens.spaceSm, 8.0);
      expect(InfocutterTokens.spaceMd, 16.0);
      expect(InfocutterTokens.radiusSm, 6.0);
      expect(InfocutterTokens.radiusMd, 8.0);
      expect(InfocutterTokens.radiusLg, 16.0);
    });
  });

  group('스냅샷과 생성물', () {
    test('design-tokens.json 의 모든 색 토큰이 생성물에 있다', () {
      final file = File('design/design-tokens.json');
      expect(file.existsSync(), isTrue, reason: '토큰 스냅샷이 레포에 있어야 한다');

      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final tokens = (decoded['tokens'] as List).cast<Map<String, Object?>>();
      final generated =
          File('lib/theme/infocutter_tokens.g.dart').readAsStringSync();

      for (final token in tokens) {
        final name = token['name']! as String;
        final camel = name
            .split('-')
            .indexed
            .map((e) =>
                e.$1 == 0 ? e.$2 : e.$2[0].toUpperCase() + e.$2.substring(1))
            .join();
        expect(
          generated.contains(camel),
          isTrue,
          reason: '토큰 "$name" 이 생성물에 없다. 생성기를 다시 돌릴 것',
        );
      }
    });

    test('생성물에 직접 고치지 말라는 표시가 있다', () {
      final generated =
          File('lib/theme/infocutter_tokens.g.dart').readAsStringSync();
      expect(generated, contains('GENERATED'));
      expect(generated, contains('generate_theme_tokens.dart'));
    });
  });

  group('테마', () {
    test('라이트/다크 테마가 토큰 색을 그대로 쓴다', () {
      final light = infocutterTheme(Brightness.light);
      final dark = infocutterTheme(Brightness.dark);

      expect(light.colorScheme.primary.toARGB32(), _expectedLight['primary']);
      expect(dark.colorScheme.primary.toARGB32(), _expectedDark['primary']);
      expect(light.scaffoldBackgroundColor.toARGB32(), _expectedLight['base']);
      expect(dark.scaffoldBackgroundColor.toARGB32(), _expectedDark['base']);
      expect(light.colorScheme.onSurface.toARGB32(), _expectedLight['text']);
      expect(dark.colorScheme.onSurface.toARGB32(), _expectedDark['text']);
    });

    test('입력 필드 채움색이 토큰을 따른다 — 다크에서 흰색으로 굳지 않는다', () {
      final dark = infocutterTheme(Brightness.dark);
      expect(
        dark.inputDecorationTheme.fillColor?.toARGB32(),
        _expectedDark['inputFill'],
      );
    });
  });
}
