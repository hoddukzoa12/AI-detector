import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_rule_manager_editors.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_rule_manager_prompt.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_sidebar_widgets.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_stored_rule_actions.dart';
import 'package:infocutter_app/infocutter/url_matcher.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

class InfocutterRuleManager extends StatelessWidget {
  const InfocutterRuleManager({
    required this.repository,
    required this.url,
    this.currentSiteOnly = false,
    this.onPreviewRule,
    this.onRulesChanged,
    super.key,
  });

  final BlockRuleRepository repository;
  final Uri url;
  final bool currentSiteOnly;
  final Future<void> Function(StoredRule rule)? onPreviewRule;
  final Future<void> Function()? onRulesChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profiles = _profilesForView();
    // Only the current-site 「숨긴 목록」 view hides the active profile's cards
    // (they are edited in the 「고르기」 tab). The full/settings manager
    // (currentSiteOnly == false) keeps showing every card.
    final activeProfileId = currentSiteOnly
        ? repository.buildActiveSiteState(url).activeProfileId
        : null;
    final actions = InfocutterStoredRuleActions(
      onPreviewRule: onPreviewRule,
      repository: repository,
      onRulesChanged: onRulesChanged,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGlobalToggle(l10n, profiles.length, actions),
        const Divider(),
        _buildProfilesHeader(context, l10n, actions),
        ..._buildProfiles(profiles, l10n, actions, activeProfileId),
      ],
    );
  }

  Widget _buildGlobalToggle(
    AppLocalizations l10n,
    int profileCount,
    InfocutterStoredRuleActions actions,
  ) =>
      InfocutterZeroPaddingSwitchTile(
        title: l10n.infocutterGlobalEnabled,
        subtitle: l10n.infocutterProfilesCount(profileCount),
        value: repository.globalEnabled,
        onChanged: actions.setGlobalEnabled,
      );

  Widget _buildProfilesHeader(
    BuildContext context,
    AppLocalizations l10n,
    InfocutterStoredRuleActions actions,
  ) =>
      Row(
        children: [
          Expanded(
            child: Text(
              l10n.infocutterProfiles,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            tooltip: l10n.infocutterImportJson,
            icon: const Icon(Icons.upload_file),
            onPressed: () => _showImportDialog(context, actions),
          ),
          IconButton(
            tooltip: l10n.infocutterExportJson,
            icon: const Icon(Icons.download),
            onPressed: () => _copyExportJson(context),
          ),
          IconButton(
            tooltip: l10n.infocutterCreateProfile,
            icon: const Icon(Icons.add),
            onPressed: () => _createProfile(context, actions),
          ),
        ],
      );

  List<Widget> _buildProfiles(
    List<RuleProfile> profiles,
    AppLocalizations l10n,
    InfocutterStoredRuleActions actions,
    String? activeProfileId,
  ) {
    if (profiles.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(l10n.infocutterNoItemsYet),
        ),
      ];
    }

    return profiles
        .map(
          (profile) => InfocutterProfileEditor(
            actions: actions,
            profile: profile,
            hideCards: profile.id == activeProfileId,
          ),
        )
        .toList();
  }

  List<RuleProfile> _profilesForView() {
    if (!currentSiteOnly) return repository.profiles;
    return repository.profiles
        .where(
          (profile) =>
              profile.matchers.any((matcher) => matchesUrl(matcher, url)),
        )
        .toList();
  }

  Future<void> _createProfile(
    BuildContext context,
    InfocutterStoredRuleActions actions,
  ) async {
    final l10n = AppLocalizations.of(context);
    final name = await promptInfocutterText(
      context,
      InfocutterPromptTextRequest(
        title: l10n.infocutterProfileName,
        initialValue: url.host,
        requireNonEmpty: true,
      ),
    );
    if (name == null) return;
    await actions.createProfile(
      name: name,
      matchers: [hostnameMatcher(url)],
    );
  }

  Future<void> _copyExportJson(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: repository.exportChromeJson()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.infocutterExportCopied)),
    );
  }

  Future<void> _showImportDialog(
    BuildContext context,
    InfocutterStoredRuleActions actions,
  ) async {
    final l10n = AppLocalizations.of(context);
    final raw = await promptInfocutterText(
      context,
      InfocutterPromptTextRequest(
        title: l10n.infocutterImportJson,
        hintText: l10n.infocutterImportPasteHint,
        initialValue: '',
        maxLines: 8,
        requireNonEmpty: true,
        saveLabel: l10n.infocutterImportJson,
        supportingText: l10n.infocutterImportReplaceWarning,
      ),
    );
    if (raw == null || raw.trim().isEmpty) return;
    await actions.importChromeJson(raw);
  }
}
