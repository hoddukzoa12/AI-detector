import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/webview_integration.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

class InfocutterSelectedTargetSummary extends StatelessWidget {
  const InfocutterSelectedTargetSummary({
    required this.result,
    required this.selectedSelector,
    required this.selectedCandidateIndex,
    required this.selectedDepthIndex,
    required this.canUseDepthTargets,
    required this.matchCount,
    super.key,
  });

  final PickerResult result;
  final String selectedSelector;
  final int selectedCandidateIndex;
  final int selectedDepthIndex;
  final bool canUseDepthTargets;
  final int? matchCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final depthTarget = _selectedDepthTarget();
    final candidate = _selectedCandidate();
    final title = _selectedTitle(depthTarget, candidate);
    final selector = _selectedSelectorText();
    final details = _details(
      context,
      depthTarget: depthTarget,
      candidate: candidate,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, l10n),
            const SizedBox(height: 10),
            Text(
              title.isNotEmpty ? title : selector,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ..._buildDetailChips(details),
            const SizedBox(height: 10),
            _buildSelectorText(context, selector),
          ],
        ),
      ),
    );
  }

  String _selectedTitle(
    PickerDepthTarget? depthTarget,
    PickerCandidate? candidate,
  ) =>
      depthTarget?.elementLabel ??
      candidate?.label ??
      _elementLabel(result.tag, result.id, result.classes);

  String _selectedSelectorText() =>
      selectedSelector.isNotEmpty ? selectedSelector : result.selector;

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) => Row(
        children: [
          Icon(
            Icons.ads_click,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.infocutterSelectedTarget,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Chip(label: Text(l10n.infocutterSelectedBadge)),
        ],
      );

  List<Widget> _buildDetailChips(List<String> details) {
    if (details.isEmpty) return const [];

    return [
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: details
            .map(
              (detail) => Chip(
                visualDensity: VisualDensity.compact,
                label: Text(detail),
              ),
            )
            .toList(),
      ),
    ];
  }

  Widget _buildSelectorText(BuildContext context, String selector) =>
      SelectableText(
        selector,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
      );

  PickerCandidate? _selectedCandidate() {
    if (result.candidates.isEmpty) return null;
    if (selectedCandidateIndex < 0 ||
        selectedCandidateIndex >= result.candidates.length) {
      return result.candidates.first;
    }
    return result.candidates[selectedCandidateIndex];
  }

  PickerDepthTarget? _selectedDepthTarget() {
    if (!canUseDepthTargets || result.depthTargets.isEmpty) return null;
    if (selectedDepthIndex < 0 ||
        selectedDepthIndex >= result.depthTargets.length) {
      return result.depthTargets.first;
    }
    return result.depthTargets[selectedDepthIndex];
  }

  List<String> _details(
    BuildContext context, {
    PickerDepthTarget? depthTarget,
    PickerCandidate? candidate,
  }) {
    final l10n = AppLocalizations.of(context);
    final count =
        matchCount ?? depthTarget?.matchCount ?? candidate?.matchCount;
    return <String?>[
      depthTarget?.label,
      candidate?.relationship,
      candidate?.kind ?? depthTarget?.tag.toLowerCase(),
      depthTarget?.qualityLabel ?? candidate?.qualityLabel,
      if (count != null) l10n.infocutterMatchCount(count),
    ].whereType<String>().where((part) => part.isNotEmpty).toList();
  }

  String _elementLabel(String tag, String? id, List<String> classes) {
    final normalizedTag = tag.toLowerCase();
    final idPart = id == null || id.isEmpty ? '' : '#$id';
    final classPart = classes.isEmpty ? '' : '.${classes.first}';
    return '$normalizedTag$idPart$classPart';
  }
}
