import 'package:crypto/crypto.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

/// certificates_info_popup 에서 갈라져 나온 인증서 필드 렌더 헬퍼들.
/// 동작은 원본과 동일하다.

List<Widget> certificateSectionHeader(String title, {bool spaced = true}) => [
      if (spaced) const SizedBox(height: 15.0),
      Text(
        title,
        style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
      ),
    ];

List<Widget> certificateField(String label, String value) => [
      const SizedBox(height: 5.0),
      Text(
        label,
        style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
      ),
      Text(
        value,
        style: const TextStyle(fontSize: 14.0),
      ),
    ];

String certificateNotPart(String? value) {
  return value ?? "<Not Part Of Certificate>";
}

String certificateHexByte(int byte) {
  return byte.toRadixString(16).padLeft(2, "0").toUpperCase();
}

String formatCertificateDate(DateTime? date) {
  return date == null
      ? "<Not Part Of Certificate>"
      : DateFormat("dd MMM yyyy HH:mm:ss").format(date);
}

String certificateOidLabel(String? value) {
  return value == null
      ? "<Not Part Of Certificate>"
      : "${OID.fromValue(value)!.name()} ( $value )";
}

String certificateOidDisplay(String value) {
  final oid = OID.fromValue(value);
  return oid != null ? "${oid.name()} ( ${oid.toValue()} )" : "( $value )";
}

List<Widget> certificateExtensionHeader(String title, OID oid) => [
      const SizedBox(height: 15.0),
      Text(
        "$title ( ${oid.toValue()} )",
        style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
      ),
    ];

String certificateCriticalValue(
  Iterable<String> criticalExtensionOIDs,
  OID oid,
) {
  return criticalExtensionOIDs.firstWhereOrNull(
            (value) => value == oid.toValue(),
          ) !=
          null
      ? "YES"
      : "NO";
}

List<Widget> certificateExtensionMissing() => const [
      SizedBox(height: 5.0),
      Text(
        "<Not Part Of Certificate>",
        style: TextStyle(fontSize: 14.0),
      ),
    ];

Widget certificateExtensionField(String label, String value) {
  return RichText(
    text: TextSpan(
      children: [
        TextSpan(
          text: "$label ",
          style: const TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        TextSpan(
          text: value,
          style: const TextStyle(fontSize: 12.0, color: Colors.black),
        ),
      ],
    ),
  );
}

Widget certificateLinkedExtensionField(
  String label,
  String value,
  Future<void> Function() onTap,
) {
  return RichText(
    text: TextSpan(
      children: [
        TextSpan(
          text: "$label ",
          style: const TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        TextSpan(
          text: value,
          style: const TextStyle(fontSize: 12.0, color: Colors.blue),
          recognizer: TapGestureRecognizer()..onTap = onTap,
        ),
      ],
    ),
  );
}

List<Widget> certificateCriticalField(String value) => [
      const SizedBox(height: 5.0),
      certificateExtensionField("Critical", value),
    ];

List<Widget> certificateFingerprintField(
  String label,
  Future<Digest>? digest,
) =>
    [
      const SizedBox(height: 5.0),
      Text(
        label,
        style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
      ),
      FutureBuilder(
        future: digest,
        builder: (context, snapshot) {
          if (!snapshot.hasData ||
              snapshot.connectionState != ConnectionState.done) {
            return const Text("");
          }

          final digest = snapshot.data as Digest;
          return Text(
            digest.bytes.map(certificateHexByte).join(" "),
            style: const TextStyle(fontSize: 14.0),
          );
        },
      ),
    ];
