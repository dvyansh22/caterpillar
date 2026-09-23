// Smart Operator Assistant for CAT machinery — app entry point (scaffold stub).
//
// Owners: P4 (UI/backend) + P3 (AR bridge, ML wiring).
// This is a placeholder to establish structure. Wire up Firebase, Riverpod, and GoRouter
// in Phase 0/1 per docs/EXECUTION_PLAN.md.

import 'package:flutter/material.dart';

void main() {
  // TODO(P4): WidgetsFlutterBinding.ensureInitialized(); await Firebase.initializeApp();
  runApp(const SmartOperatorApp());
}

class SmartOperatorApp extends StatelessWidget {
  const SmartOperatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Operator Assistant',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.amber),
      home: const _ScaffoldPlaceholder(),
    );
  }
}

// Placeholder landing with the planned bottom navbar: Task | Learning Hub | SOS | Profile.
class _ScaffoldPlaceholder extends StatelessWidget {
  const _ScaffoldPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Operator Assistant')),
      body: const Center(child: Text('Scaffold ready — build features/ next.')),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.assignment), label: 'Task'),
          NavigationDestination(icon: Icon(Icons.school), label: 'Learning'),
          NavigationDestination(icon: Icon(Icons.sos), label: 'SOS'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
