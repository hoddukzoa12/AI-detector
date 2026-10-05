enum JavaScriptConsoleLogLevel {
  log,
  error,
  tip,
  warning,
}

class JavaScriptConsoleLog {
  const JavaScriptConsoleLog({
    required this.message,
    this.level = JavaScriptConsoleLogLevel.log,
  });

  final String message;
  final JavaScriptConsoleLogLevel level;

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'level': level.name,
    };
  }

  static JavaScriptConsoleLog? fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return null;
    }
    final message = map['message'];
    if (message is! String) {
      return null;
    }

    return JavaScriptConsoleLog(
      message: message,
      level: JavaScriptConsoleLogLevel.values.firstWhere(
        (level) => level.name == map['level'],
        orElse: () => JavaScriptConsoleLogLevel.log,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is JavaScriptConsoleLog &&
        other.message == message &&
        other.level == level;
  }

  @override
  int get hashCode => Object.hash(message, level);
}
