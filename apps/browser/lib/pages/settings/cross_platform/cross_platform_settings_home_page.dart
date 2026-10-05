import 'package:flutter/material.dart';

import '../../../models/default_site_model.dart';
import 'cross_platform_settings_context.dart';

List<Widget> buildCrossPlatformSettingsSection2(
  CrossPlatformSettingsContext ctx,
) {
  return [
    ListTile(
      title: Text(ctx.l10n.homePage),
      subtitle: Text(_homePageSubtitle(ctx)),
      onTap: () {
        _showHomePageDialog(ctx);
      },
    ),
  ];
}

String _homePageSubtitle(CrossPlatformSettingsContext ctx) {
  if (!ctx.settings.homePageEnabled) return ctx.l10n.off;
  return ctx.settings.customUrlHomePage.isEmpty
      ? ctx.settings.defaultSite.url
      : ctx.settings.customUrlHomePage;
}

void _showHomePageDialog(CrossPlatformSettingsContext ctx) {
  ctx.customHomePageController.text = ctx.settings.customUrlHomePage;
  showDialog(
    context: ctx.context,
    builder: (context) {
      return AlertDialog(
        contentPadding: const EdgeInsets.all(0.0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _homePageSwitch(ctx),
            _homePageFields(ctx),
          ],
        ),
      );
    },
  );
}

Widget _homePageSwitch(CrossPlatformSettingsContext ctx) {
  return StatefulBuilder(
    builder: (context, setState) {
      return SwitchListTile(
        title: Text(ctx.settings.homePageEnabled ? ctx.l10n.on : ctx.l10n.off),
        value: ctx.settings.homePageEnabled,
        onChanged: (value) {
          setState(() {
            ctx.settings.homePageEnabled = value;
            ctx.updateSettings();
          });
        },
      );
    },
  );
}

Widget _homePageFields(CrossPlatformSettingsContext ctx) {
  return StatefulBuilder(builder: (context, setState) {
    return ListTile(
      enabled: ctx.settings.homePageEnabled,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _defaultSiteDropdown(ctx, setState),
          _customHomePageField(ctx),
        ],
      ),
    );
  });
}

Widget _defaultSiteDropdown(
  CrossPlatformSettingsContext ctx,
  StateSetter dialogSetState,
) {
  return DropdownButton<DefaultSiteModel>(
    isExpanded: true,
    hint: Text(ctx.l10n.defaultSite),
    onChanged: ctx.settings.homePageEnabled
        ? (value) {
            dialogSetState(() {
              if (value != null) {
                ctx.settings.defaultSite = value;
                ctx.updateSettings();
              }
            });
          }
        : null,
    value: ctx.settings.defaultSite,
    items: DefaultSites.map((site) {
      return DropdownMenuItem(value: site, child: Text(site.name));
    }).toList(),
  );
}

Widget _customHomePageField(CrossPlatformSettingsContext ctx) {
  return TextField(
    enabled: ctx.settings.homePageEnabled,
    onSubmitted: (value) {
      ctx.setStateWith(() {
        ctx.settings.customUrlHomePage = value;
        ctx.updateSettings();
        Navigator.pop(ctx.context);
      });
    },
    keyboardType: TextInputType.url,
    decoration: InputDecoration(hintText: ctx.l10n.customUrlHomePage),
    controller: ctx.customHomePageController,
  );
}
