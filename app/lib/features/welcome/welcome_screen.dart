import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/nav.dart';
import '../../core/tokens.dart';

/// 03 Welcome. Auto-advances to the app after 3s.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) ref.read(navProvider.notifier).toApp();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final tasks = ref.watch(tasksProvider);
    final acc = user.accent;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: acc.tint, shape: BoxShape.circle),
                child: Icon(Icons.check, color: acc.ink),
              ),
              const SizedBox(height: 24),
              Text('Good morning, ${user.first}',
                  style: const TextStyle(fontSize: 36, height: 44 / 36, color: AppColors.ink)),
              const SizedBox(height: 12),
              Text(
                'Safety checks passed on ${user.machineId}. You have ${tasks.length} tasks today at ${user.siteShort}.',
                style: const TextStyle(fontSize: 16, height: 24 / 16, color: AppColors.muted),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => ref.read(navProvider.notifier).toApp(),
                  style: FilledButton.styleFrom(
                    backgroundColor: acc.base,
                    foregroundColor: AppColors.ink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Go to tasks'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
