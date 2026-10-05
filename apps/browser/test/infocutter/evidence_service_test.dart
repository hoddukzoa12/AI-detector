import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/evidence_service.dart';

class _MemoryEvidenceStore implements EvidenceStore {
  String? raw;

  @override
  Future<String?> loadEvidenceJson() async => raw;

  @override
  Future<void> saveEvidenceJson(String raw) async {
    this.raw = raw;
  }
}

class _MemoryEvidenceFileWriter implements EvidenceFileWriter {
  Map<String, Object?>? manifest;
  String? html;

  @override
  Future<EvidenceFileSet> writeEvidenceFiles({
    required String id,
    required String html,
    required Map<String, Object?> manifest,
    Uint8List? pngBytes,
  }) async {
    this.html = html;
    this.manifest = manifest;
    return EvidenceFileSet(
      htmlFilename: '/tmp/$id/page.html',
      manifestFilename: '/tmp/$id/manifest.json',
      pdfFilename: '/tmp/$id/summary.pdf',
      pngFilename:
          pngBytes == null || pngBytes.isEmpty ? '' : '/tmp/$id/page.png',
    );
  }
}

void main() {
  test('captureHtmlSnapshot stores a hash record and dedupes same HTML',
      () async {
    final store = _MemoryEvidenceStore();
    final writer = _MemoryEvidenceFileWriter();
    final service = EvidenceService(store: store, fileWriter: writer);
    final url = Uri.parse('https://example.com/article');

    final first = await service.captureHtmlSnapshot(
      EvidenceCaptureRequest(
        url: url,
        pageTitle: 'Article',
        html: '<html><body>Hello</body></html>',
      ),
    );
    final second = await service.captureHtmlSnapshot(
      EvidenceCaptureRequest(
        url: url,
        pageTitle: 'Article',
        html: '<html><body>Hello</body></html>',
      ),
    );

    expect(first.id, second.id);
    expect(service.records, hasLength(1));
    expect(service.records.single.sequence, 1);
    expect(service.records.single.htmlSha256, isNotEmpty);
    expect(service.records.single.htmlFilename, contains('/page.html'));
    expect(service.records.single.manifestFilename, contains('/manifest.json'));
    expect(service.records.single.pdfFilename, contains('/summary.pdf'));
    expect(writer.html, '<html><body>Hello</body></html>');
    expect(writer.manifest?['url'], 'https://example.com/article');
    expect(store.raw, isNotNull);
  });

  test('captureHtmlSnapshot stores png evidence when provided', () async {
    final service = EvidenceService(
      store: _MemoryEvidenceStore(),
      fileWriter: _MemoryEvidenceFileWriter(),
    );

    final record = await service.captureHtmlSnapshot(
      EvidenceCaptureRequest(
        url: Uri.parse('https://example.com/article'),
        pageTitle: 'Article',
        html: '<html><body>Hello</body></html>',
        pngBytes: Uint8List.fromList([1, 2, 3]),
      ),
    );

    expect(record.pngSha256, isNotEmpty);
    expect(record.pngFilename, contains('/page.png'));
  });

  test('deleteRecord removes the stored record', () async {
    final service = EvidenceService(
      store: _MemoryEvidenceStore(),
      fileWriter: _MemoryEvidenceFileWriter(),
    );
    final record = await service.captureHtmlSnapshot(
      EvidenceCaptureRequest(
        url: Uri.parse('https://example.com'),
        pageTitle: 'Example',
        html: '<html></html>',
      ),
    );

    await service.deleteRecord(record.id);

    expect(service.records, isEmpty);
  });
}
