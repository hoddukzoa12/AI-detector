import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_sidebar_widgets.dart';
import 'package:infocutter_app/infocutter/watch_service.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class InfocutterWatchTab extends StatefulWidget {
  const InfocutterWatchTab({
    required this.onCaptureDetectionEvidence,
    required this.onWatchChanged,
    super.key,
  });

  final Future<void> Function(WatchDetection detection)
      onCaptureDetectionEvidence;
  final Future<void> Function() onWatchChanged;

  @override
  State<InfocutterWatchTab> createState() => _InfocutterWatchTabState();
}

class _InfocutterWatchTabState extends State<InfocutterWatchTab> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aliasesController = TextEditingController();

  @override
  void dispose() {
    _nameController.removeListener(_handleFormChanged);
    _nameController.dispose();
    _aliasesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleFormChanged);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final service = Provider.of<WatchService>(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._buildWatchToggleTiles(service, l10n),
        const Divider(),
        ..._buildTargetForm(l10n),
        const SizedBox(height: 16),
        ..._buildRecentDetections(context, service, l10n),
        ..._buildTargets(service, l10n),
      ],
    );
  }

  List<Widget> _buildWatchToggleTiles(
    WatchService service,
    AppLocalizations l10n,
  ) =>
      [
        InfocutterZeroPaddingSwitchTile(
          title: l10n.infocutterWatchGlobalEnabled,
          value: service.globalEnabled,
          onChanged: (value) =>
              _updateWatch(() => service.setGlobalEnabled(value)),
        ),
        InfocutterZeroPaddingSwitchTile(
          title: l10n.infocutterWatchAutoMask,
          value: service.autoMask,
          onChanged: (value) => _updateWatch(() => service.setAutoMask(value)),
        ),
      ];

  List<Widget> _buildTargetForm(AppLocalizations l10n) => [
        InfocutterOutlinedTextField(
          controller: _nameController,
          labelText: l10n.infocutterWatchTargetName,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 8),
        InfocutterOutlinedTextField(
          controller: _aliasesController,
          labelText: l10n.infocutterWatchAliases,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _canAddTarget ? _addTarget : null,
          icon: const Icon(Icons.person_add),
          label: Text(l10n.infocutterAddWatchTarget),
        ),
      ];

  List<Widget> _buildRecentDetections(
    BuildContext context,
    WatchService service,
    AppLocalizations l10n,
  ) {
    if (service.recentDetections.isEmpty) return const [];

    return [
      Text(
        l10n.infocutterWatchDetections,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      ...service.recentDetections.map(
        (detection) => _buildDetectionTile(detection, l10n),
      ),
      const Divider(),
    ];
  }

  Widget _buildDetectionTile(
    WatchDetection detection,
    AppLocalizations l10n,
  ) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: () => widget.onCaptureDetectionEvidence(detection),
        leading: const Icon(Icons.manage_search),
        title: Text(detection.term),
        subtitle: Text(
          detection.matchedText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: l10n.infocutterCaptureEvidence,
          icon: const Icon(Icons.fact_check),
          onPressed: () => widget.onCaptureDetectionEvidence(detection),
        ),
      );

  List<Widget> _buildTargets(
    WatchService service,
    AppLocalizations l10n,
  ) {
    if (service.targets.isEmpty) {
      return [
        InfocutterEmptyTile(
          icon: Icons.person_search,
          label: l10n.infocutterNoItemsYet,
        ),
      ];
    }

    return service.targets
        .map((target) => _buildTargetTile(service, target, l10n))
        .toList();
  }

  Widget _buildTargetTile(
    WatchService service,
    WatchTarget target,
    AppLocalizations l10n,
  ) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: () => _updateWatch(
          () => service.setTargetEnabled(target.id, !target.enabled),
        ),
        leading: Switch(
          value: target.enabled,
          onChanged: (value) => _updateWatch(
            () => service.setTargetEnabled(target.id, value),
          ),
        ),
        title: Text(target.name),
        subtitle:
            target.aliases.isEmpty ? null : Text(target.aliases.join(', ')),
        trailing: IconButton(
          tooltip: l10n.infocutterRemove,
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            if (!await showInfocutterDeleteConfirmation(context)) return;
            await _updateWatch(
              () => service.removeTarget(target.id),
            );
          },
        ),
      );

  Future<void> _addTarget() async {
    final service = context.read<WatchService>();
    final name = _nameController.text.trim();
    if (!_canAddTarget) return;
    await service.addTarget(
      name: name,
      aliases: _aliasesController.text
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
    );
    await widget.onWatchChanged();
    if (!mounted) return;
    _nameController.clear();
    _aliasesController.clear();
  }

  bool get _canAddTarget => _nameController.text.trim().isNotEmpty;

  void _handleFormChanged() {
    setState(() {});
  }

  Future<void> _updateWatch(Future<void> Function() update) async {
    await update();
    await widget.onWatchChanged();
  }
}
