import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/app_bar/certificates/certificate_field_widgets.dart';

/// certificates_info_popup 에서 갈라져 나온 EXTENSIONS 섹션 렌더.
/// 동작은 원본과 동일하다.
///
/// [onUriTap] 은 원본 `_downloadCertificateUri(url, fallbackToLaunch: ...)` 와
/// 같은 호출을 그대로 위임받는다.
List<Widget> buildCertificateExtensionSection(
  X509Certificate x509certificate,
  Future<void> Function(String url, bool fallbackToLaunch) onUriTap,
) {
  var extensionSection = <Widget>[
    const SizedBox(
      height: 15.0,
    ),
    const Text(
      "EXTENSIONS",
      style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
    ),
  ];

  extensionSection.addAll(_buildKeyUsageSection(x509certificate));
  extensionSection.addAll(_buildBasicConstraints(x509certificate));
  extensionSection.addAll(_buildExtendedKeyUsage(x509certificate));
  extensionSection.addAll(_buildSubjectKeyIdentifier(x509certificate));
  extensionSection.addAll(_buildAuthorityKeyIdentifier(x509certificate));
  extensionSection.addAll(_buildCertificatePolicies(x509certificate));
  extensionSection
      .addAll(_buildCRLDistributionPoints(x509certificate, onUriTap));
  extensionSection.addAll(_buildAuthorityInfoAccess(x509certificate, onUriTap));
  extensionSection.addAll(_buildSubjectAlternativeNames(x509certificate));

  return extensionSection;
}

List<Widget> _buildKeyUsageSection(X509Certificate x509certificate) {
  var criticalExtensionOIDs = x509certificate.criticalExtensionOIDs;
  var keyUsage = x509certificate.keyUsage;

  var keyUsageSection = certificateExtensionHeader("Key Usage", OID.keyUsage);

  var keyUsageIsCritical =
      certificateCriticalValue(criticalExtensionOIDs, OID.keyUsage);

  if (keyUsage.isNotEmpty) {
    for (var i = 0; i < keyUsage.length; i++) {
      if (keyUsage[i]) {
        keyUsageSection.addAll(<Widget>[
          ...certificateCriticalField(keyUsageIsCritical),
          certificateExtensionField("Usage", KeyUsage.fromIndex(i)!.name()),
        ]);
      }
    }
  } else {
    keyUsageSection.addAll(certificateExtensionMissing());
  }

  return keyUsageSection;
}

List<Widget> _buildBasicConstraints(X509Certificate x509certificate) {
  var criticalExtensionOIDs = x509certificate.criticalExtensionOIDs;
  var basicConstraints = x509certificate.basicConstraints;

  var basicConstraintsSection =
      certificateExtensionHeader("Basic Constraints", OID.basicConstraints);
  var basicConstraintsIsCritical = certificateCriticalValue(
    criticalExtensionOIDs,
    OID.basicConstraints,
  );
  if (basicConstraints != null && basicConstraints.pathLenConstraint == -1) {
    basicConstraintsSection.addAll(<Widget>[
      ...certificateCriticalField(basicConstraintsIsCritical),
      certificateExtensionField("Certificate Authority", "NO"),
    ]);
  } else {
    basicConstraintsSection.addAll(<Widget>[
      ...certificateCriticalField(basicConstraintsIsCritical),
      certificateExtensionField("Certificate Authority", "YES"),
      certificateExtensionField(
          "Path Length Constraints", basicConstraints.toString()),
    ]);
  }

  return basicConstraintsSection;
}

List<Widget> _buildExtendedKeyUsage(X509Certificate x509certificate) {
  var criticalExtensionOIDs = x509certificate.criticalExtensionOIDs;
  var extendedKeyUsage = x509certificate.extendedKeyUsage;

  var extendedKeyUsageSection =
      certificateExtensionHeader("Extended Key Usage", OID.extKeyUsage);
  var extendedKeyUsageIsCritical = certificateCriticalValue(
    criticalExtensionOIDs,
    OID.extKeyUsage,
  );
  if (extendedKeyUsage.isNotEmpty) {
    for (var i = 0; i < extendedKeyUsage.length; i++) {
      OID oid = OID.fromValue(extendedKeyUsage[i])!;

      extendedKeyUsageSection.addAll(<Widget>[
        ...certificateCriticalField(extendedKeyUsageIsCritical),
        certificateExtensionField(
            "Purpose #${i + 1}", "${oid.name()} ( ${oid.toValue()} )"),
      ]);
    }
  } else {
    extendedKeyUsageSection.addAll(certificateExtensionMissing());
  }

  return extendedKeyUsageSection;
}

List<Widget> _buildSubjectKeyIdentifier(X509Certificate x509certificate) {
  var criticalExtensionOIDs = x509certificate.criticalExtensionOIDs;
  var subjectKeyIdentifier = x509certificate.subjectKeyIdentifier;

  var subjectKeyIdentifierSection = certificateExtensionHeader(
      "Subject Key Identifier", OID.subjectKeyIdentifier);
  var subjectKeyIdentifierIsCritical = certificateCriticalValue(
    criticalExtensionOIDs,
    OID.subjectKeyIdentifier,
  );
  if (subjectKeyIdentifier?.value != null &&
      subjectKeyIdentifier!.value!.isNotEmpty) {
    var subjectKeyIdentifierToHexValue =
        subjectKeyIdentifier.value!.map(certificateHexByte).toList().join(" ");

    subjectKeyIdentifierSection.addAll(<Widget>[
      ...certificateCriticalField(subjectKeyIdentifierIsCritical),
      certificateExtensionField("Key ID", subjectKeyIdentifierToHexValue),
    ]);
  } else {
    subjectKeyIdentifierSection.addAll(certificateExtensionMissing());
  }

  return subjectKeyIdentifierSection;
}

List<Widget> _buildAuthorityKeyIdentifier(X509Certificate x509certificate) {
  var criticalExtensionOIDs = x509certificate.criticalExtensionOIDs;
  var authorityKeyIdentifier = x509certificate.authorityKeyIdentifier;

  var authorityKeyIdentifierSection = certificateExtensionHeader(
      "Authority Key Identifier", OID.authorityKeyIdentifier);
  var authorityKeyIdentifierIsCritical = certificateCriticalValue(
    criticalExtensionOIDs,
    OID.authorityKeyIdentifier,
  );
  if (authorityKeyIdentifier?.keyIdentifier != null &&
      authorityKeyIdentifier!.keyIdentifier!.isNotEmpty) {
    var authorityKeyIdentifierToHexValue = authorityKeyIdentifier.keyIdentifier!
        .map(certificateHexByte)
        .toList()
        .join(" ");

    authorityKeyIdentifierSection.addAll(<Widget>[
      ...certificateCriticalField(authorityKeyIdentifierIsCritical),
      certificateExtensionField("Key ID", authorityKeyIdentifierToHexValue),
    ]);
  } else {
    authorityKeyIdentifierSection.addAll(certificateExtensionMissing());
  }

  return authorityKeyIdentifierSection;
}

List<Widget> _buildCertificatePolicies(X509Certificate x509certificate) {
  var criticalExtensionOIDs = x509certificate.criticalExtensionOIDs;
  var certificatePolicies = x509certificate.certificatePolicies;

  var certificatePoliciesSection = <Widget>[
    ...certificateExtensionHeader(
        "Certificate Policies", OID.certificatePolicies),
    ...certificateCriticalField(
      certificateCriticalValue(criticalExtensionOIDs, OID.certificatePolicies),
    ),
  ];

  if (certificatePolicies?.policies != null &&
      certificatePolicies!.policies!.isNotEmpty) {
    for (var i = 0; i < certificatePolicies.policies!.length; i++) {
      certificatePoliciesSection.addAll(<Widget>[
        certificateExtensionField(
          "ID policy num. ${i + 1}",
          certificateOidDisplay(certificatePolicies.policies![i].oid),
        ),
      ]);
    }
  } else {
    certificatePoliciesSection.addAll(certificateExtensionMissing());
  }

  return certificatePoliciesSection;
}

List<Widget> _buildCRLDistributionPoints(
  X509Certificate x509certificate,
  Future<void> Function(String url, bool fallbackToLaunch) onUriTap,
) {
  var criticalExtensionOIDs = x509certificate.criticalExtensionOIDs;
  var cRLDistributionPoints = x509certificate.cRLDistributionPoints;

  var cRLDistributionPointsSection = <Widget>[
    ...certificateExtensionHeader(
        "CRL Distribution Points", OID.cRLDistributionPoints),
    ...certificateCriticalField(
      certificateCriticalValue(
          criticalExtensionOIDs, OID.cRLDistributionPoints),
    ),
  ];

  if (cRLDistributionPoints?.crls != null &&
      cRLDistributionPoints!.crls!.isNotEmpty) {
    for (var i = 0; i < cRLDistributionPoints.crls!.length; i++) {
      final crl = cRLDistributionPoints.crls![i];
      cRLDistributionPointsSection.addAll(<Widget>[
        certificateLinkedExtensionField(
          "URI",
          crl,
          () => onUriTap(crl, true),
        ),
      ]);
    }
  } else {
    cRLDistributionPointsSection.addAll(certificateExtensionMissing());
  }

  return cRLDistributionPointsSection;
}

List<Widget> _buildAuthorityInfoAccess(
  X509Certificate x509certificate,
  Future<void> Function(String url, bool fallbackToLaunch) onUriTap,
) {
  var criticalExtensionOIDs = x509certificate.criticalExtensionOIDs;
  var authorityInfoAccess = x509certificate.authorityInfoAccess;

  var authorityInfoAccessSection = <Widget>[
    ...certificateExtensionHeader(
        "Authority Info Access", OID.authorityInfoAccess),
    ...certificateCriticalField(
      certificateCriticalValue(criticalExtensionOIDs, OID.authorityInfoAccess),
    ),
  ];

  if (authorityInfoAccess?.infoAccess != null &&
      authorityInfoAccess!.infoAccess!.isNotEmpty) {
    for (var i = 0; i < authorityInfoAccess.infoAccess!.length; i++) {
      var infoAccess = authorityInfoAccess.infoAccess![i];
      var value = infoAccess.location;

      authorityInfoAccessSection.addAll(<Widget>[
        certificateExtensionField(
          "Method #${i + 1}",
          certificateOidDisplay(infoAccess.method),
        ),
        certificateLinkedExtensionField(
          "URI",
          value,
          () => onUriTap(value, false),
        ),
      ]);
    }
  } else {
    authorityInfoAccessSection.addAll(certificateExtensionMissing());
  }

  return authorityInfoAccessSection;
}

List<Widget> _buildSubjectAlternativeNames(X509Certificate x509certificate) {
  var criticalExtensionOIDs = x509certificate.criticalExtensionOIDs;
  var subjectAlternativeNames = x509certificate.subjectAlternativeNames;

  var subjectAlternativeNamesSection = <Widget>[
    ...certificateExtensionHeader(
        "Subject Alternative Names", OID.subjectAltName),
  ];
  var subjectAlternativeNamesIsCritical = certificateCriticalValue(
    criticalExtensionOIDs,
    OID.subjectAltName,
  );
  if (subjectAlternativeNames.isNotEmpty) {
    subjectAlternativeNamesSection.addAll(<Widget>[
      ...certificateCriticalField(subjectAlternativeNamesIsCritical),
    ]);
    for (var subjectAlternativeName in subjectAlternativeNames) {
      subjectAlternativeNamesSection.addAll(<Widget>[
        const SizedBox(height: 5.0),
        certificateExtensionField("DNS Name", subjectAlternativeName),
      ]);
    }
  } else {
    subjectAlternativeNamesSection.addAll(certificateExtensionMissing());
  }

  return subjectAlternativeNamesSection;
}
