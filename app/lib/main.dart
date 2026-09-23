import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/nav.dart';
import 'core/theme.dart';
import 'core/tokens.dart';
import 'features/auth/login_screen.dart';
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
      // The design targets a phone. Cap the width so it reads like a phone on wide
      // screens (web); harmless on real devices (<= this width).
      builder: (context, child) => ColoredBox(
        color: AppColors.bg,
        child: Center(
          // width capped to phone size, height fills the window (keeps Scaffold bounded).
          child: SizedBox(width: 430, height: double.infinity, child: child),
        ),
      ),
    );
  }
}

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(navProvider.select((s) => s.phase));
    final child = switch (phase) {
      AppPhase.login => const LoginScreen(),
      AppPhase.gate => const SafetyGateScreen(),
      AppPhase.welcome => const WelcomeScreen(),
      AppPhase.app => const MainShell(),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(key: ValueKey(phase), child: child),
    );
  }
}
