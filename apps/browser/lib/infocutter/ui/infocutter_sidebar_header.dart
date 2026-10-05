import 'package:flutter/material.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

class InfocutterSidebarHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onClose;

  const InfocutterSidebarHeader({
    required this.title,
    required this.onClose,
    this.icon = Icons.content_cut,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset(
              'assets/icon/icon.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: l10n.infocutterClosePanel,
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
