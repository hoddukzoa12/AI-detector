import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/applied_rule_lookup.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/selection_session.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_applied_cards.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_session_list.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_stored_rule_actions.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

/// The unified 「고르기」 tab: a collapsible "이미 숨긴 것" (applied rules, inline
/// editable) above "지금 고르는 중" (the staging session), with the apply/cancel
/// footer pinned. Applied edits go straight to the repository via the shared
/// InfocutterStoredRuleActions and reflect live (onRulesChanged, no reload).
class InfocutterPickTab extends StatefulWidget {
  const InfocutterPickTab({
    required this.url,
    required this.session,
    required this.onRemoveSessionCard,
    required this.onRefineSessionCard,
    required this.onRenameSessionCard,
    required this.onApplySession,
    required this.onCancelSession,
    required this.onRulesChanged,
    required this.onPreviewStoredRule,
    required this.onSetSessionCardDepth,
    super.key,
  });

  final Uri url;
  final List<SelectionCard> session;
  final void Function(String id) onRemoveSessionCard;
  final void Function(String id, String selector) onRefineSessionCard;
  final void Function(String id, String name) onRenameSessionCard;
  final VoidCallback onApplySession;
  final VoidCallback onCancelSession;
  final Future<void> Function() onRulesChanged;
  final Future<void> Function(StoredRule rule) onPreviewStoredRule;
  final void Function(String id, int index) onSetSessionCardDepth;

  @override
  State<InfocutterPickTab> createState() => _InfocutterPickTabState();
}

class _InfocutterPickTabState extends State<InfocutterPickTab> {
  bool? _appliedExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repository = context.watch<BlockRuleRepository>();
    final siteState = repository.buildActiveSiteState(widget.url);
    final actions = InfocutterStoredRuleActions(
      repository: repository,
      onRulesChanged: widget.onRulesChanged,
      onPreviewRule: widget.onPreviewStoredRule,
    );
    final width = MediaQuery.sizeOf(context).width;
    final expanded = _appliedExpanded ?? (width >= 620);

    final appliedBlock = _appliedBlock(
      context,
      l10n,
      siteState,
      actions,
      expanded: expanded,
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            children: [
              ...appliedBlock,
              _stagingHeader(context, l10n, widget.session.length),
              if (widget.session.isEmpty)
                _stagingEmptyHint(context, l10n)
              else
                for (var i = 0; i < widget.session.length; i++)
                  _stagedCardTile(i),
            ],
          ),
        ),
        if (widget.session.isNotEmpty) ...[
          const Divider(height: 1),
          _footer(context, l10n),
        ],
      ],
    );
  }

  /// The applied ("이미 숨긴 것") header/section/divider block. Built inside the
  /// non-null guard so profileId promotes to a plain String — no `!` assertions
  /// reach _appliedSection.
  List<Widget> _appliedBlock(
    BuildContext context,
    AppLocalizations l10n,
    ActiveSiteState siteState,
    InfocutterStoredRuleActions actions, {
    required bool expanded,
  }) {
    final profileId = siteState.activeProfileId;
    final cards = siteState.cards;
    if (profileId == null || cards.isEmpty) return const [];
    return [
      _appliedHeader(context, l10n, cards.length, expanded),
      if (expanded) _appliedSection(profileId, cards, actions),
      const Divider(height: 24),
    ];
  }

  Widget _stagedCardTile(int i) {
    final card = widget.session[i];
    return InfocutterStagedCardTile(
      key: ValueKey(card.id),
      index: i,
      card: card,
      onRemove: () => widget.onRemoveSessionCard(card.id),
      onRefine: (selector) => widget.onRefineSessionCard(card.id, selector),
      onRename: (name) => widget.onRenameSessionCard(card.id, name),
      onSetDepth: (index) => widget.onSetSessionCardDepth(card.id, index),
    );
  }

  Widget _appliedSection(
    String profileId,
    List<SavedCard> cards,
    InfocutterStoredRuleActions actions,
  ) =>
      InfocutterAppliedCards(
        cards: cards,
        onRenameCard: (cardId, name) => actions.renameCard(
            profileId: profileId, cardId: cardId, cardName: name),
        onToggleCard: (cardId, enabled) => actions.setCardEnabled(
            profileId: profileId, cardId: cardId, enabled: enabled),
        onDeleteCard: (cardId) =>
            actions.removeCard(profileId: profileId, cardId: cardId),
        onEditRuleSelector: (cardId, createdAt, selector) => _withFreshRule(
          cardId,
          createdAt,
          (rule) => actions.updateStoredRule(
              profileId: profileId, targetRule: rule, selector: selector),
        ),
        onToggleRuleMode: (cardId, createdAt) => _withFreshRule(
          cardId,
          createdAt,
          (rule) => actions.updateStoredRule(
            profileId: profileId,
            targetRule: rule,
            mode: rule.mode == RuleMode.hide ? RuleMode.unhide : RuleMode.hide,
          ),
        ),
        onDeleteRule: (cardId, createdAt) => _withFreshRule(
          cardId,
          createdAt,
          (rule) =>
              actions.removeStoredRule(profileId: profileId, targetRule: rule),
        ),
        onPreviewRule: (rule) => actions.previewRule(rule),
      );

  /// Re-resolve the freshest rule by identity (cardId + createdAt) from the
  /// current repository state and run [op] only if it is still present. Shared
  /// by selector-edit, mode-toggle, and delete-rule so a stale captured rule
  /// never desyncs the mutation target.
  void _withFreshRule(
    String cardId,
    DateTime createdAt,
    void Function(StoredRule rule) op,
  ) {
    final repository = context.read<BlockRuleRepository>();
    final rule = findRuleByIdentity(
        repository.buildActiveSiteState(widget.url).cards, cardId, createdAt);
    if (rule == null) return;
    op(rule);
  }

  Widget _appliedHeader(
    BuildContext context,
    AppLocalizations l10n,
    int count,
    bool expanded,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            // toggle the *effective* expanded (seeded from the responsive
            // default)
            onTap: () => setState(() => _appliedExpanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l10n.infocutterAlreadyHiddenSection(count),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                l10n.infocutterAppliedEditsLiveHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      );

  Widget _stagingHeader(
    BuildContext context,
    AppLocalizations l10n,
    int count,
  ) =>
      Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            l10n.infocutterPickingNowSection(count),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      );

  Widget _stagingEmptyHint(BuildContext context, AppLocalizations l10n) =>
      Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            l10n.infocutterSessionPickHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );

  Widget _footer(BuildContext context, AppLocalizations l10n) {
    final canApply = infocutterSessionCanApply(widget.session);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!canApply)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.infocutterFixSelectorsToApply,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: canApply ? widget.onApplySession : null,
                  icon: const Icon(Icons.check),
                  label: Text(
                      l10n.infocutterSessionApplyAll(widget.session.length)),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: widget.onCancelSession,
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
