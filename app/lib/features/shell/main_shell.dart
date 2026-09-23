import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/nav.dart';
import '../../core/tokens.dart';
import '../learning_hub/ar_lesson_screen.dart';
import '../learning_hub/learning_hub_screen.dart';
import '../profile/profile_screen.dart';
import '../sos/sos_screen.dart';
import '../tasks/active_task_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../tasks/tasks_screen.dart';

/// The tabbed app shell: app bar + 3-tab nav + floating SOS button, hosting the tab flows.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navProvider);
    final user = ref.watch(currentUserProvider);
    final acc = user.accent;
    final title = switch (nav.tab) {
      AppTab.task => 'Tasks',
      AppTab.learn => 'Learning Hub',
      AppTab.sos => 'Emergency SOS',
      AppTab.profile => 'Profile',
    };

    final taskFlow = switch (nav.taskView) {
      TaskView.list => const TasksScreen(),
      TaskView.detail => const TaskDetailScreen(),
      TaskView.active => const ActiveTaskScreen(),
    };
    final learnFlow = nav.lessonId == null ? const LearningHubScreen() : const ArLessonScreen();

    final body = IndexedStack(
      index: nav.tab.index,
      children: [taskFlow, learnFlow, const ProfileScreen(), const SosScreen()],
    );

    return Scaffold(
      appBar: _appBar(context, ref, nav, title, acc),
      body: SafeArea(top: false, child: body),
      floatingActionButton: nav.tab == AppTab.sos ? null : const _SosFab(),
      bottomNavigationBar: _bottomNav(ref, nav, acc),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, WidgetRef ref, NavState nav, String title, AccentPalette acc) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          if (nav.tab == AppTab.sos)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                onPressed: () => ref.read(navProvider.notifier).closeSos(),
                icon: const Icon(Icons.close),
                iconSize: 22,
              ),
            ),
          Text(title, style: const TextStyle(fontSize: 20, color: AppColors.ink)),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _VerticalChip(acc: acc, label: ref.watch(currentUserProvider).verticalLabel),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.divider),
      ),
    );
  }

  Widget _bottomNav(WidgetRef ref, NavState nav, AccentPalette acc) {
    final hasActive = ref.watch(appProvider.select((s) => s.activeTaskId != null));
    Widget item(AppTab tab, IconData icon, String label, VoidCallback onTap) {
      final active = nav.tab == tab;
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? acc.tint : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 22, color: AppColors.ink),
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: AppColors.ink)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(top: BorderSide(color: AppColors.dividerRow)),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Row(
        children: [
          item(AppTab.task, Icons.assignment_outlined, 'Task',
              () => ref.read(navProvider.notifier).goTask(hasActive: hasActive)),
          item(AppTab.learn, Icons.school_outlined, 'Learning Hub', () => ref.read(navProvider.notifier).goLearn()),
          item(AppTab.profile, Icons.person_outline, 'Profile', () => ref.read(navProvider.notifier).goProfile()),
        ],
      ),
    );
  }
}

class _VerticalChip extends StatelessWidget {
  const _VerticalChip({required this.acc, required this.label});
  final AccentPalette acc;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: acc.base, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink2)),
        ],
      ),
    );
  }
}

/// Floating SOS button. Pulses a red halo while an SOS is active.
class _SosFab extends ConsumerStatefulWidget {
  const _SosFab();

  @override
  ConsumerState<_SosFab> createState() => _SosFabState();
}

class _SosFabState extends ConsumerState<_SosFab> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(appProvider.select((s) => s.sosStartedMs != null));
    return GestureDetector(
      onTap: () => ref.read(navProvider.notifier).openSos(),
      child: SizedBox(
        width: 84,
        height: 84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (active)
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = _c.value;
                  return Container(
                    width: 68 * (1 + 0.55 * t),
                    height: 68 * (1 + 0.55 * t),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.danger.withValues(alpha: 0.5 * (1 - t)),
                    ),
                  );
                },
              ),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.danger,
                border: Border.all(color: AppColors.bg, width: 3),
                boxShadow: [
                  BoxShadow(color: AppColors.danger.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 6)),
                  const BoxShadow(color: Color(0x1F000000), blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('SOS',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  if (active)
                    const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
