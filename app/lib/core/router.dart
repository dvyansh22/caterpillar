import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/learning_hub/learning_hub_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/safety_gate/safety_gate_screen.dart';
import '../features/shell/main_scaffold.dart';
import '../features/sos/sos_screen.dart';
import '../features/tasks/active_task_screen.dart';
import '../features/tasks/tasks_screen.dart';

/// App navigation. Flow: /login -> /gate -> tabbed shell (tasks/learning/sos/profile).
/// Navigation is imperative for now (screens call context.go). A global auth redirect
/// can be added in P4 task 2 once Firebase Auth lands.
final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/gate', builder: (context, state) => const SafetyGateScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/home/tasks', builder: (c, s) => const TasksScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/home/learning', builder: (c, s) => const LearningHubScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/home/sos', builder: (c, s) => const SosScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/home/profile', builder: (c, s) => const ProfileScreen())],
        ),
      ],
    ),
    GoRoute(
      path: '/task/:id',
      builder: (context, state) => ActiveTaskScreen(taskId: state.pathParameters['id']!),
    ),
  ],
);
