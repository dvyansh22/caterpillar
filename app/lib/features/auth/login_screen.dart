import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/nav.dart';
import '../../core/tokens.dart';
import '../../services/auth_service.dart';

/// 01 Login (FR-AUTH-1/2). The account decides role + vertical.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _user = TextEditingController(text: 'arjun');
  final _pass = TextEditingController(text: 'demo1234');
  String _error = '';

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _pick(String username) {
    setState(() {
      _user.text = username;
      _error = '';
    });
  }

  bool _busy = false;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final user = await ref.read(authServiceProvider).signIn(_user.text, _pass.text);
      await ref.read(appProvider.notifier).startSession(user);
      ref.read(navProvider.notifier).toGate();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Owner dashboard: sign in (best-effort) first so its Firestore reads
  /// (incidents/training) are authorized; falls back to seed data if sign-in
  /// fails. The fleet stats come from the ML backend regardless.
  Future<void> _openDashboard() async {
    try {
      final user = await ref.read(authServiceProvider).signIn(_user.text, _pass.text);
      await ref.read(appProvider.notifier).startSession(user);
    } catch (_) {
      // ignore: the dashboard still opens with seed fallback for denied reads
    }
    if (mounted) ref.read(navProvider.notifier).toDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _user.text.trim().toLowerCase();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AccentPalette.construction.base,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.precision_manufacturing, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text('Smart Operator',
                      style: TextStyle(fontSize: 32, height: 40 / 32, letterSpacing: -0.2, color: AppColors.ink)),
                  const SizedBox(height: 8),
                  const Text('Sign in to start your shift. Your role and site load from your account.',
                      style: TextStyle(fontSize: 15, height: 22 / 15, color: AppColors.muted)),
                  const SizedBox(height: 28),
                  _label('Username'),
                  TextField(controller: _user, onChanged: (_) => setState(() => _error = '')),
                  const SizedBox(height: 20),
                  _label('Password'),
                  TextField(controller: _pass, obscureText: true, onChanged: (_) => setState(() => _error = '')),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error, style: const TextStyle(fontSize: 14, color: AppColors.errorText)),
                    ),
                  const SizedBox(height: 28),
                  _label('Demo accounts'),
                  Row(
                    children: [
                      Expanded(child: _demoCard('arjun', 'Construction · EXC004', selected == 'arjun')),
                      const SizedBox(width: 12),
                      Expanded(child: _demoCard('bala', 'Mining · HT012', selected == 'bala')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: _openDashboard,
                      icon: const Icon(Icons.dashboard_outlined, size: 18),
                      label: const Text('Open owner dashboard'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _signIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: AccentPalette.construction.base,
                    foregroundColor: AppColors.ink,
                    disabledBackgroundColor: AccentPalette.construction.base,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.ink))
                      : const Text('Sign in'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.muted)),
      );

  Widget _demoCard(String name, String sub, bool selected) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pick(name),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.ink : AppColors.inputBorder, width: selected ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.ink)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
