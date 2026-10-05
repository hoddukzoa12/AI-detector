// GENERATED — 직접 고치지 마라.
// 원본은 design/design-tokens.json 다. 고친 뒤 아래를 실행한다:
//   fvm dart run tool/generate_theme_tokens.dart

import 'package:flutter/material.dart';

/// 디자인 토큰. 정본은 design-system-studio 이며 이 파일은 생성물이다.
///
/// 색은 [brightness] 에 따라 라이트/다크 값을 고른다. 치수는 모드와 무관하다.
class InfocutterTokens {
  const InfocutterTokens(this.brightness);

  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  Color get primary =>
      isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E);

  Color get accent =>
      isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);

  Color get onPrimary =>
      isDark ? const Color(0xFF0D1117) : const Color(0xFFFFFFFF);

  Color get secondary =>
      isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7);

  Color get base => isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);

  Color get surface =>
      isDark ? const Color(0xFF161B22) : const Color(0xFFFFFFFF);

  Color get surfaceHigh =>
      isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9);

  Color get inputFill =>
      isDark ? const Color(0xFF0F141A) : const Color(0xFFFFFFFF);

  Color get outline =>
      isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE);

  Color get text => isDark ? const Color(0xFFE6EDF3) : const Color(0xFF111827);

  Color get mutedText =>
      isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);

  Color get tooltipBackground =>
      isDark ? const Color(0xFF010409) : const Color(0xFF111827);

  Color get error => isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);

  /// spacing
  static const double spaceSm = 8.0;

  /// spacing
  static const double spaceMd = 16.0;

  /// spacing
  static const double spaceLg = 24.0;

  /// spacing
  static const double spaceXl = 32.0;

  /// radius
  static const double radiusSm = 6.0;

  /// radius
  static const double radiusMd = 8.0;

  /// radius
  static const double radiusLg = 16.0;
}
