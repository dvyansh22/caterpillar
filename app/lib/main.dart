import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_state.dart';
import 'core/config.dart';
import 'core/nav.dart';
import 'core/theme.dart';
import 'core/tokens.dart';
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
    // The web build is the owner dashboard product (no login). Sign in anonymously
    // so its Firestore reads (incidents/training) are authorized by the rules
    // (which require request.auth != null). Best-effort: if the Anonymous provider
    // isn't enabled, the dashboard falls back to seed data per source.
    if (kIsWeb) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (_) {}
    }
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

/// One-time startup: restore a persisted operator session (mobile) so the app
/// resumes where it left off instead of dropping back to login. Web is the
/// dashboard product and skips this.
final bootProvider = FutureProvider<bool>((ref) async {
  if (kIsWeb) return false;
  final restored = await ref.read(appProvider.notifier).restore();
  if (restored) ref.read(navProvider.notifier).toApp();
  return restored;
});

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Web is the owner/fleet dashboard product — boot straight into it, no login
    // (design handoff: FLEET_DASHBOARD, "No login").
    if (kIsWeb) return const DashboardScreen();

    // Wait for session restore before routing, so a resumed session lands in the
    // app instead of flashing the login screen.
    final boot = ref.watch(bootProvider);
    if (boot.isLoading) return const _BootSplash();
    return _phaseScreen(ref);
  }

  Widget _phaseScreen(WidgetRef ref) {
    final phase = ref.watch(navProvider.select((s) => s.phase));
    return switch (phase) {
      AppPhase.login => const LoginScreen(),
      AppPhase.gate => const SafetyGateScreen(),
      AppPhase.welcome => const WelcomeScreen(),
      AppPhase.app => const MainShell(),
      AppPhase.dashboard => const DashboardScreen(),
    };
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(child: CircularProgressIndicator(color: AppColors.ink2)),
    );
  }
}
