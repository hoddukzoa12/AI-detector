import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class AppRuntime {
  const AppRuntime({
    required this.webArchiveDirectory,
    required this.webViewEnvironment,
  });

  final String webArchiveDirectory;
  final WebViewEnvironment? webViewEnvironment;

  String webArchivePathFor(
    Uri url, {
    required String extension,
    required int timestampMicros,
  }) {
    final fileName = '${url.scheme}-${url.host}${url.path.replaceAll("/", "-")}'
        '$timestampMicros.$extension';
    return '$webArchiveDirectory${Platform.pathSeparator}$fileName';
  }
}
