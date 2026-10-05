import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/evidence_service.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_sidebar_widgets.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class InfocutterEvidenceTab extends StatefulWidget {
  const InfocutterEvidenceTab({
    required this.onCaptureEvidence,
    super.key,
  });

  final Future<void> Function() onCaptureEvidence;

  @override
  State<InfocutterEvidenceTab> createState() => _InfocutterEvidenceTabState();
}

class _InfocutterEvidenceTabState extends State<InfocutterEvidenceTab> {
  bool _capturing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final service = Provider.of<EvidenceService>(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCaptureButton(l10n),
        const SizedBox(height: 16),
        ..._buildRecords(service, l10n),
      ],
    );
  }

  Widget _buildCaptureButton(AppLocalizations l10n) => FilledButton.icon(
        onPressed: _capturing ? null : _capture,
        icon: const Icon(Icons.fact_check),
        label: Text(l10n.infocutterCaptureEvidence),
      );

  List<Widget> _buildRecords(
    EvidenceService service,
    AppLocalizations l10n,
  ) {
    if (service.records.isEmpty) {
      return [
        InfocutterEmptyTile(
          icon: Icons.picture_as_pdf,
          label: l10n.infocutterNoEvidenceRecords,
        ),
      ];
    }

    return service.records
        .map((record) => _buildRecordTile(service, record, l10n))
        .toList();
  }

  Widget _buildRecordTile(
    EvidenceService service,
    EvidenceRecord record,
    AppLocalizations l10n,
  ) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          child: Text(record.sequence.toString()),
        ),
        title: Text(
          record.pageTitle.isNotEmpty ? record.pageTitle : record.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${record.capturedAt.toLocal()} · ${record.htmlSha256}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: l10n.infocutterRemove,
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            if (!await showInfocutterDeleteConfirmation(context)) return;
            await service.deleteRecord(record.id);
          },
        ),
      );

  Future<void> _capture() async {
    setState(() {
      _capturing = true;
    });
    try {
      await widget.onCaptureEvidence();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).infocutterEvidenceCaptureFailed,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _capturing = false;
        });
      }
    }
  }
}
