import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/vertical.dart';

/// Profile — operator identity + settings. Includes a demo vertical toggle so both
/// personalities can be previewed.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final vertical = ref.watch(verticalProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: vertical.accent.withValues(alpha: 0.2),
                child: Icon(Icons.person, size: 48, color: vertical.accent),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(session.operatorName.isEmpty ? 'Operator' : session.operatorName,
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            Center(child: Text('${session.operatorId} · ${vertical.label}')),
            const SizedBox(height: 20),
            Card(
              child: Column(
                children: [
                  ListTile(leading: const Icon(Icons.precision_manufacturing), title: const Text('Assigned machine'), trailing: Text(session.machineId.isEmpty ? '—' : session.machineId)),
                  const Divider(height: 1),
                  ListTile(leading: const Icon(Icons.workspace_premium_outlined), title: const Text('Skill level'), trailing: Text(session.skillLevel)),
                  const Divider(height: 1),
                  const ListTile(leading: Icon(Icons.language), title: Text('Language'), trailing: Text('English')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Vertical (demo toggle)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<Vertical>(
              segments: const [
                ButtonSegment(value: Vertical.construction, icon: Icon(Icons.apartment), label: Text('Construction')),
                ButtonSegment(value: Vertical.mining, icon: Icon(Icons.terrain), label: Text('Mining')),
              ],
              selected: {vertical},
              onSelectionChanged: (s) => ref.read(verticalProvider.notifier).set(s.first),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(sessionProvider.notifier).logout();
                context.go('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
            ),
          ],
        ),
      ),
    );
  }
}
