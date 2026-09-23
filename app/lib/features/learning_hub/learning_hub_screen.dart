import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/vertical.dart';

/// FR-LEARN — AR training hub (placeholder UI). AR modules render via Unity (P3).
class LearningHubScreen extends ConsumerWidget {
  const LearningHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(verticalProvider).accent;
    final modules = <(String, String, double)>[
      ('AR Controls Trainer', 'Map everyday objects to machine controls', 0.4),
      ('Pre-Op Inspection', 'Walkthrough checklist in AR', 0.75),
      ('Grade & Precision', 'Practice level grading', 0.1),
      ('Safety Scenarios', 'Hazard response drills', 0.0),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Learning Hub', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('AR-based training', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Card(
              color: accent.withValues(alpha: 0.15),
              child: ListTile(
                leading: Icon(Icons.view_in_ar, color: accent, size: 32),
                title: const Text('Assigned to you'),
                subtitle: const Text('Excessive idling detected — 90s micro-lesson'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 12),
            ...modules.map((m) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: accent.withValues(alpha: 0.18),
                      child: Icon(Icons.play_arrow, color: accent),
                    ),
                    title: Text(m.$1),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.$2),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: m.$3, minHeight: 6),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                )),
            const SizedBox(height: 12),
            Text('Skills Passport', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: const [
                Chip(avatar: Icon(Icons.verified, size: 18), label: Text('Excavator')),
                Chip(avatar: Icon(Icons.verified, size: 18), label: Text('Safety L2')),
                Chip(avatar: Icon(Icons.lock_outline, size: 18), label: Text('Grading')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
