import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';

/// FR-GATE-1/2 — pre-start safety gate. Auto-verifies checks; hard-blocks entry until all pass.
/// Checks are mocked here (seatbelt would come from the telematics dataset, camera from a
/// permission/liveness check). Breathalyzer intentionally removed.
class SafetyGateScreen extends ConsumerStatefulWidget {
  const SafetyGateScreen({super.key});

  @override
  ConsumerState<SafetyGateScreen> createState() => _SafetyGateScreenState();
}

enum _CheckStatus { checking, pass, fail }

class _Check {
  _Check(this.label, this.icon);
  final String label;
  final IconData icon;
  _CheckStatus status = _CheckStatus.checking;
}

class _SafetyGateScreenState extends ConsumerState<SafetyGateScreen> {
  late final List<_Check> _checks = [
    _Check('Seatbelt fastened', Icons.airline_seat_recline_normal),
    _Check('Operator camera on', Icons.videocam_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    for (var i = 0; i < _checks.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _checks[i].status = _CheckStatus.pass); // mock: all pass
    }
  }

  bool get _allPassed => _checks.every((c) => c.status == _CheckStatus.pass);
  bool get _anyFailed => _checks.any((c) => c.status == _CheckStatus.fail);

  void _enter() {
    ref.read(sessionProvider.notifier).passGate();
    context.go('/home/tasks');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pre-Start Safety Check'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Complete all checks to start your shift',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ..._checks.map(_buildCheckRow),
                  if (_anyFailed)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: SafetyColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SafetyColors.danger),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.block, color: SafetyColors.danger),
                          SizedBox(width: 10),
                          Expanded(child: Text('Cannot start — resolve failed checks before proceeding.')),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _allPassed ? _enter : null,
                icon: const Icon(Icons.login),
                label: Text(_allPassed ? 'Enter' : 'Checking…'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckRow(_Check c) {
    final (Widget trailing, Color color) = switch (c.status) {
      _CheckStatus.checking => (
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          Colors.grey,
        ),
      _CheckStatus.pass => (const Icon(Icons.check_circle, color: SafetyColors.pass), SafetyColors.pass),
      _CheckStatus.fail => (const Icon(Icons.cancel, color: SafetyColors.danger), SafetyColors.danger),
    };
    return Card(
      child: ListTile(
        leading: Icon(c.icon, color: color),
        title: Text(c.label),
        subtitle: Text(switch (c.status) {
          _CheckStatus.checking => 'Checking…',
          _CheckStatus.pass => 'Passed',
          _CheckStatus.fail => 'Failed',
        }),
        trailing: trailing,
      ),
    );
  }
}
