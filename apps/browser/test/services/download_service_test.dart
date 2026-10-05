import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/services/download_service.dart';

/// Regression net for the pure parts of the download layer: the request value
/// object and its filename derivation. [FlutterDownloadService] itself is not
/// covered — it reaches path_provider and flutter_downloader plugin channels.
void main() {
  group('DownloadTaskRequest.fileNameFromPath', () {
    test('takes the segment after the last slash', () {
      expect(
        DownloadTaskRequest.fileNameFromPath('/a/b/report.pdf'),
        'report.pdf',
      );
    });

    test('returns the whole string when there is no slash', () {
      expect(DownloadTaskRequest.fileNameFromPath('report.pdf'), 'report.pdf');
    });

    test('returns null when the path ends in a slash', () {
      expect(DownloadTaskRequest.fileNameFromPath('/a/b/'), isNull);
    });

    test('returns null for an empty path', () {
      expect(DownloadTaskRequest.fileNameFromPath(''), isNull);
    });

    test('returns null for a bare slash', () {
      expect(DownloadTaskRequest.fileNameFromPath('/'), isNull);
    });

    test('keeps query strings — it is a plain string split, not URL aware', () {
      // Current behaviour: no URL parsing happens here, so a query string
      // stays glued to the name. Change only if the split becomes URL aware.
      expect(
        DownloadTaskRequest.fileNameFromPath('/files/doc.pdf?token=1'),
        'doc.pdf?token=1',
      );
    });

    test('handles a trailing name with no extension', () {
      expect(DownloadTaskRequest.fileNameFromPath('/a/b/LICENSE'), 'LICENSE');
    });
  });

  group('DownloadTaskRequest defaults', () {
    test('notification flags default to true and fileName to null', () {
      const request = DownloadTaskRequest(
        url: 'https://example.com/a.pdf',
        destination: DownloadDestination.temporaryDirectory,
      );

      expect(request.fileName, isNull);
      expect(request.showNotification, isTrue);
      expect(request.openFileFromNotification, isTrue);
      expect(request.destination, DownloadDestination.temporaryDirectory);
    });

    test('explicit values are carried through', () {
      const request = DownloadTaskRequest(
        url: 'https://example.com/a.pdf',
        destination: DownloadDestination.externalStorageDirectory,
        fileName: 'renamed.pdf',
        showNotification: false,
        openFileFromNotification: false,
      );

      expect(request.fileName, 'renamed.pdf');
      expect(request.showNotification, isFalse);
      expect(request.openFileFromNotification, isFalse);
      expect(
        request.destination,
        DownloadDestination.externalStorageDirectory,
      );
    });
  });

  test('DownloadDestination has exactly two variants', () {
    // Adding a destination requires a new branch in FlutterDownloadService's
    // switch; this constant is the reminder.
    expect(DownloadDestination.values, hasLength(2));
  });
}
