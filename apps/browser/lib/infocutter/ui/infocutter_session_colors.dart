import 'package:flutter/material.dart';

/// Badge/box palette for staged cards. Kept in lockstep with the in-page
/// `SESSION_COLORS` in selector_engine.dart so a card's sidebar number matches
/// its on-page highlight color (1-based index → color).
const List<Color> kInfocutterSessionColors = [
  Color(0xFF2563EB), // blue
  Color(0xFFDC2626), // red
  Color(0xFF16A34A), // green
  Color(0xFFCA8A04), // amber
  Color(0xFF9333EA), // purple
];

Color infocutterSessionColor(int index) =>
    kInfocutterSessionColors[index % kInfocutterSessionColors.length];
