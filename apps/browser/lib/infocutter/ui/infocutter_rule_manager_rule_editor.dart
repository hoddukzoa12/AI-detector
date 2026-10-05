import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_rule_manager_prompt.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_sidebar_widgets.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_stored_rule_actions.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

enum _RuleAction { editSelector, toggleMode, editFrameScope, delete }

class InfocutterRuleEditor extends StatelessWidget {
  const InfocutterRuleEditor({
    required this.actions,
    required this.profile,
    required this.rule,
    super.key,
  });

  final InfocutterStoredRuleActions actions;
  final RuleProfile profile;
  final StoredRule rule;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: actions.canPreviewRule ? () => actions.previewRule(rule) : null,
      leading: Icon(
        rule.mode == RuleMode.hide ? Icons.visibility_off : Icons.visibility,
      ),
      title: Text(
        rule.selector,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(_subtitle(context)),
      trailing: _buildTrailing(context),
    );
  }

  Widget _buildTrailing(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (actions.canPreviewRule)
          IconButton(
            tooltip: l10n.infocutterSelectedTarget,
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () => actions.previewRule(rule),
          ),
        PopupMenuButton<_RuleAction>(
          tooltip: l10n.infocutterRuleActions,
          onSelected: (action) => _handleAction(context, action),
          itemBuilder: _buildActionMenuItems,
        ),
      ],
    );
  }

  List<PopupMenuEntry<_RuleAction>> _buildActionMenuItems(
    BuildContext context,
  ) {
    final l10n = AppLocalizations.of(context);
    return [
      PopupMenuItem(
        value: _RuleAction.editSelector,
        child: Text(l10n.infocutterEditSelector),
      ),
      PopupMenuItem(
        value: _RuleAction.toggleMode,
        child: Text(l10n.infocutterToggleRuleMode),
      ),
      PopupMenuItem(
        value: _RuleAction.editFrameScope,
        child: Text(l10n.infocutterFrameScope),
      ),
      PopupMenuItem(
        value: _RuleAction.delete,
        child: Text(l10n.infocutterDelete),
      ),
    ];
  }

  String _subtitle(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mode = rule.mode == RuleMode.hide
        ? l10n.infocutterRuleModeHide
        : l10n.infocutterRuleModeUnhide;
    final frame = rule.frameScope == null
        ? l10n.infocutterMainFrame
        : '${l10n.infocutterFrameScope}: ${rule.frameScope}';
    return '$mode · $frame';
  }

  Future<void> _handleAction(BuildContext context, _RuleAction action) async {
    switch (action) {
      case _RuleAction.editSelector:
        return _editSelector(context);
      case _RuleAction.toggleMode:
        await actions.updateStoredRule(
          profileId: profile.id,
          targetRule: rule,
          mode: rule.mode == RuleMode.hide ? RuleMode.unhide : RuleMode.hide,
        );
        return;
      case _RuleAction.editFrameScope:
        return _editFrameScope(context);
      case _RuleAction.delete:
        if (!await showInfocutterDeleteConfirmation(context)) return;
        await actions.removeStoredRule(
          profileId: profile.id,
          targetRule: rule,
        );
        return;
    }
  }

  Future<void> _editSelector(BuildContext context) async {
    final selector = await promptInfocutterText(
      context,
      InfocutterPromptTextRequest(
        title: AppLocalizations.of(context).infocutterSelector,
        initialValue: rule.selector,
        maxLines: 3,
        requireNonEmpty: true,
      ),
    );
    if (selector == null) return;
    await actions.updateStoredRule(
      profileId: profile.id,
      targetRule: rule,
      selector: selector,
    );
  }

  Future<void> _editFrameScope(BuildContext context) async {
    final scope = await promptInfocutterText(
      context,
      InfocutterPromptTextRequest(
        title: AppLocalizations.of(context).infocutterFrameScope,
        initialValue: rule.frameScope ?? '',
        maxLines: 2,
      ),
    );
    if (scope == null) return;
    await actions.updateStoredRule(
      profileId: profile.id,
      targetRule: rule,
      frameScope: scope,
    );
  }
}
