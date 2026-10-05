import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:infocutter_app/infocutter/evidence_models.dart';
import 'package:infocutter_app/infocutter/evidence_pdf.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:infocutter_app/infocutter/evidence_models.dart';

abstract interface class EvidenceStore {
  Future<String?> loadEvidenceJson();

  Future<void> saveEvidenceJson(String raw);
}

class SharedPreferencesEvidenceStore implements EvidenceStore {
  const SharedPreferencesEvidenceStore({
    this.storageKey = infocutterEvidenceStoreKey,
  });

  final String storageKey;

  @override
  Future<String?> loadEvidenceJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey);
  }

  @override
  Future<void> saveEvidenceJson(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, raw);
  }
}

abstract interface class EvidenceFileWriter {
  Future<EvidenceFileSet> writeEvidenceFiles({
    required String id,
    required String html,
    required Map<String, Object?> manifest,
    Uint8List? pngBytes,
  });
}

class LocalEvidenceFileWriter implements EvidenceFileWriter {
  const LocalEvidenceFileWriter();

  @override
  Future<EvidenceFileSet> writeEvidenceFiles({
    required String id,
    required String html,
    required Map<String, Object?> manifest,
    Uint8List? pngBytes,
  }) async {
    final supportDir = await getApplicationSupportDirectory();
    final evidenceDir = Directory(
      p.join(supportDir.path, 'infocutter-evidence', id),
    );
    await evidenceDir.create(recursive: true);
    final htmlFile = File(p.join(evidenceDir.path, 'page.html'));
    final manifestFile = File(p.join(evidenceDir.path, 'manifest.json'));
    final pdfFile = File(p.join(evidenceDir.path, 'summary.pdf'));
    final pngFile = File(p.join(evidenceDir.path, 'page.png'));
    await htmlFile.writeAsString(html);
    if (pngBytes != null && pngBytes.isNotEmpty) {
      await pngFile.writeAsBytes(pngBytes);
    }
    await pdfFile.writeAsBytes(buildEvidenceSummaryPdf(manifest, html));
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
    return EvidenceFileSet(
      htmlFilename: htmlFile.path,
      manifestFilename: manifestFile.path,
      pdfFilename: pdfFile.path,
      pngFilename: pngBytes == null || pngBytes.isEmpty ? '' : pngFile.path,
    );
  }
}

class EvidenceService extends ChangeNotifier {
  EvidenceService({
    EvidenceFileWriter? fileWriter,
    EvidenceStore? store,
  })  : _fileWriter = fileWriter ?? const LocalEvidenceFileWriter(),
        _store = store ?? const SharedPreferencesEvidenceStore();

  final EvidenceFileWriter _fileWriter;
  final EvidenceStore _store;

  EvidenceStoreSnapshot _snapshot = EvidenceStoreSnapshot.empty;
  bool _loaded = false;

  EvidenceStoreSnapshot get snapshot => _snapshot;
  bool get isLoaded => _loaded;
  List<EvidenceRecord> get records => List.unmodifiable(_snapshot.records);

  Future<void> load() async {
    final raw = await _store.loadEvidenceJson();
    if (raw != null && raw.isNotEmpty) {
      _snapshot = _decodeJson(raw);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<EvidenceRecord> captureHtmlSnapshot(
    EvidenceCaptureRequest request,
  ) async {
    final htmlSha256 = _htmlSha256(request.html);
    final pngSha256 = _pngSha256(request.pngBytes);
    final existing = _findExistingRecord(request.url, htmlSha256);
    if (existing != null) return existing;
    final capturedAt = DateTime.now().toUtc();
    final capture = EvidenceCaptureContext(
      id: 'iev-${capturedAt.toIso8601String().replaceAll(':', '-')}',
      sequence: _nextSequence(),
      capturedAt: capturedAt,
      htmlSha256: htmlSha256,
      pngSha256: pngSha256,
    );
    final manifest = _buildManifest(request, capture);
    final files = await _fileWriter.writeEvidenceFiles(
      id: capture.id,
      html: request.html,
      manifest: manifest,
      pngBytes: request.pngBytes,
    );
    final record = _buildRecord(request, files, capture);
    await _commit(
      _snapshot.copyWith(records: [record, ..._snapshot.records]),
    );
    return record;
  }

  String _htmlSha256(String html) =>
      sha256.convert(utf8.encode(html)).toString();

  String _pngSha256(Uint8List? pngBytes) {
    if (pngBytes == null || pngBytes.isEmpty) return '';
    return sha256.convert(pngBytes).toString();
  }

  EvidenceRecord? _findExistingRecord(Uri url, String htmlSha256) {
    for (final record in _snapshot.records) {
      if (record.url == url.toString() && record.htmlSha256 == htmlSha256) {
        return record;
      }
    }
    return null;
  }

  Map<String, Object?> _buildManifest(
    EvidenceCaptureRequest request,
    EvidenceCaptureContext capture,
  ) =>
      {
        'id': capture.id,
        'sequence': capture.sequence,
        'capturedAt': capture.capturedAt.toIso8601String(),
        'targetId': request.targetId,
        'matchedTerm': request.matchedTerm,
        'matchedText': request.matchedText,
        'pageTitle': request.pageTitle,
        'url': request.url.toString(),
        'htmlSha256': capture.htmlSha256,
        'pngSha256': capture.pngSha256,
      };

  EvidenceRecord _buildRecord(
    EvidenceCaptureRequest request,
    EvidenceFileSet files,
    EvidenceCaptureContext capture,
  ) =>
      EvidenceRecord(
        id: capture.id,
        sequence: capture.sequence,
        targetId: request.targetId,
        matchedTerm: request.matchedTerm,
        url: request.url.toString(),
        pageTitle: request.pageTitle,
        matchedText: request.matchedText,
        htmlExcerpt: evidenceHtmlExcerpt(request.html),
        capturedAt: capture.capturedAt,
        pngSha256: capture.pngSha256,
        pngFilename: files.pngFilename,
        htmlSha256: capture.htmlSha256,
        htmlFilename: files.htmlFilename,
        manifestFilename: files.manifestFilename,
        pdfFilename: files.pdfFilename,
        downloadId: null,
      );

  Future<void> deleteRecord(String id) {
    return _commit(
      _snapshot.copyWith(
        records: _snapshot.records.where((record) => record.id != id).toList(),
      ),
    );
  }

  int _nextSequence() {
    return _snapshot.records.fold<int>(
          0,
          (max, record) => record.sequence > max ? record.sequence : max,
        ) +
        1;
  }

  Future<void> _commit(EvidenceStoreSnapshot snapshot) async {
    _snapshot = snapshot;
    await _store.saveEvidenceJson(_encodeJson(snapshot));
    notifyListeners();
  }

  static EvidenceStoreSnapshot _decodeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return EvidenceStoreSnapshot.empty;
      if (decoded['version'] != null &&
          decoded['version'] != evidenceStorageVersion) {
        return EvidenceStoreSnapshot.empty;
      }
      final rawRecords = decoded['records'];
      return EvidenceStoreSnapshot(
        records: rawRecords is List
            ? rawRecords.map(_decodeRecord).whereType<EvidenceRecord>().toList()
            : const [],
      );
    } on FormatException {
      return EvidenceStoreSnapshot.empty;
    }
  }

  static EvidenceRecord? _decodeRecord(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final url = raw['url'];
    final capturedAt = _parseDate(raw['capturedAt']);
    if (id is! String || url is! String || capturedAt == null) {
      return null;
    }
    return EvidenceRecord(
      id: id,
      sequence: raw['sequence'] is int ? raw['sequence'] as int : 0,
      targetId: raw['targetId'] is String ? raw['targetId'] as String : '',
      matchedTerm:
          raw['matchedTerm'] is String ? raw['matchedTerm'] as String : '',
      url: url,
      pageTitle: raw['pageTitle'] is String ? raw['pageTitle'] as String : '',
      matchedText:
          raw['matchedText'] is String ? raw['matchedText'] as String : '',
      htmlExcerpt:
          raw['htmlExcerpt'] is String ? raw['htmlExcerpt'] as String : '',
      capturedAt: capturedAt,
      pngSha256: raw['pngSha256'] is String ? raw['pngSha256'] as String : '',
      pngFilename:
          raw['pngFilename'] is String ? raw['pngFilename'] as String : '',
      htmlSha256:
          raw['htmlSha256'] is String ? raw['htmlSha256'] as String : '',
      htmlFilename:
          raw['htmlFilename'] is String ? raw['htmlFilename'] as String : '',
      manifestFilename: raw['manifestFilename'] is String
          ? raw['manifestFilename'] as String
          : '',
      pdfFilename:
          raw['pdfFilename'] is String ? raw['pdfFilename'] as String : '',
      downloadId: raw['downloadId'] is int ? raw['downloadId'] as int : null,
    );
  }

  static String _encodeJson(EvidenceStoreSnapshot snapshot) => jsonEncode({
        'version': evidenceStorageVersion,
        'records': snapshot.records
            .map(
              (record) => {
                'id': record.id,
                'sequence': record.sequence,
                'targetId': record.targetId,
                'matchedTerm': record.matchedTerm,
                'url': record.url,
                'pageTitle': record.pageTitle,
                'matchedText': record.matchedText,
                'htmlExcerpt': record.htmlExcerpt,
                'capturedAt': record.capturedAt.toUtc().toIso8601String(),
                'pngSha256': record.pngSha256,
                'pngFilename': record.pngFilename,
                'htmlSha256': record.htmlSha256,
                'htmlFilename': record.htmlFilename,
                'manifestFilename': record.manifestFilename,
                'pdfFilename': record.pdfFilename,
                'downloadId': record.downloadId,
              },
            )
            .toList(),
      });

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}
