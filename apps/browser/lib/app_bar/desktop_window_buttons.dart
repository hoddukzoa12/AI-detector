import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/window_service.dart';
import '../util.dart';

class DesktopWindowButtons extends StatelessWidget {
  const DesktopWindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    if (Util.isWindows()) {
      return const SizedBox.shrink();
    }

    final windowControls = Provider.of<WindowControls>(
      context,
      listen: false,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 8),
        _WindowDotButton(
          color: Colors.red,
          icon: Icons.close,
          onPressed: windowControls.close,
        ),
        const SizedBox(width: 8),
        _WindowDotButton(
          color: Colors.amber,
          icon: Icons.remove,
          onPressed: windowControls.minimizeIfNotFullScreen,
        ),
        const SizedBox(width: 8),
        _WindowDotButton(
          color: Colors.green,
          icon: Icons.open_in_full,
          onPressed: windowControls.toggleFullScreen,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _WindowDotButton extends StatelessWidget {
  const _WindowDotButton({
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  final Color color;
  final IconData icon;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      constraints: const BoxConstraints(
        maxWidth: 13,
        minWidth: 13,
        maxHeight: 13,
        minHeight: 13,
      ),
      padding: EdgeInsets.zero,
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: WidgetStatePropertyAll(color),
        iconColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.hovered) ? Colors.black45 : color,
        ),
      ),
      color: color,
      icon: Icon(icon, size: 10),
    );
  }
}
