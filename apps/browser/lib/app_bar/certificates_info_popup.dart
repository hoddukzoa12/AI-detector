import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:infocutter_app/app_bar/certificates/certificate_info_view.dart';
import 'package:infocutter_app/app_bar/certificates/certificate_name_lookup.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/services/download_service.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class CertificateInfoPopup extends StatefulWidget {
  const CertificateInfoPopup({super.key});

  @override
  State<CertificateInfoPopup> createState() => _CertificateInfoPopupState();
}

class _CertificateInfoPopupState extends State<CertificateInfoPopup> {
  final List<X509Certificate> _otherCertificates = [];
  X509Certificate? _topMainCertificate;
  X509Certificate? _selectedCertificate;

  @override
  Widget build(BuildContext context) {
    return _build();
  }

  Widget _build() {
    if (_topMainCertificate != null) {
      return _buildCertificatesInfoAlertDialog();
    }

    final webViewModel = Provider.of<WebViewModel>(context);
    return FutureBuilder(
      future: webViewModel.webViewController?.getCertificate(),
      builder: (context, snapshot) => _buildCertificateSnapshot(snapshot),
    );
  }

  Widget _buildCertificateSnapshot(AsyncSnapshot<Object?> snapshot) {
    if (!snapshot.hasData || snapshot.connectionState != ConnectionState.done) {
      return Container();
    }

    final sslCertificate = snapshot.data as SslCertificate;
    _topMainCertificate = sslCertificate.x509Certificate;
    _selectedCertificate = _topMainCertificate!;

    return FutureBuilder(
      future: _getOtherCertificatesFromTopMain(
        _otherCertificates,
        _topMainCertificate!,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return _buildCertificatesInfoAlertDialog();
        }
        return _buildLoadingIndicator();
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(2.5)),
        ),
        padding: const EdgeInsets.all(25.0),
        width: 100.0,
        height: 100.0,
        child: const CircularProgressIndicator(strokeWidth: 4.0),
      ),
    );
  }

  Future<void> _getOtherCertificatesFromTopMain(
      List<X509Certificate> otherCertificates,
      X509Certificate x509certificate) async {
    var authorityInfoAccess = x509certificate.authorityInfoAccess;
    if (authorityInfoAccess != null && authorityInfoAccess.infoAccess != null) {
      for (var i = 0; i < authorityInfoAccess.infoAccess!.length; i++) {
        try {
          var caIssuerUrl = authorityInfoAccess
              .infoAccess![i].location; // [OID.caIssuers.toValue()];
          HttpClientRequest request =
              await HttpClient().getUrl(Uri.parse(caIssuerUrl));
          HttpClientResponse response = await request.close();
          var certData = Uint8List.fromList(await response.first);
          var cert = X509Certificate.fromData(data: certData);
          otherCertificates.add(cert);
          await _getOtherCertificatesFromTopMain(otherCertificates, cert);
        } catch (e) {
          log(e.toString());
        }
      }
    }

    var cRLDistributionPoints = x509certificate.cRLDistributionPoints;
    if (cRLDistributionPoints != null && cRLDistributionPoints.crls != null) {
      for (var i = 0; i < cRLDistributionPoints.crls!.length; i++) {
        var crlUrl = cRLDistributionPoints.crls![i];
        try {
          HttpClientRequest request =
              await HttpClient().getUrl(Uri.parse(crlUrl));
          HttpClientResponse response = await request.close();
          var certData = Uint8List.fromList(await response.first);
          var cert = X509Certificate.fromData(data: certData);
          otherCertificates.add(cert);
          await _getOtherCertificatesFromTopMain(otherCertificates, cert);
        } catch (e) {
          log(e.toString());
        }
      }
    }
  }

  AlertDialog _buildCertificatesInfoAlertDialog() {
    var webViewModel = Provider.of<WebViewModel>(context);
    var url = webViewModel.url;

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                decoration: const BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.all(Radius.circular(5.0)),
                ),
                padding: const EdgeInsets.all(5.0),
                child: const Icon(
                  Icons.lock,
                  color: Colors.white,
                  size: 20.0,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: _buildVerifiedSiteSummary(url?.host ?? ""),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildVerifiedSiteSummary(String host) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          host,
          style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15.0),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                "Infocutter has verified that ${_topMainCertificate?.issuer(dn: ASN1DistinguishedNames.COMMON_NAME)} has emitted the web site certificate.",
                softWrap: true,
                style: const TextStyle(fontSize: 12.0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15.0),
        _buildCertificateInfoLink(),
      ],
    );
  }

  Widget _buildCertificateInfoLink() {
    return RichText(
      text: TextSpan(
        text: "Certificate info",
        style: const TextStyle(color: Colors.blue, fontSize: 12.0),
        recognizer: TapGestureRecognizer()..onTap = _showCertificateViewer,
      ),
    );
  }

  void _showCertificateViewer() {
    showDialog(
      context: context,
      builder: _buildCertificateViewerDialog,
    );
  }

  AlertDialog _buildCertificateViewerDialog(BuildContext context) {
    return AlertDialog(
      content: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width / 2.5,
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            return _buildCertificateViewerContent(setState);
          },
        ),
      ),
    );
  }

  Widget _buildCertificateViewerContent(StateSetter setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          "Certificate Viewer",
          style: TextStyle(
            fontSize: 24.0,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15.0),
        DropdownButton<X509Certificate>(
          isExpanded: true,
          onChanged: (value) {
            setState(() {
              _selectedCertificate = value;
            });
          },
          value: _selectedCertificate,
          items: _certificateDropdownItems(),
        ),
        const SizedBox(height: 15.0),
        Flexible(
          child: SingleChildScrollView(
            child: CertificateInfoView(
              x509certificate: _selectedCertificate!,
              onUriTap: _onCertificateUriTap,
            ),
          ),
        ),
      ],
    );
  }

  List<DropdownMenuItem<X509Certificate>> _certificateDropdownItems() {
    return [_topMainCertificate!, ..._otherCertificates]
        .map((certificate) {
          final name = _certificateDisplayName(certificate);
          if (name.isEmpty) return null;
          return DropdownMenuItem<X509Certificate>(
            value: certificate,
            child: Text(name),
          );
        })
        .nonNulls
        .toList();
  }

  String _certificateDisplayName(X509Certificate certificate) {
    return findCertificateCommonName(
          x509certificate: certificate,
          isSubject: true,
        ) ??
        findCertificateOrganizationName(
          x509certificate: certificate,
          isSubject: true,
        ) ??
        "";
  }

  Future<void> _onCertificateUriTap(String url, bool fallbackToLaunch) {
    return _downloadCertificateUri(url, fallbackToLaunch: fallbackToLaunch);
  }

  Future<void> _downloadCertificateUri(
    String url, {
    bool fallbackToLaunch = false,
  }) async {
    try {
      final downloadService = Provider.of<DownloadService>(
        context,
        listen: false,
      );
      await downloadService.enqueue(
        DownloadTaskRequest(
          url: url,
          destination: DownloadDestination.externalStorageDirectory,
        ),
      );
    } catch (e) {
      if (!fallbackToLaunch) {
        rethrow;
      }
      await _launchIfPossible(url);
    }
  }

  Future<void> _launchIfPossible(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) {
      return;
    }
    await launchUrl(uri);
  }
}
