import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/app_bar/certificates/certificate_extensions_view.dart';
import 'package:infocutter_app/app_bar/certificates/certificate_field_widgets.dart';
import 'package:infocutter_app/app_bar/certificates/certificate_name_lookup.dart';

/// certificates_info_popup 에서 갈라져 나온 인증서 상세 렌더.
/// 동작은 원본 `_buildCertificateInfo` 와 동일하다.
class CertificateInfoView extends StatelessWidget {
  final X509Certificate x509certificate;
  final Future<void> Function(String url, bool fallbackToLaunch) onUriTap;

  const CertificateInfoView({
    required this.x509certificate,
    required this.onUriTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var children = <Widget>[];
    children.addAll(_buildIssuedToSection(x509certificate));
    children.addAll(_buildIssuedBySection(x509certificate));
    children.addAll(_buildValidityPeriodSection(x509certificate));
    children.addAll(_buildPublicKeySection(x509certificate));
    children.addAll(_buildFingerprintSection(x509certificate));
    children.addAll(
      buildCertificateExtensionSection(x509certificate, onUriTap),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  List<Widget> _buildIssuedToSection(X509Certificate x509certificate) {
    return <Widget>[
      ...certificateSectionHeader("ISSUED TO", spaced: false),
      ..._buildDistinguishedNameFields(x509certificate, isSubject: true),
    ];
  }

  /// ISSUED TO 와 ISSUED BY 는 같은 5개 DN 필드를 주체(subject)로 보느냐
  /// 발급자(issuer)로 보느냐만 다르게 읽는다. 한 곳에서 만든다.
  List<Widget> _buildDistinguishedNameFields(
    X509Certificate x509certificate, {
    required bool isSubject,
  }) {
    return <Widget>[
      ...certificateField(
        "Common Name (CN)",
        certificateNotPart(
          findCertificateCommonName(
            x509certificate: x509certificate,
            isSubject: isSubject,
          ),
        ),
      ),
      ...certificateField(
        "Organization (O)",
        certificateNotPart(
          findCertificateOrganizationName(
            x509certificate: x509certificate,
            isSubject: isSubject,
          ),
        ),
      ),
      ...certificateField(
        "Organizational Unit (U)",
        certificateNotPart(
          findCertificateOrganizationUnitName(
            x509certificate: x509certificate,
            isSubject: isSubject,
          ),
        ),
      ),
      ...certificateField(
        "Country",
        certificateNotPart(
          findCertificateCountryName(
            x509certificate: x509certificate,
            isSubject: isSubject,
          ),
        ),
      ),
      ...certificateField(
        "State/Province",
        certificateNotPart(
          findCertificateStateOrProvinceName(
            x509certificate: x509certificate,
            isSubject: isSubject,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildIssuedBySection(X509Certificate x509certificate) {
    return <Widget>[
      ...certificateSectionHeader("ISSUED BY"),
      ..._buildDistinguishedNameFields(x509certificate, isSubject: false),
      ...certificateField(
        "Serial Number",
        certificateNotPart(
          x509certificate.serialNumber?.map(certificateHexByte).join(":"),
        ),
      ),
      ...certificateField(
        "Version",
        certificateNotPart(x509certificate.version?.toString()),
      ),
      ...certificateField(
        "Signature Algorithm",
        certificateNotPart(x509certificate.sigAlgName),
      ),
    ];
  }

  List<Widget> _buildValidityPeriodSection(X509Certificate x509certificate) {
    return <Widget>[
      ...certificateSectionHeader("VALIDITY PERIOD"),
      ...certificateField(
        "Issued on date",
        formatCertificateDate(x509certificate.notBefore),
      ),
      ...certificateField(
        "Expires on date",
        formatCertificateDate(x509certificate.notAfter),
      ),
    ];
  }

  List<Widget> _buildPublicKeySection(X509Certificate x509certificate) {
    var publicKey = x509certificate.publicKey;

    return <Widget>[
      ...certificateSectionHeader("PUBLIC KEY"),
      ...certificateField(
        "Algorithm",
        certificateOidLabel(publicKey?.algOid),
      ),
      ...certificateField(
        "Parameters",
        certificateOidLabel(publicKey?.algParams),
      ),
    ];
  }

  List<Widget> _buildFingerprintSection(X509Certificate x509certificate) {
    return <Widget>[
      ...certificateSectionHeader("FINGERPRINT"),
      ...certificateFingerprintField(
        "Fingerprint SHA-256",
        x509certificate.encoded == null
            ? null
            : sha256.bind(Stream.value(x509certificate.encoded!)).first,
      ),
      ...certificateFingerprintField(
        "Fingerprint SHA-1",
        x509certificate.encoded == null
            ? null
            : sha1.bind(Stream.value(x509certificate.encoded!)).first,
      ),
    ];
  }
}
