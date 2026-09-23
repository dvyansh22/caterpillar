/// Placeholder SOS screen — P4's responsibility.
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sos_rounded, size: 64, color: CatColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Emergency SOS',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'TODO(P4): BLE mesh SOS beacon',
              style: TextStyle(color: CatColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
