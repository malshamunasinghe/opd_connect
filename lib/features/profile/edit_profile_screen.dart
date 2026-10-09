import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/app_settings.dart';
import '../../core/logic.dart';
import '../../core/widgets.dart';
import '../../models/patient.dart';
import '../../services/profile_service.dart';
import 'package:provider/provider.dart';

/// Edit the signed-in user's name, phone and (for patients) health details.
/// The NIC and e-mail are shown but locked: staff verify the NIC at the
/// counter and the e-mail is the login.
class EditProfileScreen extends StatefulWidget {
  final Patient? record;
  const EditProfileScreen({super.key, this.record});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _genders = ['Male', 'Female', 'Other'];
  static const _bloodGroups = ['', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _allergies;
  late final TextEditingController _emergency;
  DateTime? _dob;
  String _gender = '';
  String _blood = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<CurrentUser>().profile!;
    final r = widget.record;
    _name = TextEditingController(text: p.name);
    _phone = TextEditingController(text: p.phone);
    _address = TextEditingController(text: r?.address ?? '');
    _allergies = TextEditingController(text: r?.allergies ?? '');
    _emergency = TextEditingController(text: r?.emergencyContact ?? '');
    _dob = r?.dob;
    _gender = _genders.contains(r?.gender) ? r!.gender : '';
    _blood = _bloodGroups.contains(r?.bloodGroup) ? r!.bloodGroup : '';
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _allergies, _emergency]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDob() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _dob = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final hasRecord = widget.record != null;
    if (hasRecord) {
      final dobError = Validators.dob(_dob);
      if (dobError != null) {
        showSnack(context, dobError, error: true);
        return;
      }
      if (_gender.isEmpty) {
        showSnack(context, 'Select a gender', error: true);
        return;
      }
    }
    setState(() => _busy = true);
    final p = me(context);
    final ok = await runGuarded(
      context,
      () => ProfileService.updateProfile(
        uid: p.uid,
        patientId: p.patientId,
        name: _name.text,
        phone: _phone.text,
        dob: _dob,
        gender: _gender,
        address: _address.text,
        bloodGroup: _blood,
        allergies: _allergies.text,
        emergencyContact: _emergency.text,
      ),
      success: 'Profile updated',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CurrentUser>().profile!;
    final hasRecord = widget.record != null;
    return Scaffold(
      appBar: AppBar(title: Text(context.watch<AppSettings>().t('editProfile'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppInput(
              label: '${context.watch<AppSettings>().t('fullName')} *',
              controller: _name,
              capitalization: TextCapitalization.words,
              validator: (v) => Validators.personName(v, 'Name'),
            ),
            AppInput(
              label: context.watch<AppSettings>().t('mobileNumber'),
              hint: '07XXXXXXXX',
              controller: _phone,
              keyboardType: TextInputType.phone,
              validator: Validators.mobile,
            ),
            AppInput(
              label: 'Email (cannot be changed)',
              controller: TextEditingController(text: p.email),
              enabled: false,
            ),
            if (hasRecord) ...[
              AppInput(
                label: 'NIC number (verified by hospital staff)',
                controller: TextEditingController(text: widget.record!.nic),
                enabled: false,
              ),
              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDob,
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: '${context.watch<AppSettings>().t('dob')} *', suffixIcon: const Icon(Icons.event)),
                      child: Text(_dob == null ? 'Select' : formatDay(_dob!)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _gender.isEmpty ? null : _gender,
                    decoration: InputDecoration(labelText: context.watch<AppSettings>().t('genderReq')),
                    items: [for (final g in _genders) DropdownMenuItem(value: g, child: Text(g))],
                    onChanged: (v) => setState(() => _gender = v ?? ''),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _blood,
                decoration: InputDecoration(labelText: context.watch<AppSettings>().t('bloodGroup')),
                items: [for (final b in _bloodGroups) DropdownMenuItem(value: b, child: Text(b.isEmpty ? 'Unknown' : b))],
                onChanged: (v) => setState(() => _blood = v ?? ''),
              ),
              const SizedBox(height: 16),
              AppInput(
                label: context.watch<AppSettings>().t('address'),
                controller: _address,
                maxLines: 2,
                validator: (v) => Validators.text(v, field: 'Address', max: 200),
              ),
              AppInput(
                label: context.watch<AppSettings>().t('allergies'),
                hint: 'e.g. Penicillin',
                controller: _allergies,
                validator: (v) => Validators.text(v, field: 'Allergies', max: 200),
              ),
              AppInput(
                label: context.watch<AppSettings>().t('emergencyContact'),
                hint: 'Name and number',
                controller: _emergency,
                validator: (v) => Validators.text(v, field: 'Emergency contact', max: 100),
              ),
            ],
            const SizedBox(height: 8),
            PrimaryButton(context.watch<AppSettings>().t('saveChanges'), icon: Icons.check, onPressed: _save, loading: _busy),
            const SizedBox(height: 12),
            SecondaryButton(context.watch<AppSettings>().t('cancelBtn'), onPressed: _busy ? null : () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}
