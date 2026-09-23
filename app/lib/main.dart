// Smart Operator Assistant for CAT machinery — app entry point.
//
// Owners: P4 (UI/backend) + P3 (AR bridge, ML wiring).
// Wired with Riverpod, GoRouter, and the CAT theme.
// Firebase init is TODO(P4) — needs GoogleService-Info.plist.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO(P4): await Firebase.initializeApp();
  runApp(const ProviderScope(child: SmartOperatorApp()));
}

class SmartOperatorApp extends ConsumerWidget {
  const SmartOperatorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vertical = ref.watch(verticalProvider);

    return MaterialApp.router(
      title: 'Smart Operator Assistant',
      debugShowCheckedModeBanner: false,
      theme: buildCatTheme(isMining: vertical == Vertical.mining),
      routerConfig: routerProvider,
    );
  }
}
