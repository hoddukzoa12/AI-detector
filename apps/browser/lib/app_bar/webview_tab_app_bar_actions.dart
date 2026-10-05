import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/window_model.dart';

/// webview_tab_app_bar 에서 갈라져 나온 탭·창 액션들.
/// 동작은 원본과 동일하다.

void shareCurrentWebViewTab(BuildContext context) {
  final windowModel = Provider.of<WindowModel>(context, listen: false);
  final webViewModel = windowModel.getCurrentWebViewModel();
  final url = webViewModel?.url;
  if (url == null) {
    return;
  }

  SharePlus.instance.share(
    ShareParams(text: url.toString(), subject: webViewModel?.title),
  );
}

void openNewBrowserWindow(BuildContext context) {
  final browserModel = Provider.of<BrowserModel>(context, listen: false);
  browserModel.openWindow(null);
}

void toggleShouldSaveWindow(BuildContext context) {
  final windowModel = Provider.of<WindowModel>(context, listen: false);
  windowModel.shouldSave = !windowModel.shouldSave;
}

Future<void> toggleWebViewTabDesktopMode(BuildContext context) async {
  final windowModel = Provider.of<WindowModel>(context, listen: false);
  final webViewModel = windowModel.getCurrentWebViewModel();
  final webViewController = webViewModel?.webViewController;
  if (webViewController == null) {
    return;
  }

  final currentWebViewModel = Provider.of<WebViewModel>(context, listen: false);

  webViewModel?.isDesktopMode = !webViewModel.isDesktopMode;
  currentWebViewModel.isDesktopMode = webViewModel?.isDesktopMode ?? false;

  final currentSettings = await webViewController.getSettings();
  if (currentSettings == null) {
    await webViewController.reload();
    return;
  }

  currentSettings.preferredContentMode = webViewModel?.isDesktopMode ?? false
      ? UserPreferredContentMode.DESKTOP
      : UserPreferredContentMode.RECOMMENDED;
  await webViewController.setSettings(settings: currentSettings);
  await webViewController.reload();
}

Future<void> takeWebViewTabScreenshotAndShow(BuildContext context) async {
  var webViewModel = Provider.of<WebViewModel>(context, listen: false);
  var screenshot = await webViewModel.webViewController?.takeScreenshot();
  if (screenshot == null) {
    return;
  }

  var dir = await getApplicationDocumentsDirectory();
  File file = File(
      "${dir.path}/screenshot_${DateTime.now().microsecondsSinceEpoch}.png");
  await file.writeAsBytes(screenshot);

  if (!context.mounted) {
    await file.delete();
    return;
  }
  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        content: Image.memory(screenshot),
        actions: <Widget>[
          ElevatedButton(
            child: Text(AppLocalizations.of(context).share),
            onPressed: () async {
              await SharePlus.instance.share(
                ShareParams(files: [XFile(file.path)]),
              );
            },
          )
        ],
      );
    },
  );

  file.delete();
}
