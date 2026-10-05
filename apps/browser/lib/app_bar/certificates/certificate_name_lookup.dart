import 'dart:developer';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// certificates_info_popup 에서 갈라져 나온 X509 이름(DN) 조회 헬퍼들.
/// 동작은 원본과 동일하다.

String? findCertificateCountryName({
  required X509Certificate x509certificate,
  required bool isSubject,
}) {
  try {
    return (isSubject
            ? x509certificate.subject(dn: ASN1DistinguishedNames.COUNTRY_NAME)
            : x509certificate.issuer(
                dn: ASN1DistinguishedNames.COUNTRY_NAME)) ??
        x509certificate.block1
            ?.findOid(oid: OID.countryName)
            ?.parent
            ?.sub
            ?.last
            .value;
  } catch (e) {
    log(e.toString());
  }
  return null;
}

String? findCertificateStateOrProvinceName({
  required X509Certificate x509certificate,
  required bool isSubject,
}) {
  try {
    return (isSubject
            ? x509certificate.subject(
                dn: ASN1DistinguishedNames.STATE_OR_PROVINCE_NAME)
            : x509certificate.issuer(
                dn: ASN1DistinguishedNames.STATE_OR_PROVINCE_NAME)) ??
        x509certificate.block1
            ?.findOid(oid: OID.stateOrProvinceName)
            ?.parent
            ?.sub
            ?.last
            .value;
  } catch (e) {
    log(e.toString());
  }
  return null;
}

String? findCertificateCommonName({
  required X509Certificate x509certificate,
  required bool isSubject,
}) {
  try {
    return (isSubject
            ? x509certificate.subject(dn: ASN1DistinguishedNames.COMMON_NAME)
            : x509certificate.issuer(dn: ASN1DistinguishedNames.COMMON_NAME)) ??
        x509certificate.block1
            ?.findOid(oid: OID.commonName)
            ?.parent
            ?.sub
            ?.last
            .value;
  } catch (e) {
    log(e.toString());
  }
  return null;
}

String? findCertificateOrganizationName({
  required X509Certificate x509certificate,
  required bool isSubject,
}) {
  try {
    return (isSubject
            ? x509certificate.subject(
                dn: ASN1DistinguishedNames.ORGANIZATION_NAME)
            : x509certificate.issuer(
                dn: ASN1DistinguishedNames.ORGANIZATION_NAME)) ??
        x509certificate.block1
            ?.findOid(oid: OID.organizationName)
            ?.parent
            ?.sub
            ?.last
            .value;
  } catch (e) {
    log(e.toString());
  }
  return null;
}

String? findCertificateOrganizationUnitName({
  required X509Certificate x509certificate,
  required bool isSubject,
}) {
  try {
    return (isSubject
            ? x509certificate.subject(
                dn: ASN1DistinguishedNames.ORGANIZATIONAL_UNIT_NAME)
            : x509certificate.issuer(
                dn: ASN1DistinguishedNames.ORGANIZATIONAL_UNIT_NAME)) ??
        x509certificate.block1
            ?.findOid(oid: OID.organizationalUnitName)
            ?.parent
            ?.sub
            ?.last
            .value;
  } catch (e) {
    log(e.toString());
  }
  return null;
}
