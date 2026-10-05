import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/network_filter_service.dart';
import 'package:infocutter_app/infocutter/text_block_service.dart';
import 'package:infocutter_app/infocutter/watch_service.dart';
import 'package:provider/provider.dart';

typedef InfocutterBackupExporter = Object? Function(BuildContext context);

typedef InfocutterBackupImporter = Future<void> Function(
  BuildContext context,
  Object? raw,
);

class InfocutterBackupContributor {
  const InfocutterBackupContributor({
    required this.key,
    required this.exportJson,
    required this.importJson,
  });

  final String key;
  final InfocutterBackupExporter exportJson;
  final InfocutterBackupImporter importJson;
}

const List<InfocutterBackupContributor> infocutterBackupContributors = [
  InfocutterBackupContributor(
    key: 'block',
    exportJson: _exportBlockRules,
    importJson: _importBlockRules,
  ),
  InfocutterBackupContributor(
    key: 'textBlocks',
    exportJson: _exportTextBlocks,
    importJson: _importTextBlocks,
  ),
  InfocutterBackupContributor(
    key: 'watch',
    exportJson: _exportWatch,
    importJson: _importWatch,
  ),
  InfocutterBackupContributor(
    key: 'network',
    exportJson: _exportNetwork,
    importJson: _importNetwork,
  ),
];

Object? _exportBlockRules(BuildContext context) =>
    jsonDecode(context.read<BlockRuleRepository>().exportChromeJson());

Future<void> _importBlockRules(BuildContext context, Object? raw) {
  return context.read<BlockRuleRepository>().importChromeJson(jsonEncode(raw));
}

Object? _exportTextBlocks(BuildContext context) =>
    jsonDecode(context.read<TextBlockService>().exportJson());

Future<void> _importTextBlocks(BuildContext context, Object? raw) {
  return context.read<TextBlockService>().importJson(jsonEncode(raw));
}

Object? _exportWatch(BuildContext context) =>
    jsonDecode(context.read<WatchService>().exportJson());

Future<void> _importWatch(BuildContext context, Object? raw) {
  return context.read<WatchService>().importJson(jsonEncode(raw));
}

Object? _exportNetwork(BuildContext context) =>
    jsonDecode(context.read<NetworkFilterService>().exportJson());

Future<void> _importNetwork(BuildContext context, Object? raw) {
  return context.read<NetworkFilterService>().importJson(jsonEncode(raw));
}
