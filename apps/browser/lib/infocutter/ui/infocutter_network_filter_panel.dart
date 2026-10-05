import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/network_filter_service.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_sidebar_widgets.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class InfocutterNetworkFilterPanel extends StatefulWidget {
  const InfocutterNetworkFilterPanel({
    required this.onNetworkFiltersChanged,
    this.showHeader = true,
    super.key,
  });

  final Future<void> Function() onNetworkFiltersChanged;
  final bool showHeader;

  @override
  State<InfocutterNetworkFilterPanel> createState() =>
      _InfocutterNetworkFilterPanelState();
}

class _InfocutterNetworkFilterPanelState
    extends State<InfocutterNetworkFilterPanel> {
  final TextEditingController _importController = TextEditingController();
  final TextEditingController _subscribeController = TextEditingController();
  NetworkFilterImportSummary? _lastImport;
  bool _subscribing = false;

  @override
  void initState() {
    super.initState();
    _importController.addListener(_handleImportTextChanged);
    _subscribeController.addListener(_handleImportTextChanged);
  }

  @override
  void dispose() {
    _importController.removeListener(_handleImportTextChanged);
    _subscribeController.removeListener(_handleImportTextChanged);
    _importController.dispose();
    _subscribeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final service = Provider.of<NetworkFilterService>(context);
    final children = [
      _buildGlobalToggle(service, l10n),
      _buildImportField(l10n),
      const SizedBox(height: 8),
      _buildImportButton(service, l10n),
      const SizedBox(height: 12),
      _buildSubscribeField(l10n),
      const SizedBox(height: 8),
      _buildSubscribeButton(service, l10n),
      ..._buildImportSummary(l10n),
      const Divider(),
      ..._buildRuleList(service, l10n),
    ];

    if (!widget.showHeader) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: children,
      );
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.filter_alt_outlined),
      title: Text(l10n.infocutterNetworkFilters),
      subtitle: Text(l10n.infocutterSavedRules(service.rules.length)),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      children: children,
    );
  }

  Widget _buildGlobalToggle(
    NetworkFilterService service,
    AppLocalizations l10n,
  ) =>
      InfocutterZeroPaddingSwitchTile(
        title: l10n.infocutterNetworkFilterGlobalEnabled,
        value: service.globalEnabled,
        onChanged: (value) => _updateNetwork(
          () => service.setGlobalEnabled(value),
        ),
      );

  Widget _buildImportField(AppLocalizations l10n) =>
      InfocutterOutlinedTextField(
        controller: _importController,
        labelText: l10n.infocutterNetworkFilterPaste,
        maxLines: 5,
        minLines: 3,
      );

  Widget _buildImportButton(
    NetworkFilterService service,
    AppLocalizations l10n,
  ) =>
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _importController.text.trim().isEmpty
              ? null
              : () => _importRules(service),
          icon: const Icon(Icons.playlist_add),
          label: Text(l10n.infocutterNetworkFilterImport),
        ),
      );

  Widget _buildSubscribeField(AppLocalizations l10n) =>
      InfocutterOutlinedTextField(
        controller: _subscribeController,
        labelText: l10n.networkFilterSubscribeUrl,
      );

  Widget _buildSubscribeButton(
    NetworkFilterService service,
    AppLocalizations l10n,
  ) =>
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.tonalIcon(
          onPressed: _subscribing || _subscribeController.text.trim().isEmpty
              ? null
              : () => _subscribeRules(service),
          icon: _subscribing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_download_outlined),
          label: Text(l10n.networkFilterSubscribeAction),
        ),
      );

  List<Widget> _buildImportSummary(AppLocalizations l10n) {
    final summary = _lastImport;
    if (summary == null) return const [];

    return [
      ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: const Icon(Icons.info_outline),
        title: Text(
          l10n.infocutterNetworkFilterImportResult(
            summary.imported,
            summary.skipped,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildRuleList(
    NetworkFilterService service,
    AppLocalizations l10n,
  ) {
    if (service.rules.isEmpty) {
      return [
        InfocutterEmptyTile(
          icon: Icons.filter_alt_outlined,
          label: l10n.infocutterNoItemsYet,
        ),
      ];
    }

    return service.rules
        .map(
          (rule) => _RuleTile(
            ruleId: rule.id,
            onNetworkFiltersChanged: widget.onNetworkFiltersChanged,
          ),
        )
        .toList();
  }

  Future<void> _importRules(NetworkFilterService service) async {
    final raw = _importController.text.trim();
    if (raw.isEmpty) return;
    final result = await service.importRawList(raw);
    setState(() {
      _lastImport = result;
      _importController.clear();
    });
    await widget.onNetworkFiltersChanged();
  }

  Future<void> _subscribeRules(NetworkFilterService service) async {
    final url = _subscribeController.text.trim();
    if (url.isEmpty) return;
    setState(() => _subscribing = true);
    try {
      final result = await service.importFromUrl(url);
      if (!mounted) return;
      setState(() {
        _lastImport = result;
        _subscribeController.clear();
      });
      await widget.onNetworkFiltersChanged();
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.networkFilterSubscribeFailed('$error'))),
      );
    } finally {
      if (mounted) {
        setState(() => _subscribing = false);
      }
    }
  }

  Future<void> _updateNetwork(Future<void> Function() update) async {
    await update();
    await widget.onNetworkFiltersChanged();
  }

  void _handleImportTextChanged() {
    setState(() {});
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.onNetworkFiltersChanged,
    required this.ruleId,
  });

  final Future<void> Function() onNetworkFiltersChanged;
  final String ruleId;

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<NetworkFilterService>(context);
    final l10n = AppLocalizations.of(context);
    final stored = service.rules.firstWhere((rule) => rule.id == ruleId);
    final rule = stored.rule;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () async {
        await service.setRuleEnabled(stored.id, !stored.enabled);
        await onNetworkFiltersChanged();
      },
      leading: Switch(
        value: stored.enabled,
        onChanged: (value) async {
          await service.setRuleEnabled(stored.id, value);
          await onNetworkFiltersChanged();
        },
      ),
      title: Text(rule.raw),
      subtitle: Text(
        rule.allow
            ? l10n.infocutterNetworkFilterAllowRule
            : l10n.infocutterNetworkFilterBlockRule,
      ),
      trailing: IconButton(
        tooltip: l10n.infocutterRemove,
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          if (!await showInfocutterDeleteConfirmation(context)) return;
          await service.removeRule(stored.id);
          await onNetworkFiltersChanged();
        },
      ),
    );
  }
}
