import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/logic.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../services/auth_service.dart';
import '../profile/help_screen.dart';
import 'register_screen.dart';

/// S17 - Login with role-based access.
/// Owner: Weerasinghe W.D.S.U (IT23685802)
/// CRUD: READ (credentials checked, role read from users/{uid});
///       UPDATE (password reset e-mail).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  int _failures = 0;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final ok = await runGuarded(context, () => AuthService.signIn(_email.text, _password.text));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _failures++;
    });
  }

  /// Asks for the e-mail (pre-filled) and sends the reset link.
  Future<void> _forgot() async {
    final ctrl = TextEditingController(text: _email.text.trim());
    final formKey = GlobalKey<FormState>();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset your password'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('We will e-mail you a link to choose a new password.'),
            const SizedBox(height: 12),
            TextFormField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: Validators.email,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (email == null || !mounted) return;
    _email.text = email;
    await runGuarded(context, () => AuthService.sendPasswordReset(email),
        success: 'If an account exists for $email, a reset link is on its way.');
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          GradientHeader(
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 12, 24, 40),
            child: Column(children: [
              // Language choice before sign-in, so a Sinhala or Tamil
              // speaker is not blocked at the very first screen (NF3).
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  for (final code in S.supported)
                    ChoiceChip(
                      label: Text(S.languageNames[code]!),
                      selected: settings.lang == code,
                      onSelected: (_) => settings.apply(lang: code),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.local_hospital, size: 56, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              const Text('OPD Connect',
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Book. Track the queue. Be on time.', style: TextStyle(color: Colors.white70, fontSize: 15)),
            ]),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(settings.t('welcomeBack'), style: t.headlineMedium),
                    const SizedBox(height: 4),
                    Text(settings.t('loginSub'), style: t.bodySmall),
                    const SizedBox(height: 24),
                    AutofillGroup(
                      child: Column(children: [
                        AppInput(
                          label: settings.t('email'),
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                        ),
                        AppInput(
                          label: settings.t('password'),
                          controller: _password,
                          obscure: _hide,
                          validator: Validators.passwordRequired,
                          suffix: IconButton(
                            tooltip: _hide ? 'Show password' : 'Hide password',
                            icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _hide = !_hide),
                          ),
                        ),
                      ]),
                    ),
                    if (_failures >= 2)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: InfoBanner(
                          icon: Icons.help_outline,
                          color: AppColors.accent,
                          message: 'Having trouble? Check your e-mail spelling or use "Forgot password".',
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: _forgot, child: Text(settings.t('forgotPassword'))),
                    ),
                    const SizedBox(height: 8),
                    PrimaryButton(settings.t('signIn'), onPressed: _signIn, loading: _busy),
                    const SizedBox(height: 12),
                    SecondaryButton(
                      settings.t('createAccount'),
                      onPressed: () =>
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
                      icon: const Icon(Icons.help_outline),
                      label: Text(settings.t('helpEmergency')),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      const Icon(Icons.lock_outline, size: 18, color: AppColors.n600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your health information is protected. Staff can only see records '
                          'needed for your visit.',
                          style: t.bodySmall,
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
