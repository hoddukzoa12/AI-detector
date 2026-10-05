import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infocutter_app/models/javascript_console_log.dart';

class JavaScriptConsoleResult extends StatelessWidget {
  const JavaScriptConsoleResult({
    required this.log,
    super.key,
  });

  final JavaScriptConsoleLog log;

  @override
  Widget build(BuildContext context) {
    var textSpanChildrens = <InlineSpan>[];
    final iconData = _iconData(log.level);
    if (iconData != null) {
      textSpanChildrens.add(WidgetSpan(
        child: Container(
          padding: const EdgeInsets.only(right: 5.0),
          child: Icon(iconData, color: _iconColor(log.level), size: 14),
        ),
        alignment: PlaceholderAlignment.middle,
      ));
    }
    textSpanChildrens.add(TextSpan(
      text: log.message,
      style: TextStyle(color: _textColor(log.level)),
    ));

    return Material(
      color: _backgroundColor(log.level),
      child: InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: log.message));
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
            color: Colors.transparent,
            child: RichText(
              text: TextSpan(
                children: textSpanChildrens,
              ),
            ),
          )),
    );
  }

  Color _textColor(JavaScriptConsoleLogLevel level) {
    return switch (level) {
      JavaScriptConsoleLogLevel.error => Colors.red,
      JavaScriptConsoleLogLevel.tip => Colors.blue,
      _ => Colors.black,
    };
  }

  Color _backgroundColor(JavaScriptConsoleLogLevel level) {
    return switch (level) {
      JavaScriptConsoleLogLevel.error => Colors.red.withValues(alpha: 0.1),
      JavaScriptConsoleLogLevel.warning =>
        const Color.fromRGBO(255, 251, 227, 1),
      _ => Colors.transparent,
    };
  }

  IconData? _iconData(JavaScriptConsoleLogLevel level) {
    return switch (level) {
      JavaScriptConsoleLogLevel.error => Icons.report_problem,
      JavaScriptConsoleLogLevel.tip => Icons.info,
      JavaScriptConsoleLogLevel.warning => Icons.report_problem,
      JavaScriptConsoleLogLevel.log => null,
    };
  }

  Color? _iconColor(JavaScriptConsoleLogLevel level) {
    return switch (level) {
      JavaScriptConsoleLogLevel.error => Colors.red,
      JavaScriptConsoleLogLevel.tip => Colors.blueAccent,
      JavaScriptConsoleLogLevel.warning => Colors.orangeAccent,
      JavaScriptConsoleLogLevel.log => null,
    };
  }
}
