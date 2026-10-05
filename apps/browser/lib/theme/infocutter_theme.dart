import 'package:flutter/material.dart';
import 'package:infocutter_app/theme/infocutter_tokens.g.dart';

ThemeData infocutterTheme(Brightness brightness) {
  final palette = _InfocutterPalette(brightness);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: _infocutterColorScheme(palette),
    scaffoldBackgroundColor: palette.base,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    appBarTheme: _infocutterAppBarTheme(palette),
    cardTheme: _infocutterCardTheme(palette),
    chipTheme: _infocutterChipTheme(palette),
    dividerColor: palette.outline,
    filledButtonTheme: _infocutterFilledButtonTheme(palette),
    outlinedButtonTheme: _infocutterOutlinedButtonTheme(palette),
    textButtonTheme: _infocutterTextButtonTheme(palette),
    iconButtonTheme: _infocutterIconButtonTheme(palette),
    inputDecorationTheme: _infocutterInputDecorationTheme(palette),
    listTileTheme: _infocutterListTileTheme(palette),
    popupMenuTheme: _infocutterPopupMenuTheme(palette),
    switchTheme: _infocutterSwitchTheme(palette),
    tabBarTheme: _infocutterTabBarTheme(palette),
    tooltipTheme: _infocutterTooltipTheme(palette),
  );
}

/// Color values of the infocutter theme, resolved per [brightness].
///
/// 값의 정본은 design-system-studio 이며 `design/design-tokens.json` 스냅샷을 거쳐
/// [InfocutterTokens] 로 생성된다. **여기서 색을 새로 만들지 마라** — 토큰을 늘리고
/// 다시 구우면 된다. 이 클래스는 토큰에 의미 이름을 붙이는 얇은 층이다.
class _InfocutterPalette {
  _InfocutterPalette(this.brightness) : _tokens = InfocutterTokens(brightness);

  final Brightness brightness;
  final InfocutterTokens _tokens;

  bool get isDark => brightness == Brightness.dark;

  Color get primary => _tokens.primary;
  Color get accent => _tokens.accent;
  Color get base => _tokens.base;
  Color get surface => _tokens.surface;
  Color get surfaceHigh => _tokens.surfaceHigh;
  Color get inputFill => _tokens.inputFill;
  Color get outline => _tokens.outline;
  Color get text => _tokens.text;
  Color get mutedText => _tokens.mutedText;
  Color get tooltipBackground => _tokens.tooltipBackground;
  Color get onPrimary => _tokens.onPrimary;
  Color get secondary => _tokens.secondary;
  Color get error => _tokens.error;

  double get chipSelectedAlpha => isDark ? 0.22 : 0.16;
}

ColorScheme _infocutterColorScheme(_InfocutterPalette palette) =>
    ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: palette.brightness,
    ).copyWith(
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      primaryContainer: palette.surfaceHigh,
      onPrimaryContainer: palette.text,
      secondary: palette.secondary,
      onSecondary: palette.onPrimary,
      surface: palette.surface,
      onSurface: palette.text,
      surfaceContainerHighest: palette.surfaceHigh,
      outline: palette.outline,
      error: palette.error,
      onError: Colors.white,
    );

AppBarTheme _infocutterAppBarTheme(_InfocutterPalette palette) => AppBarTheme(
      backgroundColor: palette.base,
      foregroundColor: palette.text,
      elevation: 0,
    );

CardThemeData _infocutterCardTheme(_InfocutterPalette palette) => CardThemeData(
      color: palette.surfaceHigh,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(InfocutterTokens.radiusMd),
        side: BorderSide(color: palette.outline),
      ),
    );

ChipThemeData _infocutterChipTheme(_InfocutterPalette palette) => ChipThemeData(
      backgroundColor: palette.surfaceHigh,
      selectedColor:
          palette.accent.withValues(alpha: palette.chipSelectedAlpha),
      disabledColor: palette.surfaceHigh.withValues(alpha: 0.55),
      labelStyle: TextStyle(color: palette.text),
      secondaryLabelStyle: TextStyle(color: palette.text),
      side: BorderSide(color: palette.outline),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InfocutterTokens.radiusMd)),
    );

FilledButtonThemeData _infocutterFilledButtonTheme(
  _InfocutterPalette palette,
) =>
    FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        disabledBackgroundColor: palette.surfaceHigh,
        disabledForegroundColor: palette.mutedText,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InfocutterTokens.radiusMd)),
      ),
    );

OutlinedButtonThemeData _infocutterOutlinedButtonTheme(
  _InfocutterPalette palette,
) =>
    OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.primary,
        side: BorderSide(color: palette.outline),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InfocutterTokens.radiusMd)),
      ),
    );

TextButtonThemeData _infocutterTextButtonTheme(_InfocutterPalette palette) =>
    TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: palette.primary),
    );

IconButtonThemeData _infocutterIconButtonTheme(_InfocutterPalette palette) =>
    IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: palette.text,
        hoverColor: palette.primary.withValues(alpha: 0.10),
      ),
    );

InputDecorationTheme _infocutterInputDecorationTheme(
  _InfocutterPalette palette,
) =>
    InputDecorationTheme(
      filled: true,
      fillColor: palette.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(InfocutterTokens.radiusMd),
        borderSide: BorderSide(color: palette.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(InfocutterTokens.radiusMd),
        borderSide: BorderSide(color: palette.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(InfocutterTokens.radiusMd),
        borderSide: BorderSide(color: palette.primary, width: 1.4),
      ),
    );

ListTileThemeData _infocutterListTileTheme(_InfocutterPalette palette) =>
    ListTileThemeData(
      iconColor: palette.mutedText,
      textColor: palette.text,
    );

PopupMenuThemeData _infocutterPopupMenuTheme(_InfocutterPalette palette) =>
    PopupMenuThemeData(
      color: palette.surfaceHigh,
      textStyle: TextStyle(color: palette.text),
    );

SwitchThemeData _infocutterSwitchTheme(_InfocutterPalette palette) =>
    SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.base
            : palette.mutedText,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.primary
            : palette.surfaceHigh,
      ),
      trackOutlineColor: WidgetStateProperty.all(palette.outline),
    );

TabBarThemeData _infocutterTabBarTheme(_InfocutterPalette palette) =>
    TabBarThemeData(
      labelColor: palette.primary,
      unselectedLabelColor: palette.mutedText,
      indicatorColor: palette.primary,
      dividerColor: palette.outline,
    );

TooltipThemeData _infocutterTooltipTheme(_InfocutterPalette palette) =>
    TooltipThemeData(
      decoration: BoxDecoration(
        color: palette.tooltipBackground,
        borderRadius: BorderRadius.circular(InfocutterTokens.radiusSm),
        border: Border.all(color: palette.outline),
      ),
      textStyle: const TextStyle(color: Colors.white),
    );
