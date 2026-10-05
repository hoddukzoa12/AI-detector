import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/selection_session.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_staged_card_tile.dart';

export 'package:infocutter_app/infocutter/ui/infocutter_session_colors.dart';
export 'package:infocutter_app/infocutter/ui/infocutter_staged_card_tile.dart';

/// Every staged card must match something and not blanket the whole page
/// before the session can be committed.
bool infocutterSessionCanApply(List<SelectionCard> session) => session.every(
      (c) => c.matchCount >= 0 && !isOverlyBroadSelector(c.selector),
    );

/// The multi-select block session view: the staged cards plus apply/cancel.
/// Clicking elements on the page stages cards (handled upstream); this renders
/// the live `infocutterSelectionSession` and lets the human rename/refine/remove
/// each card before committing them all at once.
class InfocutterSessionList extends StatelessWidget {
  const InfocutterSessionList({
    required this.session,
    required this.onRemove,
    required this.onRefine,
    required this.onRename,
    required this.onApply,
    required this.onCancel,
    this.onSetDepth,
    super.key,
  });

  final List<SelectionCard> session;
  final void Function(String id) onRemove;
  final void Function(String id, String selector) onRefine;
  final void Function(String id, String name) onRename;
  final VoidCallback onApply;
  final VoidCallback onCancel;
  final void Function(String id, int index)? onSetDepth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (session.isEmpty) return _emptyState(context, l10n);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.infocutterStagedCount(session.length),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        Expanded(child: _cardList()),
        const Divider(height: 1),
        _footer(context, l10n),
      ],
    );
  }

  Widget _emptyState(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.ads_click,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.infocutterSessionPickHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _cardList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: session.length,
      itemBuilder: (context, index) {
        final card = session[index];
        return InfocutterStagedCardTile(
          key: ValueKey(card.id),
          index: index,
          card: card,
          onRemove: () => onRemove(card.id),
          onRefine: (selector) => onRefine(card.id, selector),
          onRename: (name) => onRename(card.id, name),
          onSetDepth:
              onSetDepth == null ? null : (i) => onSetDepth!(card.id, i),
        );
      },
    );
  }

  bool get _canApply => infocutterSessionCanApply(session);

  Widget _footer(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_canApply)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.infocutterFixSelectorsToApply,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _canApply ? onApply : null,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.infocutterSessionApplyAll(session.length)),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onCancel,
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
