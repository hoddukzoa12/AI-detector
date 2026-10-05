part of 'app_automation_controller.dart';

class _AutomationArgs {
  const _AutomationArgs(this._values);

  final Map<String, Object?> _values;

  String requiredString(String key) {
    final value = _values[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw ArgumentError.value(value, key, 'non-empty string required');
  }

  String? stringArg(String key) {
    final value = _values[key];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  String? rawStringArg(String key) {
    final value = _values[key];
    return value is String ? value : null;
  }

  bool requiredBool(String key) {
    final value = _values[key];
    if (value is bool) return value;
    throw ArgumentError.value(value, key, 'bool required');
  }

  bool boolArg(String key, {bool fallback = false}) {
    final value = _values[key];
    return value is bool ? value : fallback;
  }

  int requiredInt(String key) {
    final value = _values[key];
    final coerced = _coerceInt(value);
    if (coerced != null) return coerced;
    throw ArgumentError.value(value, key, 'int required');
  }

  int? intArg(String key) => _coerceInt(_values[key]);

  /// Coerces JSON-transport number shapes to [int]: native ints, integral
  /// doubles (e.g. `1.0` from JS/JSON-RPC), and numeric strings. Returns null
  /// for non-integral or non-numeric values so callers can reject them.
  static int? _coerceInt(Object? value) {
    if (value is int) return value;
    if (value is double) {
      return value.isFinite && value == value.roundToDouble()
          ? value.toInt()
          : null;
    }
    if (value is String) {
      final trimmed = value.trim();
      final asInt = int.tryParse(trimmed);
      if (asInt != null) return asInt;
      final asDouble = double.tryParse(trimmed);
      if (asDouble != null &&
          asDouble.isFinite &&
          asDouble == asDouble.roundToDouble()) {
        return asDouble.toInt();
      }
    }
    return null;
  }

  List<String> stringListArg(String key) {
    final value = _values[key];
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }
}
