import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../models/browser_model.dart';
import '../../../models/default_site_model.dart';
import '../../../models/search_engine_model.dart';
import 'cross_platform_settings_context.dart';

List<Widget> buildCrossPlatformSettingsSection1(
  CrossPlatformSettingsContext ctx,
) {
  return [
    ListTile(
      title: Text(ctx.l10n.generalSettings),
      enabled: false,
    ),
    _themeModeTile(ctx),
    _searchEngineTile(ctx),
    _defaultSiteTile(ctx),
  ];
}

Widget _themeModeTile(CrossPlatformSettingsContext ctx) => ListTile(
      title: Text(ctx.l10n.themeMode),
      subtitle: Text(themeModeLabel(ctx.l10n, ctx.settings.themeMode)),
      trailing: DropdownButton<BrowserThemeMode>(
        value: ctx.settings.themeMode,
        onChanged: (value) => _setThemeMode(ctx, value),
        items: BrowserThemeMode.values.map((mode) {
          return DropdownMenuItem(
            value: mode,
            child: Text(themeModeLabel(ctx.l10n, mode)),
          );
        }).toList(),
      ),
    );

void _setThemeMode(CrossPlatformSettingsContext ctx, BrowserThemeMode? value) {
  if (value == null) return;
  ctx.setStateWith(() {
    ctx.settings.themeMode = value;
    ctx.updateSettings();
  });
}

String themeModeLabel(AppLocalizations l10n, BrowserThemeMode mode) {
  return switch (mode) {
    BrowserThemeMode.system => l10n.themeModeSystem,
    BrowserThemeMode.light => l10n.themeModeLight,
    BrowserThemeMode.dark => l10n.themeModeDark,
  };
}

Widget _searchEngineTile(CrossPlatformSettingsContext ctx) => ListTile(
      title: Text(ctx.l10n.searchEngine),
      subtitle: Text(ctx.settings.searchEngine.name),
      trailing: DropdownButton<SearchEngineModel>(
        hint: Text(ctx.l10n.searchEngine),
        onChanged: (value) => _setSearchEngine(ctx, value),
        value: ctx.settings.searchEngine,
        items: SearchEngines.map((searchEngine) {
          return DropdownMenuItem<SearchEngineModel>(
            value: searchEngine,
            child: Text(searchEngine.name),
          );
        }).toList(),
      ),
    );

void _setSearchEngine(
  CrossPlatformSettingsContext ctx,
  SearchEngineModel? value,
) {
  if (value == null) return;
  ctx.setStateWith(() {
    ctx.settings.searchEngine = value;
    ctx.updateSettings();
  });
}

Widget _defaultSiteTile(CrossPlatformSettingsContext ctx) => ListTile(
      title: Text(ctx.l10n.defaultSite),
      subtitle: Text(ctx.settings.defaultSite.name),
      trailing: DropdownButton<DefaultSiteModel>(
        hint: Text(ctx.l10n.defaultSite),
        onChanged: (value) => _setDefaultSite(ctx, value),
        value: ctx.settings.defaultSite,
        items: DefaultSites.map((site) {
          return DropdownMenuItem<DefaultSiteModel>(
            value: site,
            child: Text(site.name),
          );
        }).toList(),
      ),
    );

void _setDefaultSite(CrossPlatformSettingsContext ctx, DefaultSiteModel? value) {
  if (value == null) return;
  ctx.setStateWith(() {
    ctx.settings.defaultSite = value;
    ctx.updateSettings();
  });
}
