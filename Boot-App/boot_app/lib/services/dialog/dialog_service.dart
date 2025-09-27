import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class DialogService {
  static void showComingSoon(
    BuildContext context,
    String feature,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Row(
          children: [
            Icon(Symbols.construction, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '$feature Coming Soon!',
              style: textTheme.titleLarge?.copyWith(color: colorScheme.primary),
            ),
          ],
        ),
        content: Text(
          'This feature is under development for Boot YSWS Winter 2025.\n\nStay tuned for updates!',
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}
