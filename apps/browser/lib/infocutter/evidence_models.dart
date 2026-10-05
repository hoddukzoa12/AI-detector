import 'package:flutter/foundation.dart';

const String infocutterEvidenceStoreKey = 'infocutter.evidenceRecords';
const int evidenceStorageVersion = 1;

@immutable
class EvidenceCaptureRequest {
  const EvidenceCaptureRequest({
    required this.url,
    required this.pageTitle,
    required this.html,
    this.pngBytes,
    this.targetId = '',
    this.matchedTerm = '',
    this.matchedText = '',
  });

  final Uri url;
  final String pageTitle;
  final String html;
  final Uint8List? pngBytes;
  final String targetId;
  final String matchedTerm;
  final String matchedText;
}

@immutable
class EvidenceRecord {
  const EvidenceRecord({
    required this.id,
    required this.sequence,
    required this.targetId,
    required this.matchedTerm,
    required this.url,
    required this.pageTitle,
    required this.matchedText,
    required this.htmlExcerpt,
    required this.capturedAt,
    required this.pngSha256,
    required this.pngFilename,
    required this.htmlSha256,
    required this.htmlFilename,
    required this.manifestFilename,
    required this.pdfFilename,
    required this.downloadId,
  });

  final String id;
  final int sequence;
  final String targetId;
  final String matchedTerm;
  final String url;
  final String pageTitle;
  final String matchedText;
  final String htmlExcerpt;
  final DateTime capturedAt;
  final String pngSha256;
  final String pngFilename;
  final String htmlSha256;
  final String htmlFilename;
  final String manifestFilename;
  final String pdfFilename;
  final int? downloadId;
}

@immutable
class EvidenceFileSet {
  const EvidenceFileSet({
    required this.htmlFilename,
    required this.manifestFilename,
    required this.pdfFilename,
    required this.pngFilename,
  });

  final String htmlFilename;
  final String manifestFilename;
  final String pdfFilename;
  final String pngFilename;
}

@immutable
class EvidenceStoreSnapshot {
  const EvidenceStoreSnapshot({
    required this.records,
  });

  final List<EvidenceRecord> records;

  EvidenceStoreSnapshot copyWith({
    List<EvidenceRecord>? records,
  }) =>
      EvidenceStoreSnapshot(records: records ?? this.records);

  static const empty = EvidenceStoreSnapshot(records: []);
}

/// The per-capture identity/digest values computed once and shared by the
/// manifest and the stored record.
class EvidenceCaptureContext {
  const EvidenceCaptureContext({
    required this.id,
    required this.sequence,
    required this.capturedAt,
    required this.htmlSha256,
    required this.pngSha256,
  });

  final String id;
  final int sequence;
  final DateTime capturedAt;
  final String htmlSha256;
  final String pngSha256;
}

/// Compacted, length-capped page text stored alongside a record and printed
/// into the summary PDF.
String evidenceHtmlExcerpt(String html) {
  final compact = html.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= 500) return compact;
  return compact.substring(0, 500);
}
