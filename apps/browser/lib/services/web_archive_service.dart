import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/models/web_archive_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/services/app_runtime.dart';
import 'package:infocutter_app/util.dart';

class WebArchiveSaveRequest {
  const WebArchiveSaveRequest({
    required this.webViewModel,
    required this.timestamp,
  });

  final WebViewModel webViewModel;
  final DateTime timestamp;
}

abstract interface class WebArchiveService {
  Future<WebArchiveModel?> save(WebArchiveSaveRequest request);
}

class InAppWebViewArchiveService implements WebArchiveService {
  const InAppWebViewArchiveService({
    required AppRuntime runtime,
  }) : _runtime = runtime;

  final AppRuntime _runtime;

  @override
  Future<WebArchiveModel?> save(WebArchiveSaveRequest request) async {
    final url = request.webViewModel.url;
    final controller = request.webViewModel.webViewController;
    if (url == null || controller == null || !url.scheme.startsWith('http')) {
      return null;
    }

    final webArchivePath = _runtime.webArchivePathFor(
      url,
      extension: Util.isAndroid()
          ? WebArchiveFormat.MHT.toValue()
          : WebArchiveFormat.WEBARCHIVE.toValue(),
      timestampMicros: request.timestamp.microsecondsSinceEpoch,
    );

    final savedPath = await controller.saveWebArchive(
      filePath: webArchivePath,
    );
    if (savedPath == null) {
      return null;
    }

    return WebArchiveModel(
      url: url,
      path: savedPath,
      title: request.webViewModel.title,
      favicon: request.webViewModel.favicon,
      timestamp: request.timestamp,
    );
  }
}
