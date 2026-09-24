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
  bool _busy = false;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    const acc = AccentPalette.construction;
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
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: acc.base,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.precision_manufacturing, color: AppColors.onAccent),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('SMART OPERATOR',
                      style: oswald(size: 32, weight: FontWeight.w700, spacing: 0.4, height: 36 / 32, color: AppColors.ink)),
                  const SizedBox(height: 8),
                  Text('Sign in to start your shift. Your role and site load from your account.',
                      style: inter(size: 15, height: 22 / 15, color: AppColors.muted)),
                  const SizedBox(height: 28),
                  _label('Username'),
                  TextField(controller: _user, onChanged: (_) => setState(() => _error = '')),
                  const SizedBox(height: 20),
                  _label('Password'),
                  TextField(controller: _pass, obscureText: true, onChanged: (_) => setState(() => _error = '')),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error, style: inter(size: 14, color: AppColors.errorText)),
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
                    backgroundColor: acc.base,
                    foregroundColor: AppColors.onAccent,
                    disabledBackgroundColor: acc.base,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusButton)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onAccent))
                      : Text('SIGN IN', style: oswald(size: 16, weight: FontWeight.w600, spacing: 1, color: AppColors.onAccent)),
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
        child: Text(t, style: inter(size: 13, weight: FontWeight.w500, color: AppColors.muted)),
      );
}
