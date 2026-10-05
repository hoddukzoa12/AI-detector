import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infocutter_app/infocutter/infocutter_backup_contributors.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/network_filter_service.dart';
import 'package:infocutter_app/infocutter/text_block_service.dart';
import 'package:infocutter_app/infocutter/watch_service.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

/// Module management: flip each Infocutter feature on/off globally, and back
/// up / restore every module (block / keyword / watch / network) as one JSON
/// bundle. The AI API key is never part of any export.
class InfocutterModulesPanel extends StatelessWidget {
  const InfocutterModulesPanel({
    required this.onRulesChanged,
    required this.onReloadRules,
    super.key,
  });

  /// Re-applies the JS runtimes to the live page (no reload). Enough for the
  /// keyword/watch modules, which hide via JS and un-hide on the next apply.
  final Future<void> Function() onRulesChanged;

  /// Re-applies settings AND reloads. Required for block/network, whose hides
  /// come from WebKit content blockers that only update on navigation.
  final Future<void> Function() onReloadRules;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.infocutterModulesHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        ..._moduleToggles(context, l10n),
        const Divider(height: 24),
        _backupSection(context, l10n),
      ],
    );
  }

  List<Widget> _moduleToggles(BuildContext context, AppLocalizations l10n) {
    final block = context.watch<BlockRuleRepository>();
    final textBlocks = context.watch<TextBlockService>();
    final watch = context.watch<WatchService>();
    final network = context.watch<NetworkFilterService>();
    return [
      _moduleSwitch(
        icon: Icons.content_cut,
        title: l10n.infocutterPickBlockRemoveTab,
        value: block.globalEnabled,
        onChanged: (v) async {
          await block.setGlobalEnabled(v);
          // Block hides via content blockers → needs a reload to take effect.
          await onReloadRules();
        },
      ),
      _moduleSwitch(
        icon: Icons.text_fields,
        title: l10n.infocutterKeywordBlockRemoveTab,
        value: textBlocks.globalEnabled,
        onChanged: (v) async {
          await textBlocks.setGlobalEnabled(v);
          await onRulesChanged();
        },
      ),
      _moduleSwitch(
        icon: Icons.visibility,
        title: l10n.infocutterWatchAutoRemoveTab,
        value: watch.globalEnabled,
        onChanged: (v) async {
          await watch.setGlobalEnabled(v);
          await onRulesChanged();
        },
      ),
      _moduleSwitch(
        icon: Icons.block,
        title: l10n.infocutterNetworkRequestBlockTab,
        value: network.globalEnabled,
        onChanged: (v) async {
          await network.setGlobalEnabled(v);
          await onReloadRules();
        },
      ),
    ];
  }

  Widget _backupSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.infocutterBackupRestore,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.upload_outlined),
                label: Text(l10n.infocutterExportRules),
                onPressed: () => unawaited(_exportBundle(context, l10n)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.download_outlined),
                label: Text(l10n.infocutterImportRules),
                onPressed: () => unawaited(_importBundle(context, l10n)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _moduleSwitch({
    required IconData icon,
    required String title,
    required bool value,
    required Future<void> Function(bool) onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon),
      title: Text(title),
      value: value,
      onChanged: (v) => unawaited(onChanged(v)),
    );
  }

  // One JSON bundle for every module (block / keyword / watch / network +
  // their toggles). The AI config (API key) is intentionally never included.
  Future<void> _exportBundle(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final bundle = {
      'infocutterConfigVersion': 1,
      for (final contributor in infocutterBackupContributors)
        contributor.key: contributor.exportJson(context),
    };
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(bundle)),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.infocutterRulesExported)),
      );
    }
  }

  Future<void> _importBundle(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final raw = await _promptForJson(context, l10n);
    if (raw == null || raw.trim().isEmpty) return;
    if (!context.mounted) return;
    // Reject anything that isn't our bundle BEFORE touching any service, so a
    // stray paste can never silently wipe the stored rules.
    Map<String, Object?> map;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['infocutterConfigVersion'] == null) {
        throw const FormatException('not a config bundle');
      }
      map = Map<String, Object?>.from(decoded);
    } catch (_) {
      if (context.mounted) _showMessage(context, l10n.infocutterImportInvalid);
      return;
    }
    String message;
    try {
      for (final contributor in infocutterBackupContributors) {
        if (map.containsKey(contributor.key)) {
          if (!context.mounted) return;
          await contributor.importJson(context, map[contributor.key]);
        }
      }
      // A restore can touch content-blocker modules, so reload to apply.
      await onReloadRules();
      message = l10n.infocutterRulesImported;
    } catch (_) {
      message = l10n.infocutterImportInvalid;
    }
    if (context.mounted) _showMessage(context, message);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<String?> _promptForJson(BuildContext context, AppLocalizations l10n) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => const _ImportJsonDialog(),
    );
  }
}

/// Owns its [TextEditingController] in State so it's disposed only after the
/// dialog route is fully gone (disposing it via `whenComplete` races the exit
/// animation and throws "used after dispose").
class _ImportJsonDialog extends StatefulWidget {
  const _ImportJsonDialog();

  @override
  State<_ImportJsonDialog> createState() => _ImportJsonDialogState();
}

class _ImportJsonDialogState extends State<_ImportJsonDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.infocutterImportRules),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.infocutterImportReplaceWarning,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: l10n.infocutterImportPasteHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _controller.text),
          child: Text(l10n.infocutterImportRules),
        ),
      ],
    );
  }

  void _handleTextChanged() {
    setState(() {});
  }
}
