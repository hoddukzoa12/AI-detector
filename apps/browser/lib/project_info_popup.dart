import 'package:flutter/material.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/util.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import 'animated_flutter_browser_logo.dart';
import 'models/window_model.dart';

class ProjectInfoPopup extends StatefulWidget {
  const ProjectInfoPopup({super.key});

  @override
  State<StatefulWidget> createState() => _ProjectInfoPopupState();
}

class _ProjectInfoPopupState extends State<ProjectInfoPopup> {
  @override
  Widget build(BuildContext context) {
    final children = _buildContentChildren(context);
    if (Util.isIOS() || Util.isMacOS()) {
      children.addAll(_buildAppleActions(context));
    }

    return Scaffold(
      body: Center(
        child: OrientationBuilder(
          builder: (context, orientation) {
            return Orientation.landscape == orientation
                ? _buildLandscape(children)
                : _buildPortrait(children);
          },
        ),
      ),
    );
  }

  List<Widget> _buildContentChildren(BuildContext context) => [
        RichText(
          text: const TextSpan(children: [
            TextSpan(
              text: "Do you like this project? Give a ",
              style: TextStyle(color: Colors.black),
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(
                Icons.star,
                size: 25,
                color: Colors.yellow,
              ),
            ),
            TextSpan(text: " to", style: TextStyle(color: Colors.black))
          ]),
        ),
        _buildGithubButton(
          context: context,
          repository: "pichillilorenzo/flutter_inappwebview",
        ),
        RichText(
          text: const TextSpan(children: [
            TextSpan(text: "and to", style: TextStyle(color: Colors.black)),
          ]),
        ),
        _buildGithubButton(
          context: context,
          repository: "dalsoop/infocutter",
        ),
        const SizedBox(
          height: 20.0,
        ),
        SizedBox(
          width: 250.0,
          child: RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(children: [
              TextSpan(
                text:
                    "Also, if you want, you can support these projects with a donation. Thanks!",
                style: TextStyle(color: Colors.black),
              ),
            ]),
          ),
        ),
      ];

  Widget _buildGithubButton({
    required BuildContext context,
    required String repository,
  }) {
    return ElevatedButton.icon(
      icon: const Icon(
        Icons.code,
        size: 40.0,
      ),
      style: ButtonStyle(
        backgroundColor:
            WidgetStateColor.resolveWith((states) => Colors.grey.shade300),
      ),
      label: RichText(
        text: TextSpan(children: [
          const TextSpan(
              text: "Github: ", style: TextStyle(color: Colors.black)),
          TextSpan(
              text: repository, style: const TextStyle(color: Colors.blue)),
        ]),
      ),
      onPressed: () => _openRepository(context, repository),
    );
  }

  void _openRepository(BuildContext context, String repository) {
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    windowModel.addTab(
      WebViewModel(url: WebUri("https://github.com/$repository")),
    );
    Navigator.pop(context);
  }

  List<Widget> _buildAppleActions(BuildContext context) => [
        const SizedBox(
          height: 20.0,
        ),
        ElevatedButton.icon(
          icon: const Icon(
            Icons.arrow_back_ios,
            size: 30.0,
          ),
          label: const Text(
            "Go Back",
            style: TextStyle(fontSize: 20.0),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ];

  Widget _buildLandscape(List<Widget> children) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AnimatedFlutterBrowserLogo(),
        const SizedBox(width: 80.0),
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: children,
        ),
      ],
    );
  }

  Widget _buildPortrait(List<Widget> children) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AnimatedFlutterBrowserLogo(),
        const SizedBox(height: 80.0),
        ...children,
      ],
    );
  }
}
