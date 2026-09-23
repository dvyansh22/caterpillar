/// GoRouter configuration for the Smart Operator Assistant.
///
/// Shell route with bottom nav (Task | Learning Hub | SOS | Profile).
/// Learning Hub is P3's feature; other tabs are P4 placeholders.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/learning_hub/screens/ar_repair_screen.dart';
import '../features/learning_hub/screens/ar_training_screen.dart';
import '../features/learning_hub/screens/learning_hub_screen.dart';
import '../features/learning_hub/screens/on_device_safety_screen.dart';
import '../features/tasks/screens/tasks_screen.dart';
import '../features/sos/screens/sos_screen.dart';
import '../features/profile/screens/profile_screen.dart';

final routerProvider = GoRouter(
  initialLocation: '/tasks',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(
          path: '/tasks',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: TasksScreen(),
          ),
        ),
        GoRoute(
          path: '/learning-hub',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: LearningHubScreen(),
          ),
          routes: [
            GoRoute(
              path: 'training/:moduleId',
              builder: (context, state) => ArTrainingScreen(
                moduleId: state.pathParameters['moduleId']!,
              ),
            ),
            GoRoute(
              path: 'repair',
              builder: (context, state) => const ArRepairScreen(),
            ),
            GoRoute(
              path: 'safety',
              builder: (context, state) => const OnDeviceSafetyScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/sos',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SosScreen(),
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProfileScreen(),
          ),
        ),
      ],
    ),
  ],
);

/// App shell with bottom navigation bar.
class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});
  final Widget child;

  static const _tabs = [
    (icon: Icons.assignment_rounded, label: 'Task', path: '/tasks'),
    (icon: Icons.school_rounded, label: 'Learning', path: '/learning-hub'),
    (icon: Icons.sos_rounded, label: 'SOS', path: '/sos'),
    (icon: Icons.person_rounded, label: 'Profile', path: '/profile'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
