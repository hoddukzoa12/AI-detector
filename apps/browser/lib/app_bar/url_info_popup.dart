import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:infocutter_app/app_bar/certificates_info_popup.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:provider/provider.dart';

import '../custom_popup_dialog.dart';

class UrlInfoPopup extends StatefulWidget {
  final CustomPopupDialogPageRoute route;
  final Duration transitionDuration;
  final Function()? onWebViewTabSettingsClicked;

  const UrlInfoPopup(
      {required this.route,
      required this.transitionDuration,
      super.key,
      this.onWebViewTabSettingsClicked});

  @override
  State<UrlInfoPopup> createState() => _UrlInfoPopupState();
}

class _UrlInfoPopupState extends State<UrlInfoPopup> {
  var showFullInfoUrl = false;
  var defaultTextSpanStyle = const TextStyle(
    color: Colors.black54,
    fontSize: 12.5,
  );

  @override
  Widget build(BuildContext context) {
    final webViewModel = Provider.of<WebViewModel>(context);
    final connectionInfo = _connectionInfo(webViewModel.isSecure);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildUrlText(webViewModel),
          _buildConnectionTitle(connectionInfo.title),
          _buildConnectionDescription(context, connectionInfo.description),
          const SizedBox(height: 30.0),
          _buildSettingsButton(context),
        ],
      ),
    );
  }

  ({String title, String description}) _connectionInfo(bool isSecure) {
    if (isSecure) {
      return (
        title: "Your connection is protected",
        description:
            "Your sensitive data (e.g. passwords or credit card numbers) remains private when it is sent to this site.",
      );
    }

    return (
      title: "Your connection to this website is not protected",
      description:
          "You should not enter sensitive data on this site (e.g. passwords or credit cards) because they could be intercepted by malicious users.",
    );
  }

  Widget _buildUrlText(WebViewModel webViewModel) {
    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTap: () {
            setState(() {
              showFullInfoUrl = !showFullInfoUrl;
            });
          },
          child: Container(
            padding: const EdgeInsets.only(bottom: 15.0),
            constraints: const BoxConstraints(maxHeight: 100.0),
            child: RichText(
              maxLines: showFullInfoUrl ? null : 2,
              overflow:
                  showFullInfoUrl ? TextOverflow.clip : TextOverflow.ellipsis,
              text: TextSpan(children: _urlTextSpans(webViewModel)),
            ),
          ),
        );
      },
    );
  }

  List<TextSpan> _urlTextSpans(WebViewModel webViewModel) {
    final url = webViewModel.url;
    return [
      TextSpan(
        text: url?.scheme,
        style: defaultTextSpanStyle.copyWith(
          color: webViewModel.isSecure ? Colors.green : Colors.black54,
          fontWeight: FontWeight.bold,
        ),
      ),
      TextSpan(
        text: webViewModel.url?.toString() == "about:blank" ? ':' : '://',
        style: defaultTextSpanStyle,
      ),
      TextSpan(
        text: url?.host,
        style: defaultTextSpanStyle.copyWith(color: Colors.black),
      ),
      TextSpan(text: url?.path, style: defaultTextSpanStyle),
      TextSpan(text: url?.query, style: defaultTextSpanStyle),
    ];
  }

  Widget _buildConnectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16.0),
      ),
    );
  }

  Widget _buildConnectionDescription(BuildContext context, String description) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12.0, color: Colors.black87),
        children: [
          TextSpan(text: "$description "),
          TextSpan(
            text: "Details",
            style: const TextStyle(color: Colors.blue),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _showCertificateDetails(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsButton(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        onPressed: () => _openWebViewTabSettings(context),
        child: const Text("WebView Tab Settings"),
      ),
    );
  }

  Future<void> _showCertificateDetails(BuildContext context) async {
    Navigator.maybePop(context);
    await widget.route.popped;
    await Future.delayed(
      Duration(milliseconds: widget.transitionDuration.inMilliseconds - 200),
    );

    if (!context.mounted) {
      return;
    }
    showDialog(
      context: context,
      builder: (context) => const CertificateInfoPopup(),
    );
  }

  Future<void> _openWebViewTabSettings(BuildContext context) async {
    Navigator.maybePop(context);
    await widget.route.popped;
    Future.delayed(widget.transitionDuration, () {
      widget.onWebViewTabSettingsClicked?.call();
    });
  }
}
