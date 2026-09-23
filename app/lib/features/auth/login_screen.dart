import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/vertical.dart';

/// FR-AUTH-1/2 — login + vertical routing. Mock now; Firebase Auth in P4 task 2.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _user = TextEditingController(text: 'OP1001');
  final _pass = TextEditingController(text: 'demo');

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _login() {
    ref.read(sessionProvider.notifier).login(_user.text.trim());
    context.go('/gate');
  }

  @override
  Widget build(BuildContext context) {
    final vertical = ref.watch(verticalProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Icon(Icons.precision_manufacturing, size: 72, color: vertical.accent),
                const SizedBox(height: 16),
                Text('Smart Operator Assistant',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('CAT machinery companion',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                TextField(
                  controller: _user,
                  decoration: const InputDecoration(labelText: 'Username / Operator ID', prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: _login, child: const Text('Log In')),
                const SizedBox(height: 16),
                // Demo-only vertical selector (real vertical comes from the account's claims).
                SegmentedButton<Vertical>(
                  segments: const [
                    ButtonSegment(value: Vertical.construction, label: Text('Construction')),
                    ButtonSegment(value: Vertical.mining, label: Text('Mining')),
                  ],
                  selected: {vertical},
                  onSelectionChanged: (s) => ref.read(verticalProvider.notifier).set(s.first),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
