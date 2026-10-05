import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infocutter_app/infocutter/webview_integration.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

export 'package:infocutter_app/infocutter/ui/infocutter_selected_target_summary.dart';

Future<bool> showInfocutterDeleteConfirmation(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.infocutterDelete),
          content: Text(l10n.infocutterConfirmDeleteMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.infocutterDelete),
            ),
          ],
        ),
      ) ??
      false;
}

class InfocutterSectionTitle extends StatelessWidget {
  final String title;

  const InfocutterSectionTitle({
    required this.title,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall,
    );
  }
}

class InfocutterMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;

  const InfocutterMetricTile({
    required this.icon,
    required this.label,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
    );
  }
}

class InfocutterEmptyTile extends StatelessWidget {
  const InfocutterEmptyTile({
    required this.icon,
    required this.label,
    super.key,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
    );
  }
}

class InfocutterOutlinedTextField extends StatelessWidget {
  const InfocutterOutlinedTextField({
    required this.controller,
    required this.labelText,
    this.helperText,
    this.inputFormatters,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.obscureText = false,
    this.textInputAction,
    super.key,
  });

  final TextEditingController controller;
  final String labelText;
  final String? helperText;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        helperText: helperText,
        labelText: labelText,
        border: const OutlineInputBorder(),
      ),
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      obscureText: obscureText,
      textInputAction: textInputAction,
    );
  }
}

class InfocutterZeroPaddingSwitchTile extends StatelessWidget {
  const InfocutterZeroPaddingSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

class InfocutterPlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;

  const InfocutterPlaceholderTab({
    required this.icon,
    required this.title,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(title),
          const SizedBox(height: 4),
          Text(l10n.infocutterNoItemsYet),
        ],
      ),
    );
  }
}

class InfocutterPointerCandidateTile extends StatelessWidget {
  final PickerCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  const InfocutterPointerCandidateTile({
    required this.candidate,
    required this.selected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
        ),
      ),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      title: Text(candidate.label),
      subtitle: Text(
        <String>[
          candidate.relationship,
          candidate.kind,
          candidate.qualityLabel,
          '${candidate.matchCount}',
        ].where((part) => part.isNotEmpty).join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing:
          selected ? Chip(label: Text(l10n.infocutterSelectedBadge)) : null,
      onTap: onTap,
    );
  }
}

class InfocutterDepthTile extends StatelessWidget {
  final PickerDepthTarget target;
  final bool selected;
  final VoidCallback onTap;

  const InfocutterDepthTile({
    required this.target,
    required this.selected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
        ),
      ),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      title: Text('${target.label} · ${target.elementLabel}'),
      subtitle: Text(
        '${target.qualityLabel} · ${target.matchCount}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}

class InfocutterSelectorCandidateTile extends StatelessWidget {
  final String selector;
  final bool selected;
  final int? matchCount;
  final VoidCallback onTap;

  const InfocutterSelectorCandidateTile({
    required this.selector,
    required this.selected,
    required this.matchCount,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      title: Text(
        selector,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: matchCount == null ? null : Text('$matchCount'),
      onTap: onTap,
    );
  }
}
