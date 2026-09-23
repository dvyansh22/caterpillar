import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/nav.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/safety_gate/safety_gate_screen.dart';
import 'features/shell/main_shell.dart';
import 'features/welcome/welcome_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Only touches Firebase when explicitly enabled (see docs/FIREBASE_SETUP.md).
  if (kUseFirebase) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  runApp(const ProviderScope(child: SmartOperatorApp()));
}

class SmartOperatorApp extends StatelessWidget {
  const SmartOperatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Operator',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _Root(),
    );
  }
}

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(navProvider.select((s) => s.phase));
    // Return the active screen directly. (The former AnimatedSwitcher + phone-width
    // builder wrapper are gone; they added a loosely-constrained Stack/SizedBox layer
    // that only muddied debugging of the real bottom-nav height bug in MainShell.)
    return switch (phase) {
      AppPhase.login => const LoginScreen(),
      AppPhase.gate => const SafetyGateScreen(),
      AppPhase.welcome => const WelcomeScreen(),
      AppPhase.app => const MainShell(),
      AppPhase.dashboard => const DashboardScreen(),
    };
  }
}
