/// Placeholder Profile screen — P4's responsibility.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vertical = ref.watch(verticalProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Vertical switcher (useful for P3 testing both themes)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vertical',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Switch between construction and mining mode',
                    style: TextStyle(
                      fontSize: 13,
                      color: CatColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<Vertical>(
                    segments: [
                      for (final v in Vertical.values)
                        ButtonSegment(
                          value: v,
                          label: Text(v.displayName),
                          icon: Icon(
                            v == Vertical.construction
                                ? Icons.construction_rounded
                                : Icons.terrain_rounded,
                          ),
                        ),
                    ],
                    selected: {vertical},
                    onSelectionChanged: (v) =>
                        ref.read(verticalProvider.notifier).state = v.first,
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.2),
                      selectedForegroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Placeholder content
          Center(
            child: Column(
              children: [
                Icon(Icons.person_rounded,
                    size: 64, color: CatColors.textMuted),
                const SizedBox(height: 16),
                const Text(
                  'Operator Profile',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'TODO(P4): Auth, skills passport, machine assignment',
                  style:
                      TextStyle(color: CatColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
