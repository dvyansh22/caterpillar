import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'core/vertical.dart';

void main() {
  // TODO(P4): WidgetsFlutterBinding.ensureInitialized(); await Firebase.initializeApp();
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
      theme: buildTheme(vertical, Brightness.light),
      darkTheme: buildTheme(vertical, Brightness.dark),
      themeMode: ThemeMode.dark, // default dark for in-cab glare/night shifts
      routerConfig: appRouter,
    );
  }
}
