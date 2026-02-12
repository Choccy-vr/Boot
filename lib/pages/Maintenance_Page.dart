import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Terminal-style icon
              Icon(
                Symbols.pause_circle,
                size: 120,
                color: colorScheme.primary,
                weight: 300,
              ),
              const SizedBox(height: 32),
              
              // Main message
              Text(
                'Boot is temporarily down',
                style: textTheme.headlineMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Subtext
              Text(
                'Come back later when we are back up.',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
