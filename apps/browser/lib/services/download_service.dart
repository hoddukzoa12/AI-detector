import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';

enum DownloadDestination {
  temporaryDirectory,
  externalStorageDirectory,
}

class DownloadTaskRequest {
  const DownloadTaskRequest({
    required this.url,
    required this.destination,
    this.fileName,
    this.showNotification = true,
    this.openFileFromNotification = true,
  });

  final String url;
  final DownloadDestination destination;
  final String? fileName;
  final bool showNotification;
  final bool openFileFromNotification;

  static String? fileNameFromPath(String path) {
    final slashIndex = path.lastIndexOf('/');
    final fileName = slashIndex >= 0 ? path.substring(slashIndex + 1) : path;
    return fileName.isEmpty ? null : fileName;
  }
}

abstract interface class DownloadService {
  Future<String?> enqueue(DownloadTaskRequest request);
}

class FlutterDownloadService implements DownloadService {
  const FlutterDownloadService();

  @override
  Future<String?> enqueue(DownloadTaskRequest request) async {
    final savedDir = switch (request.destination) {
      DownloadDestination.temporaryDirectory =>
        (await getTemporaryDirectory()).path,
      DownloadDestination.externalStorageDirectory =>
        (await getExternalStorageDirectory())?.path,
    };

    if (savedDir == null) {
      throw StateError('Download directory is not available');
    }

    return FlutterDownloader.enqueue(
      url: request.url,
      fileName: request.fileName,
      savedDir: savedDir,
      showNotification: request.showNotification,
      openFileFromNotification: request.openFileFromNotification,
    );
  }
}
