import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/site_protection_bypass.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_rule_manager.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_sidebar_widgets.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class InfocutterSiteTab extends StatelessWidget {
  const InfocutterSiteTab({
    required this.url,
    required this.onRulesChanged,
    this.onPreviewRule,
    super.key,
  });

  final Uri url;
  final Future<void> Function() onRulesChanged;
  final Future<void> Function(StoredRule rule)? onPreviewRule;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repository = context.watch<BlockRuleRepository>();
    final bypass = context.watch<SiteProtectionBypass>();
    final siteState = repository.buildActiveSiteState(url);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SiteBypassSwitch(
          bypassed: bypass.isBypassed(url),
          l10n: l10n,
          onChanged: (value) async {
            await bypass.setBypassed(url, bypassed: value);
            await onRulesChanged();
          },
        ),
        if (bypass.isBypassed(url)) _SiteBypassHint(l10n: l10n),
        _ActiveProfileTile(
          bypassed: bypass.isBypassed(url),
          l10n: l10n,
          siteState: siteState,
        ),
        const Divider(),
        ..._metricTiles(l10n, siteState),
        const Divider(),
        InfocutterRuleManager(
          currentSiteOnly: true,
          onPreviewRule: onPreviewRule,
          onRulesChanged: onRulesChanged,
          repository: repository,
          url: url,
        ),
      ],
    );
  }

  List<Widget> _metricTiles(
    AppLocalizations l10n,
    ActiveSiteState siteState,
  ) =>
      [
        InfocutterMetricTile(
          icon: Icons.dashboard_outlined,
          label: l10n.infocutterSavedCards(siteState.cardCount),
        ),
        InfocutterMetricTile(
          icon: Icons.rule,
          label: l10n.infocutterSavedRules(siteState.selectorCount),
        ),
        InfocutterMetricTile(
          icon: Icons.visibility_off,
          label: l10n.infocutterEnabledRules(siteState.enabledSelectorCount),
        ),
      ];
}

class _SiteBypassSwitch extends StatelessWidget {
  const _SiteBypassSwitch({
    required this.bypassed,
    required this.l10n,
    required this.onChanged,
  });

  final bool bypassed;
  final AppLocalizations l10n;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.siteProtectionBypassTitle),
      subtitle: Text(l10n.siteProtectionBypassSubtitle),
      value: bypassed,
      onChanged: onChanged,
    );
  }
}

class _SiteBypassHint extends StatelessWidget {
  const _SiteBypassHint({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        l10n.siteProtectionBypassActiveHint,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
      ),
    );
  }
}

class _ActiveProfileTile extends StatelessWidget {
  const _ActiveProfileTile({
    required this.bypassed,
    required this.l10n,
    required this.siteState,
  });

  final bool bypassed;
  final AppLocalizations l10n;
  final ActiveSiteState siteState;

  @override
  Widget build(BuildContext context) {
    final profileName =
        siteState.activeProfileName ?? l10n.infocutterNoActiveProfile;
    final active =
        !bypassed && siteState.globalEnabled && siteState.profileEnabled;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.infocutterActiveProfile),
      subtitle: Text(profileName),
      trailing: Icon(
        active ? Icons.check_circle : Icons.pause_circle,
      ),
    );
  }
}
