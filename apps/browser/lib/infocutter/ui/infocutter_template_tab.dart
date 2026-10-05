import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/template_catalog.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_sidebar_widgets.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class InfocutterTemplateTab extends StatelessWidget {
  const InfocutterTemplateTab({
    required this.onRulesChanged,
    super.key,
  });

  final Future<void> Function() onRulesChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfocutterSectionTitle(title: l10n.infocutterTemplates),
        const SizedBox(height: 8),
        ...bundledInfocutterTemplates.map(
          (template) => _buildTemplateCard(context, template, l10n),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(
    BuildContext context,
    InfocutterTemplate template,
    AppLocalizations l10n,
  ) =>
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                template.name,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(template.description),
              const SizedBox(height: 8),
              _buildTemplateChips(template, l10n),
              const SizedBox(height: 8),
              _buildImportButton(context, template, l10n),
            ],
          ),
        ),
      );

  Widget _buildTemplateChips(
    InfocutterTemplate template,
    AppLocalizations l10n,
  ) =>
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          Chip(
            label: Text(
              l10n.infocutterSavedCards(template.cards.length),
            ),
          ),
          Chip(label: Text(template.matchers.join(', '))),
        ],
      );

  Widget _buildImportButton(
    BuildContext context,
    InfocutterTemplate template,
    AppLocalizations l10n,
  ) =>
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: () => _importTemplate(context, template),
          icon: const Icon(Icons.download),
          label: Text(l10n.infocutterImportTemplate),
        ),
      );

  Future<void> _importTemplate(
    BuildContext context,
    InfocutterTemplate template,
  ) async {
    final l10n = AppLocalizations.of(context);
    final repository = context.read<BlockRuleRepository>();
    await repository.importTemplate(template);
    await onRulesChanged();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.infocutterTemplateImported(template.name))),
    );
  }
}
