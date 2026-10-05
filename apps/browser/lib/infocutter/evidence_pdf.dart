import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:infocutter_app/infocutter/evidence_models.dart';

/// Minimal single-page PDF summarising a capture manifest. Hand-rolled so the
/// app carries no PDF dependency.
Uint8List buildEvidenceSummaryPdf(Map<String, Object?> manifest, String html) {
  final stream = _buildPdfTextStream(_summaryLines(manifest, html));
  final objects = _buildPdfObjects(stream);
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (final object in objects) {
    offsets.add(utf8.encode(buffer.toString()).length);
    buffer.write(object);
  }
  _writePdfXref(buffer, objects.length, offsets.skip(1));
  return Uint8List.fromList(utf8.encode(buffer.toString()));
}

List<String> _summaryLines(Map<String, Object?> manifest, String html) => [
      'Infocutter Evidence Summary',
      'URL: ${manifest['url'] ?? ''}',
      'Title: ${manifest['pageTitle'] ?? ''}',
      'Captured: ${manifest['capturedAt'] ?? ''}',
      'HTML SHA-256: ${manifest['htmlSha256'] ?? ''}',
      'PNG SHA-256: ${manifest['pngSha256'] ?? ''}',
      'Matched term: ${manifest['matchedTerm'] ?? ''}',
      'Excerpt: ${evidenceHtmlExcerpt(html)}',
    ];

String _buildPdfTextStream(List<String> lines) {
  final content = StringBuffer('BT /F1 10 Tf 40 780 Td 14 TL\n');
  for (final line in lines) {
    content.writeln('(${_escapePdfText(line)}) Tj T*');
  }
  content.writeln('ET');
  return content.toString();
}

List<String> _buildPdfObjects(String stream) {
  final pageObject =
      '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
      '/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >> endobj\n';
  final streamObject =
      '5 0 obj << /Length ${utf8.encode(stream).length} >> stream\n'
      '$stream'
      'endstream endobj\n';
  final objects = <String>[
    '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n',
    '2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n',
    pageObject,
    '4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj\n',
    streamObject,
  ];
  return objects;
}

void _writePdfXref(
  StringBuffer buffer,
  int objectCount,
  Iterable<int> objectOffsets,
) {
  final xrefOffset = utf8.encode(buffer.toString()).length;
  buffer.write('xref\n0 ${objectCount + 1}\n');
  buffer.write('0000000000 65535 f \n');
  for (final offset in objectOffsets) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer.write('trailer << /Size ${objectCount + 1} /Root 1 0 R >>\n');
  buffer.write('startxref\n$xrefOffset\n%%EOF\n');
}

String _escapePdfText(String value) {
  return value
      .replaceAll('\\', r'\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)')
      .replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E]'), '?');
}
