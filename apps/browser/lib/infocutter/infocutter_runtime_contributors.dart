import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/infocutter/text_block_service.dart';
import 'package:infocutter_app/infocutter/watch_service.dart';
import 'package:infocutter_app/infocutter/webview_integration.dart';
import 'package:provider/provider.dart';

typedef InfocutterRuntimeContributorApply = Future<void> Function(
  BuildContext context,
  InAppWebViewController controller,
  Uri? url,
);

class InfocutterRuntimeContributor {
  const InfocutterRuntimeContributor({
    required this.key,
    required this.apply,
  });

  final String key;
  final InfocutterRuntimeContributorApply apply;
}

const List<InfocutterRuntimeContributor> infocutterRuntimeContributors = [
  InfocutterRuntimeContributor(
    key: 'block',
    apply: _applyBlockRuntime,
  ),
  InfocutterRuntimeContributor(
    key: 'textBlocks',
    apply: _applyTextBlockRuntime,
  ),
  InfocutterRuntimeContributor(
    key: 'watch',
    apply: _applyWatchRuntime,
  ),
];

Future<void> _applyBlockRuntime(
  BuildContext context,
  InAppWebViewController controller,
  Uri? url,
) {
  return applyInfocutterRuntimeForUrl(
    controller,
    context.read<InfocutterService>(),
    url,
  );
}

Future<void> _applyTextBlockRuntime(
  BuildContext context,
  InAppWebViewController controller,
  Uri? url,
) {
  return applyInfocutterTextBlockRuntimeForUrl(
    controller,
    context.read<TextBlockService>(),
    url,
  );
}

Future<void> _applyWatchRuntime(
  BuildContext context,
  InAppWebViewController controller,
  Uri? url,
) {
  return applyInfocutterWatchRuntime(
    controller,
    context.read<WatchService>(),
  );
}
