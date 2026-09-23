/// Placeholder Tasks screen — P4's responsibility.
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_rounded,
                size: 64, color: CatColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Task Dashboard',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'TODO(P4): Task cards with ML ETAs',
              style: TextStyle(color: CatColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
