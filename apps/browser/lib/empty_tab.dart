import 'dart:async';

import 'package:flutter/material.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/onboarding/onboarding_gate.dart';
import 'package:infocutter_app/services/browser_url_resolver.dart';
import 'package:provider/provider.dart';

import 'models/browser_model.dart';
import 'models/webview_model.dart';
import 'models/window_model.dart';

class EmptyTab extends StatefulWidget {
  const EmptyTab({super.key});

  @override
  State<EmptyTab> createState() => _EmptyTabState();
}

class _EmptyTabState extends State<EmptyTab> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The new-tab screen is the first thing a fresh install shows, so it is
    // where the one-time "how to hide things" card is introduced.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(showOnboardingIfNeeded(context));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final browserModel = Provider.of<BrowserModel>(context);
    final settings = browserModel.getSettings();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLogoLockup(context),
                  const SizedBox(height: 36),
                  _buildSearchPanel(context, l10n, settings),
                  const SizedBox(height: 18),
                  _buildQuickLinks(context, settings),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoLockup(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.16),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset('assets/icon/icon.png', fit: BoxFit.cover),
        ),
        const SizedBox(height: 18),
        Text(
          AppLocalizations.of(context).appTitle,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchPanel(
    BuildContext context,
    AppLocalizations l10n,
    BrowserSettings settings,
  ) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.22 : 0.08,
            ),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildSearchEngineBadge(settings),
          const SizedBox(width: 10),
          Expanded(child: _buildSearchField(l10n)),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: const Icon(Icons.arrow_forward),
            tooltip: l10n.searchOrTypeWebAddress,
            onPressed: () => _openNewTab(_controller.text),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchEngineBadge(BrowserSettings settings) {
    return Tooltip(
      message: settings.searchEngine.name,
      child: Container(
        width: 42,
        height: 42,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child:
            Image.asset(settings.searchEngine.assetIcon, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) => TextField(
        controller: _controller,
        onSubmitted: _openNewTab,
        textInputAction: TextInputAction.go,
        decoration: InputDecoration(
          hintText: l10n.searchOrTypeWebAddress,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        style: Theme.of(context).textTheme.titleLarge,
      );

  Widget _buildQuickLinks(BuildContext context, BrowserSettings settings) {
    final links = <_HomeQuickLink>[
      _HomeQuickLink(
        icon: Icons.home,
        label: settings.defaultSite.name,
        url: settings.defaultSite.url,
      ),
      if (settings.searchEngine.url != settings.defaultSite.url)
        _HomeQuickLink(
          icon: Icons.search,
          label: settings.searchEngine.name,
          url: settings.searchEngine.url,
        ),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final link in links)
          _QuickLinkButton(
            icon: link.icon,
            label: link.label,
            onPressed: () => _openNewTab(link.url),
          ),
      ],
    );
  }

  void _openNewTab(String value) {
    if (value.trim().isEmpty) return;
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    final browserModel = Provider.of<BrowserModel>(context, listen: false);
    final settings = browserModel.getSettings();
    final url = const BrowserUrlResolver().resolve(value, settings);

    windowModel.addTab(WebViewModel(url: url));
    FocusScope.of(context).unfocus();
  }
}

class _HomeQuickLink {
  const _HomeQuickLink({
    required this.icon,
    required this.label,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String url;
}

class _QuickLinkButton extends StatelessWidget {
  const _QuickLinkButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        side: BorderSide(color: theme.colorScheme.outline),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
