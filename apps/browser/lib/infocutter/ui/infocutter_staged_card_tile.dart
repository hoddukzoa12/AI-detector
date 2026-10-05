import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/selection_session.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_session_colors.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

class InfocutterStagedCardTile extends StatefulWidget {
  const InfocutterStagedCardTile({
    required this.index,
    required this.card,
    required this.onRemove,
    required this.onRefine,
    required this.onRename,
    this.onSetDepth,
    super.key,
  });

  final int index;
  final SelectionCard card;
  final VoidCallback onRemove;
  final void Function(String selector) onRefine;
  final void Function(String name) onRename;
  final void Function(int index)? onSetDepth;

  @override
  State<InfocutterStagedCardTile> createState() =>
      _InfocutterStagedCardTileState();
}

class _InfocutterStagedCardTileState extends State<InfocutterStagedCardTile> {
  late final TextEditingController _nameController;
  late final TextEditingController _selectorController;
  late final FocusNode _nameFocus;
  late final FocusNode _selectorFocus;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.card.name);
    _selectorController = TextEditingController(text: widget.card.selector);
    _nameFocus = FocusNode()..addListener(_commitNameOnBlur);
    _selectorFocus = FocusNode()..addListener(_commitSelectorOnBlur);
  }

  // Commit edits when a field loses focus (e.g. the user types a selector then
  // taps "전체 적용") so the staged card always reflects what's on screen.
  void _commitNameOnBlur() {
    if (!_nameFocus.hasFocus) widget.onRename(_nameController.text);
  }

  void _commitSelectorOnBlur() {
    if (_selectorFocus.hasFocus) return;
    final text = _selectorController.text.trim();
    if (text.isNotEmpty && text != widget.card.selector) {
      widget.onRefine(text);
    }
  }

  @override
  void didUpdateWidget(covariant InfocutterStagedCardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync the fields when the card changes from elsewhere (the "next selector"
    // swap, an AI refine), but never while the user is editing that field.
    if (widget.card.name != oldWidget.card.name &&
        !_nameFocus.hasFocus &&
        widget.card.name != _nameController.text) {
      _nameController.text = widget.card.name;
    }
    if (widget.card.selector != oldWidget.card.selector &&
        !_selectorFocus.hasFocus &&
        widget.card.selector != _selectorController.text) {
      _selectorController.text = widget.card.selector;
    }
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_commitNameOnBlur);
    _selectorFocus.removeListener(_commitSelectorOnBlur);
    _nameFocus.dispose();
    _selectorFocus.dispose();
    _nameController.dispose();
    _selectorController.dispose();
    super.dispose();
  }

  void _cycleSelector() {
    final alternatives = widget.card.alternatives;
    if (alternatives.length <= 1) return;
    final current = _selectorController.text.trim();
    final at = alternatives.indexOf(current);
    // Don't clobber a hand-edited selector that isn't one of the picker's
    // candidates — only cycle when we're currently on a known alternative.
    if (at < 0) return;
    final next = alternatives[(at + 1) % alternatives.length];
    if (next == current) return;
    widget.onRefine(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _numberBadge(),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _nameField(l10n),
                  const SizedBox(height: 6),
                  _selectorField(l10n),
                  const SizedBox(height: 4),
                  _metaRow(context, l10n),
                  if (widget.card.depthOptions.length > 1 &&
                      widget.onSetDepth != null)
                    _depthControl(context, l10n),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.infocutterDelete,
              visualDensity: VisualDensity.compact,
              onPressed: widget.onRemove,
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberBadge() {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: infocutterSessionColor(widget.index),
        shape: BoxShape.circle,
      ),
      child: Text(
        '${widget.index + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _nameField(AppLocalizations l10n) {
    return TextField(
      controller: _nameController,
      focusNode: _nameFocus,
      decoration: InputDecoration(
        isDense: true,
        labelText: l10n.infocutterCardName,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      onSubmitted: widget.onRename,
    );
  }

  Widget _selectorField(AppLocalizations l10n) {
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
      onSubmitted: widget.onRefine,
    );
  }

  Widget _metaRow(BuildContext context, AppLocalizations l10n) {
    final matchCount = widget.card.matchCount;
    final tooBroad = isOverlyBroadSelector(widget.card.selector);
    final invalid = tooBroad || matchCount < 0;
    return Row(
      children: [
        Text(
          tooBroad
              ? l10n.infocutterTooBroadSelector
              : matchCount < 0
                  ? l10n.infocutterInvalidSelector
                  : l10n.infocutterMatchCount(matchCount),
          // Red for unknown/invalid (-1) or whole-page selectors; a valid
          // selector matching 0 elements is not an error.
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: invalid ? Theme.of(context).colorScheme.error : null,
              ),
        ),
        const Spacer(),
        if (widget.card.alternatives.length > 1)
          TextButton.icon(
            onPressed: _cycleSelector,
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: Text(l10n.infocutterNextSelector),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }

  Widget _depthControl(BuildContext context, AppLocalizations l10n) {
    final options = widget.card.depthOptions;
    final currentIndex = widget.card.depthIndex;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.infocutterTargetRange,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          _depthChips(options.length, currentIndex),
          const SizedBox(height: 2),
          _depthNudgeRow(l10n, options.length, currentIndex),
        ],
      ),
    );
  }

  Widget _depthChips(int optionCount, int currentIndex) {
    final options = widget.card.depthOptions;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (var i = 0; i < optionCount; i++)
          ChoiceChip(
            label: Text(options[i].label),
            selected: i == currentIndex,
            onSelected: (_) => widget.onSetDepth!(i),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _depthNudgeRow(
    AppLocalizations l10n,
    int optionCount,
    int currentIndex,
  ) {
    return Row(
      children: [
        TextButton.icon(
          icon: const Icon(Icons.unfold_less, size: 16),
          label: Text(l10n.infocutterNarrowTarget),
          onPressed: currentIndex > 0
              ? () => widget.onSetDepth!(currentIndex - 1)
              : null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
          ),
        ),
        TextButton.icon(
          icon: const Icon(Icons.unfold_more, size: 16),
          label: Text(l10n.infocutterWidenTarget),
          onPressed: currentIndex < optionCount - 1
              ? () => widget.onSetDepth!(currentIndex + 1)
              : null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}
