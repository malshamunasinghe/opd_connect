import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/logic.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../services/profile_service.dart';

/// Change the account password. The current password is required (Firebase
/// asks for a recent sign-in before it lets a password change).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => ProfileService.changePassword(current: _current.text, next: _next.text),
      success: 'Password changed',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final eye = IconButton(
      tooltip: _hide ? 'Show passwords' : 'Hide passwords',
      icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
      onPressed: () => setState(() => _hide = !_hide),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.watch<AppSettings>().t('changePassword'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppInput(
              label: context.watch<AppSettings>().t('currentPassword'),
              controller: _current,
              obscure: _hide,
              validator: Validators.passwordRequired,
              suffix: eye,
            ),
            AppInput(
              label: context.watch<AppSettings>().t('newPassword'),
              hint: '8+ characters, letters and numbers',
              controller: _next,
              obscure: _hide,
              validator: Validators.newPassword,
              onChanged: (_) => setState(() {}),
            ),
            PasswordStrength(_next.text),
            AppInput(
              label: context.watch<AppSettings>().t('confirmNewPassword'),
              controller: _confirm,
              obscure: _hide,
              validator: (v) => v != _next.text ? 'Passwords do not match' : null,
            ),
            PrimaryButton(context.watch<AppSettings>().t('changePassword'), icon: Icons.lock_reset, onPressed: _save, loading: _busy),
          ],
        ),
      ),
    );
  }
}
