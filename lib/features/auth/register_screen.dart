import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';

/// S17 - Account registration with role selection.
/// Owner: Weerasinghe W.D.S.U (IT23685802)
/// CRUD: CREATE (auth account, users/{uid}, linked patients record);
///       READ (staff access code verified by security rules).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nic = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  String _role = Roles.patient;
  bool _hide = true;
  bool _busy = false;
  bool _agree = false;

  @override
  void dispose() {
    for (final c in [_name, _nic, _phone, _email, _password, _confirm, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => AuthService.register(
        name: _name.text,
        email: _email.text,
        phone: _phone.text,
        password: _password.text,
        role: _role,
        nic: _nic.text,
        accessCode: _code.text,
        language: context.read<AppSettings>().lang,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      // The auth gate swaps to the home screen; close this route.
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = _role == Roles.patient;
    final tr = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: Text(tr.t('createAccount'))),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.grid * 3),
            children: [
              Text(tr.t('iAm'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: Roles.patient, label: Text(tr.t('patientRole')), icon: const Icon(Icons.person)),
                  ButtonSegment(value: Roles.staff, label: const Text('OPD staff'), icon: const Icon(Icons.badge)),
                  ButtonSegment(value: Roles.admin, label: const Text('Admin'), icon: const Icon(Icons.admin_panel_settings)),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: 24),
              AppInput(
                label: tr.t('fullName'),
                controller: _name,
                capitalization: TextCapitalization.words,
                validator: (v) => Validators.personName(v, 'Name'),
              ),
              if (patient)
                AppInput(
                  label: tr.t('nicNumber'),
                  hint: '851234567V or 198512345678',
                  controller: _nic,
                  validator: Validators.nic,
                ),
              AppInput(
                label: tr.t('mobileNumber'),
                hint: '07XXXXXXXX',
                controller: _phone,
                keyboardType: TextInputType.phone,
                validator: Validators.mobile,
              ),
              AppInput(
                label: tr.t('email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              AppInput(
                label: tr.t('password'),
                controller: _password,
                hint: '8+ characters, letters and numbers',
                obscure: _hide,
                validator: Validators.newPassword,
                onChanged: (_) => setState(() {}),
                suffix: IconButton(
                  tooltip: _hide ? 'Show password' : 'Hide password',
                  icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
              PasswordStrength(_password.text),
              AppInput(
                label: tr.t('confirmPassword'),
                controller: _confirm,
                obscure: _hide,
                validator: (v) {
                  if ((v ?? '').isEmpty) return 'Confirm your password';
                  return v != _password.text ? 'Passwords do not match' : null;
                },
              ),
              if (!patient) ...[
                AppInput(
                  label: _role == Roles.admin ? 'Admin access code' : 'Staff access code',
                  hint: 'Provided by the hospital ICT unit',
                  controller: _code,
                  validator: (v) => Validators.text(v, field: 'Access code', min: 4, max: 40),
                ),
                Text(
                  'Staff accounts can view patient records and manage the queue, so an '
                  'access code from the ICT administrator is required.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _agree,
                onChanged: (v) => setState(() => _agree = v ?? false),
                title: const Text(
                  'I agree that OPD Connect may store my details to manage my appointments and health record.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              PrimaryButton('Create account', onPressed: _agree ? _submit : null, loading: _busy),
              const SizedBox(height: 12),
              Text(
                'We will send a verification link to your email.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
