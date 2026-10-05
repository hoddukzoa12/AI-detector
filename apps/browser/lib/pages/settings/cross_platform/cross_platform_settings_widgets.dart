import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../project_info_popup.dart';
import 'cross_platform_settings_context.dart';

Widget copyableInfoTile({
  required String title,
  required String value,
}) =>
    ListTile(
      title: Text(title),
      subtitle: Text(value),
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: value));
      },
    );

List<Widget> buildCrossPlatformSettingsSection4(
  CrossPlatformSettingsContext ctx,
) {
  return [
    ListTile(
      leading: Container(
        height: 35,
        width: 35,
        margin: const EdgeInsets.only(top: 6.0, left: 6.0),
        child: const CircleAvatar(
            backgroundImage: AssetImage("assets/icon/icon.png")),
      ),
      title: const Text("Flutter InAppWebView Project"),
      subtitle:
          const Text("https://github.com/pichillilorenzo/flutter_inappwebview"),
      trailing: const Icon(Icons.arrow_forward),
      onLongPress: () => _showProjectInfoPopup(ctx),
      onTap: () => _showProjectInfoPopup(ctx),
    ),
  ];
}

void _showProjectInfoPopup(CrossPlatformSettingsContext ctx) {
  showGeneralDialog(
    context: ctx.context,
    pageBuilder: (context, animation, secondaryAnimation) {
      return const ProjectInfoPopup();
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

Widget buildWebViewPackageInfo(CrossPlatformSettingsLoaders loaders) =>
    FutureBuilder(
      future: (loaders.currentWebViewPackageLoader ??
              InAppWebViewController.getCurrentWebViewPackage)
          .call(),
      builder: (context, snapshot) {
        String packageDescription = "";
        if (snapshot.hasData) {
          WebViewPackageInfo packageInfo = snapshot.data!;
          packageDescription =
              "${packageInfo.packageName ?? ""} - ${packageInfo.versionName ?? ""}";
        }
        return ListTile(
          title: const Text("WebView Package Info"),
          subtitle: Text(packageDescription),
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: packageDescription));
          },
        );
      },
    );
