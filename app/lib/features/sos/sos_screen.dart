import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// FR-SOS — emergency. Press-and-hold to broadcast. Real BLE mesh relay in P4 task 6;
/// here the button + broadcasting state are simulated.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  Timer? _holdTimer;
  double _hold = 0; // 0..1 over 3s
  bool _sent = false;

  void _startHold() {
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      setState(() => _hold += 0.1 / 3);
      if (_hold >= 1.0) {
        t.cancel();
        setState(() => _sent = true);
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    if (!_sent) setState(() => _hold = 0);
  }

  void _reset() => setState(() {
        _sent = false;
        _hold = 0;
      });

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency SOS')),
      body: SafeArea(
        child: Center(
          child: _sent ? _broadcasting() : _button(),
        ),
      ),
    );
  }

  Widget _button() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Hold for 3 seconds to send'),
        const SizedBox(height: 24),
        GestureDetector(
          onTapDown: (_) => _startHold(),
          onTapUp: (_) => _cancelHold(),
          onTapCancel: _cancelHold,
          child: SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: _hold == 0 ? null : _hold,
                    strokeWidth: 10,
                    backgroundColor: SafetyColors.danger.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation(SafetyColors.danger),
                  ),
                ),
                Container(
                  width: 170,
                  height: 170,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: SafetyColors.danger),
                  child: const Center(
                    child: Text('SOS',
                        style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text('Works offline — alerts nearby devices via Bluetooth even with no signal.',
              textAlign: TextAlign.center),
        ),
      ],
    );
  }

  Widget _broadcasting() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.wifi_tethering, size: 72, color: SafetyColors.danger),
        const SizedBox(height: 16),
        Text('Broadcasting to nearby devices…', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Location + last sensor snapshot attached'),
        const SizedBox(height: 24),
        const Card(
          child: ListTile(leading: Icon(Icons.person_pin_circle), title: Text('Supervisor'), trailing: Text('~40 m')),
        ),
        const Card(
          child: ListTile(leading: Icon(Icons.person_pin_circle), title: Text('OP1002'), trailing: Text('~85 m')),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(onPressed: _reset, icon: const Icon(Icons.close), label: const Text('Cancel')),
      ],
    );
  }
}
