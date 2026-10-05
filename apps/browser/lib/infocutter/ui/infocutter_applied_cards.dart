import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

/// The "이미 숨긴 것" section: applied block cards for the current site,
/// fully inline-editable. Pure presentational widget — takes data + callbacks
/// keyed by stable identity (cardId / rule createdAt) so the parent can
/// re-resolve fresh targets at commit time. Edits here apply to the page
/// immediately via the parent's onRulesChanged path (no reload).
class InfocutterAppliedCards extends StatelessWidget {
  const InfocutterAppliedCards({
    required this.cards,
    required this.onRenameCard,
    required this.onToggleCard,
    required this.onDeleteCard,
    required this.onEditRuleSelector,
    required this.onToggleRuleMode,
    required this.onDeleteRule,
    required this.onPreviewRule,
    super.key,
  });

  final List<SavedCard> cards;
  final void Function(String cardId, String name) onRenameCard;
  final void Function(String cardId, bool enabled) onToggleCard;
  final void Function(String cardId) onDeleteCard;
  final void Function(String cardId, DateTime createdAt, String selector)
      onEditRuleSelector;
  final void Function(String cardId, DateTime createdAt) onToggleRuleMode;
  final void Function(String cardId, DateTime createdAt) onDeleteRule;
  final void Function(StoredRule rule) onPreviewRule;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final card in cards)
          _AppliedCardTile(
            key: ValueKey('applied-${card.cardId}'),
            card: card,
            onRename: (name) => onRenameCard(card.cardId, name),
            onToggle: (enabled) => onToggleCard(card.cardId, enabled),
            onDelete: () => onDeleteCard(card.cardId),
            onEditSelector: (createdAt, selector) =>
                onEditRuleSelector(card.cardId, createdAt, selector),
            onToggleMode: (createdAt) =>
                onToggleRuleMode(card.cardId, createdAt),
            onDeleteRule: (createdAt) => onDeleteRule(card.cardId, createdAt),
            onPreview: onPreviewRule,
          ),
      ],
    );
  }
}

class _AppliedCardTile extends StatefulWidget {
  const _AppliedCardTile({
    required this.card,
    required this.onRename,
    required this.onToggle,
    required this.onDelete,
    required this.onEditSelector,
    required this.onToggleMode,
    required this.onDeleteRule,
    required this.onPreview,
    super.key,
  });

  final SavedCard card;
  final void Function(String name) onRename;
  final void Function(bool enabled) onToggle;
  final VoidCallback onDelete;
  final void Function(DateTime createdAt, String selector) onEditSelector;
  final void Function(DateTime createdAt) onToggleMode;
  final void Function(DateTime createdAt) onDeleteRule;
  final void Function(StoredRule rule) onPreview;

  @override
  State<_AppliedCardTile> createState() => _AppliedCardTileState();
}

class _AppliedCardTileState extends State<_AppliedCardTile> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocus;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.card.cardName);
    _nameFocus = FocusNode()..addListener(_commitNameOnBlur);
  }

  void _commitNameOnBlur() {
    if (_nameFocus.hasFocus) return;
    _commit(_nameController.text);
  }

  void _commit(String raw) {
    final text = raw.trim();
    if (text.isNotEmpty && text != widget.card.cardName) widget.onRename(text);
  }

  @override
  void didUpdateWidget(covariant _AppliedCardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.card.cardName != oldWidget.card.cardName &&
        !_nameFocus.hasFocus &&
        widget.card.cardName != _nameController.text) {
      _nameController.text = widget.card.cardName;
    }
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_commitNameOnBlur);
    _nameFocus.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Widget _buildNameField(AppLocalizations l10n) {
    return TextField(
      controller: _nameController,
      focusNode: _nameFocus,
      decoration: InputDecoration(
        isDense: true,
        labelText: l10n.infocutterCardName,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      onSubmitted: _commit,
    );
  }

  Widget _buildHeaderRow(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        Icon(
          widget.card.enabled ? Icons.block : Icons.block_outlined,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildNameField(l10n)),
        Switch(
          value: widget.card.enabled,
          onChanged: widget.onToggle,
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.infocutterDelete,
          visualDensity: VisualDensity.compact,
          onPressed: widget.onDelete,
        ),
      ],
    );
  }

  Widget _buildRuleRow(StoredRule rule) {
    return _AppliedRuleRow(
      key: ValueKey(
        'rule-${rule.cardId}-${rule.createdAt.microsecondsSinceEpoch}',
      ),
      rule: rule,
      onEditSelector: (selector) =>
          widget.onEditSelector(rule.createdAt, selector),
      onToggleMode: () => widget.onToggleMode(rule.createdAt),
      onDelete: widget.card.rules.length > 1
          ? () => widget.onDeleteRule(rule.createdAt)
          : null,
      onPreview: () => widget.onPreview(rule),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderRow(context, l10n),
            for (final rule in widget.card.rules) _buildRuleRow(rule),
          ],
        ),
      ),
    );
  }
}

class _AppliedRuleRow extends StatefulWidget {
  const _AppliedRuleRow({
    required this.rule,
    required this.onEditSelector,
    required this.onToggleMode,
    required this.onPreview,
    this.onDelete,
    super.key,
  });

  final StoredRule rule;
  final void Function(String selector) onEditSelector;
  final VoidCallback onToggleMode;
  final VoidCallback onPreview;
  final VoidCallback? onDelete;

  @override
  State<_AppliedRuleRow> createState() => _AppliedRuleRowState();
}

class _AppliedRuleRowState extends State<_AppliedRuleRow> {
  late final TextEditingController _selectorController;
  late final FocusNode _selectorFocus;

  @override
  void initState() {
    super.initState();
    _selectorController = TextEditingController(text: widget.rule.selector);
    _selectorFocus = FocusNode()..addListener(_commitSelectorOnBlur);
  }

  void _commitSelectorOnBlur() {
    if (_selectorFocus.hasFocus) return;
    _commit(_selectorController.text);
  }

  void _commit(String raw) {
    final text = raw.trim();
    if (text.isNotEmpty && text != widget.rule.selector) {
      widget.onEditSelector(text);
    }
  }

  @override
  void didUpdateWidget(covariant _AppliedRuleRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rule.selector != oldWidget.rule.selector &&
        !_selectorFocus.hasFocus &&
        widget.rule.selector != _selectorController.text) {
      _selectorController.text = widget.rule.selector;
    }
  }

  @override
  void dispose() {
    _selectorFocus.removeListener(_commitSelectorOnBlur);
    _selectorFocus.dispose();
    _selectorController.dispose();
    super.dispose();
  }

  Widget _buildSelectorField(AppLocalizations l10n) {
    return TextField(
      controller: _selectorController,
      focusNode: _selectorFocus,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        labelText: l10n.infocutterSelector,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      onSubmitted: _commit,
    );
  }

  Widget _buildActionRow(AppLocalizations l10n) {
    final isHide = widget.rule.mode == RuleMode.hide;
    return Row(
      children: [
        Expanded(child: _buildSelectorField(l10n)),
        IconButton(
          icon: Icon(isHide ? Icons.visibility_off : Icons.visibility),
          tooltip: isHide
              ? l10n.infocutterRuleModeHide
              : l10n.infocutterRuleModeUnhide,
          visualDensity: VisualDensity.compact,
          onPressed: widget.onToggleMode,
        ),
        IconButton(
          icon: const Icon(Icons.center_focus_strong),
          tooltip: l10n.infocutterSelectedTarget,
          visualDensity: VisualDensity.compact,
          onPressed: widget.onPreview,
        ),
        if (widget.onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.infocutterDeleteRule,
            visualDensity: VisualDensity.compact,
            onPressed: widget.onDelete,
          ),
      ],
    );
  }

  Widget _buildFrameLabel(BuildContext context, AppLocalizations l10n) {
    final frameLabel = widget.rule.frameScope == null
        ? l10n.infocutterMainFrame
        : '${l10n.infocutterFrameScope}: ${widget.rule.frameScope}';
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 2),
      child: Text(
        frameLabel,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionRow(l10n),
          _buildFrameLabel(context, l10n),
        ],
      ),
    );
  }
}
