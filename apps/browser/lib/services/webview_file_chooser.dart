import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Android WebView 파일 선택 (`onShowFileChooser`) 을 file_picker 로 중계한다.
///
/// iOS 는 WKWebView 가 자체 시트를 띄우는 경우가 많아 이 콜백이 안 올 수 있다.
/// 그 경우 handledByClient=false 로 플랫폼 기본에 맡긴다.
class WebViewFileChooser {
  const WebViewFileChooser();

  Future<ShowFileChooserResponse?> pick(
    ShowFileChooserRequest request,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: request.mode == ShowFileChooserRequestMode.OPEN_MULTIPLE,
        type: _fileType(request.acceptTypes),
        allowedExtensions: _extensions(request.acceptTypes),
      );
      return _toResponse(result);
    } catch (_) {
      return ShowFileChooserResponse(handledByClient: false);
    }
  }

  FileType _fileType(List<String> accept) {
    if (accept.isNotEmpty && accept.every((a) => a.startsWith('image/'))) {
      return FileType.image;
    }
    if (accept.isNotEmpty && accept.every((a) => a.startsWith('.'))) {
      return FileType.custom;
    }
    return FileType.any;
  }

  List<String>? _extensions(List<String> accept) {
    if (accept.isEmpty || !accept.every((a) => a.startsWith('.'))) {
      return null;
    }
    return accept.map((a) => a.replaceFirst('.', '')).toList();
  }

  ShowFileChooserResponse _toResponse(FilePickerResult? result) {
    if (result == null || result.files.isEmpty) {
      return ShowFileChooserResponse(handledByClient: true);
    }
    final paths = result.files
        .map((f) => f.path)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .map((p) => p.startsWith('file:') ? p : 'file://$p')
        .toList(growable: false);
    if (paths.isEmpty) {
      return ShowFileChooserResponse(handledByClient: true);
    }
    return ShowFileChooserResponse(handledByClient: true, filePaths: paths);
  }
}
