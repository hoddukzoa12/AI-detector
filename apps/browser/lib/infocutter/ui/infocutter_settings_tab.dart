import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_sidebar_widgets.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class InfocutterSettingsTab extends StatelessWidget {
  const InfocutterSettingsTab({
    required this.onReloadRules,
    super.key,
  });

  /// Re-applies settings AND reloads — the global block toggle drives WebKit
  /// content blockers, which only take effect on navigation.
  final Future<void> Function() onReloadRules;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repository = context.watch<BlockRuleRepository>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfocutterSectionTitle(title: l10n.infocutterGlobalSettingsTab),
        const SizedBox(height: 8),
        InfocutterZeroPaddingSwitchTile(
          title: l10n.infocutterGlobalEnabled,
          value: repository.globalEnabled,
          onChanged: (value) async {
            await repository.setGlobalEnabled(value);
            await onReloadRules();
          },
        ),
      ],
    );
  }
}
