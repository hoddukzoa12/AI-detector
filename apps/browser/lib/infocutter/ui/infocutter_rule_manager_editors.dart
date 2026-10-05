import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_rule_manager_prompt.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_rule_manager_rule_editor.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_sidebar_widgets.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_stored_rule_actions.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

class InfocutterProfileEditor extends StatelessWidget {
  const InfocutterProfileEditor({
    required this.actions,
    required this.profile,
    this.hideCards = false,
    super.key,
  });

  final InfocutterStoredRuleActions actions;
  final RuleProfile profile;
  final bool hideCards;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cards = groupRulesByCard(profile.rules, profile.cards);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(profile.name),
      subtitle: Text(profile.matchers.join(', ')),
      leading: Switch(
        value: profile.enabled,
        onChanged: (value) => actions.setProfileEnabled(profile.id, value),
      ),
      childrenPadding: const EdgeInsets.only(left: 12, bottom: 12),
      children: [
        _buildProfileActions(context, l10n),
        if (hideCards)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.infocutterCardsManagedInPickTab),
            ),
          )
        else
          ..._buildCards(cards, l10n),
      ],
    );
  }

  Widget _buildProfileActions(
    BuildContext context,
    AppLocalizations l10n,
  ) =>
      _ActionRow(
        children: [
          IconButton(
            tooltip: l10n.infocutterRename,
            icon: const Icon(Icons.edit),
            onPressed: () => _renameProfile(context),
          ),
          IconButton(
            tooltip: l10n.infocutterEditMatchers,
            icon: const Icon(Icons.link),
            onPressed: () => _editMatchers(context),
          ),
          IconButton(
            tooltip: l10n.infocutterDelete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (!await showInfocutterDeleteConfirmation(context)) return;
              await actions.deleteProfile(profile.id);
            },
          ),
        ],
      );

  List<Widget> _buildCards(
    List<SavedCard> cards,
    AppLocalizations l10n,
  ) {
    if (cards.isEmpty) {
      return [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(l10n.infocutterNoItemsYet),
        ),
      ];
    }

    return cards
        .map(
          (card) => _CardEditor(
            actions: actions,
            profile: profile,
            card: card,
          ),
        )
        .toList();
  }

  Future<void> _renameProfile(BuildContext context) async {
    final name = await promptInfocutterText(
      context,
      InfocutterPromptTextRequest(
        title: AppLocalizations.of(context).infocutterProfileName,
        initialValue: profile.name,
        requireNonEmpty: true,
      ),
    );
    if (name == null) return;
    await actions.renameProfile(profile.id, name);
  }

  Future<void> _editMatchers(BuildContext context) async {
    final matchers = await promptInfocutterText(
      context,
      InfocutterPromptTextRequest(
        title: AppLocalizations.of(context).infocutterMatchers,
        initialValue: profile.matchers.join('\n'),
        maxLines: 4,
        requireNonEmpty: true,
      ),
    );
    if (matchers == null) return;
    await actions.setProfileMatchers(profile.id, matchers.split('\n'));
  }
}

class _CardEditor extends StatelessWidget {
  const _CardEditor({
    required this.actions,
    required this.profile,
    required this.card,
  });

  final InfocutterStoredRuleActions actions;
  final RuleProfile profile;
  final SavedCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(card.cardName),
      subtitle: Text(l10n.infocutterSavedRules(card.ruleCount)),
      leading: Switch(
        value: card.enabled,
        onChanged: (value) => actions.setCardEnabled(
          profileId: profile.id,
          cardId: card.cardId,
          enabled: value,
        ),
      ),
      childrenPadding: const EdgeInsets.only(left: 12),
      children: [
        _ActionRow(
          children: [
            IconButton(
              tooltip: l10n.infocutterRename,
              icon: const Icon(Icons.drive_file_rename_outline),
              onPressed: () => _renameCard(context),
            ),
            IconButton(
              tooltip: l10n.infocutterDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await showInfocutterDeleteConfirmation(context)) return;
                await actions.removeCard(
                  profileId: profile.id,
                  cardId: card.cardId,
                );
              },
            ),
          ],
        ),
        ...card.rules.map(
          (rule) => InfocutterRuleEditor(
            actions: actions,
            profile: profile,
            rule: rule,
          ),
        ),
      ],
    );
  }

  Future<void> _renameCard(BuildContext context) async {
    final name = await promptInfocutterText(
      context,
      InfocutterPromptTextRequest(
        title: AppLocalizations.of(context).infocutterCardName,
        initialValue: card.cardName,
        requireNonEmpty: true,
      ),
    );
    if (name == null) return;
    await actions.renameCard(
      profileId: profile.id,
      cardId: card.cardId,
      cardName: name,
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 4,
        children: children,
      ),
    );
  }
}
