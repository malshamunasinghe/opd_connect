import 'package:flutter/material.dart';

import '../../core/logic.dart';
import '../../core/strings.dart';
import '../../core/widgets.dart';
import '../../models/patient.dart';

/// Form fields shared by S13 (new registration) and S15 (edit details), so
/// both screens validate identically.
/// Owner: Weerasinghe W.D.S.U (IT23685802)
class PatientForm extends StatefulWidget {
  final Patient? initial;
  final String initialNic;
  final String submitLabel;
  final bool busy;
  final ValueChanged<Map<String, dynamic>> onSubmit;

  const PatientForm({
    super.key,
    this.initial,
    this.initialNic = '',
    required this.submitLabel,
    required this.busy,
    required this.onSubmit,
  });

  @override
  State<PatientForm> createState() => _PatientFormState();
}

class _PatientFormState extends State<PatientForm> {
  static const genders = ['Male', 'Female', 'Other'];
  static const bloodGroups = ['', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _nic;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _allergies;
  late final TextEditingController _emergency;
  DateTime? _dob;
  String _gender = '';
  String _blood = '';
  String _lang = 'si';

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p?.fullName ?? '');
    _nic = TextEditingController(text: p?.nic ?? widget.initialNic);
    _phone = TextEditingController(text: p?.phone ?? '');
    _address = TextEditingController(text: p?.address ?? '');
    _allergies = TextEditingController(text: p?.allergies ?? '');
    _emergency = TextEditingController(text: p?.emergencyContact ?? '');
    _dob = p?.dob;
    _gender = genders.contains(p?.gender) ? p!.gender : '';
    _blood = bloodGroups.contains(p?.bloodGroup) ? p!.bloodGroup : '';
    _lang = S.supported.contains(p?.preferredLanguage) ? p!.preferredLanguage : 'si';
    if (p == null && widget.initialNic.isNotEmpty) _fillFromNic(widget.initialNic);
  }

  @override
  void dispose() {
    for (final c in [_name, _nic, _phone, _address, _allergies, _emergency]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Fewer keystrokes at a busy counter: DOB and gender come from the NIC.
  void _fillFromNic(String nic) {
    final dob = Validators.dobFromNic(nic);
    final g = Validators.genderFromNic(nic);
    if (dob != null) {
      setState(() {
        _dob = dob;
        if (g != null) _gender = g;
      });
    }
  }

  Future<void> _pickDob() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1980),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _dob = d);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final dobError = Validators.dob(_dob);
    if (dobError != null) {
      showSnack(context, dobError, error: true);
      return;
    }
    if (_gender.isEmpty) {
      showSnack(context, 'Select a gender', error: true);
      return;
    }
    // The NIC already encodes date of birth and gender; a mismatch means a typo.
    final nicDob = Validators.dobFromNic(_nic.text);
    if (nicDob != null && (nicDob.year != _dob!.year || nicDob.month != _dob!.month || nicDob.day != _dob!.day)) {
      showSnack(context, 'Date of birth does not match the NIC number', error: true);
      return;
    }
    final nicGender = Validators.genderFromNic(_nic.text);
    if (nicGender != null && _gender != 'Other' && nicGender != _gender) {
      showSnack(context, 'Gender does not match the NIC number', error: true);
      return;
    }
    widget.onSubmit(Patient.editableData(
      fullName: _name.text,
      nic: _nic.text,
      phone: _phone.text,
      dob: _dob,
      gender: _gender,
      address: _address.text,
      bloodGroup: _blood,
      allergies: _allergies.text,
      emergencyContact: _emergency.text,
      preferredLanguage: _lang,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppInput(
            label: 'Full name *',
            controller: _name,
            capitalization: TextCapitalization.words,
            validator: (v) => Validators.personName(v, 'Name'),
          ),
          AppInput(
            label: 'NIC number *',
            hint: '851234567V or 198512345678',
            controller: _nic,
            validator: Validators.nic,
            onChanged: (v) {
              if (Validators.nic(v) == null) _fillFromNic(v);
            },
          ),
          AppInput(
            label: 'Mobile number *',
            hint: '07XXXXXXXX',
            controller: _phone,
            keyboardType: TextInputType.phone,
            validator: Validators.mobile,
          ),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: _pickDob,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date of birth', suffixIcon: Icon(Icons.event)),
                  child: Text(_dob == null ? 'Select' : formatDay(_dob!)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _gender.isEmpty ? null : _gender,
                key: ValueKey('g$_gender'),
                decoration: const InputDecoration(labelText: 'Gender *'),
                items: [for (final g in genders) DropdownMenuItem(value: g, child: Text(g))],
                onChanged: (v) => setState(() => _gender = v ?? ''),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          AppInput(
            label: 'Address',
            controller: _address,
            maxLines: 2,
            validator: (v) => Validators.text(v, field: 'Address', max: 200),
          ),
          DropdownButtonFormField<String>(
            initialValue: _blood,
            decoration: const InputDecoration(labelText: 'Blood group'),
            items: [
              for (final b in bloodGroups) DropdownMenuItem(value: b, child: Text(b.isEmpty ? 'Unknown' : b)),
            ],
            onChanged: (v) => setState(() => _blood = v ?? ''),
          ),
          const SizedBox(height: 16),
          AppInput(
            label: 'Allergies',
            hint: 'e.g. Penicillin',
            controller: _allergies,
            validator: (v) => Validators.text(v, field: 'Allergies', max: 200),
          ),
          AppInput(
            label: 'Emergency contact',
            hint: 'Name and number',
            controller: _emergency,
            validator: (v) => Validators.text(v, field: 'Emergency contact', max: 100),
          ),
          DropdownButtonFormField<String>(
            initialValue: _lang,
            decoration: const InputDecoration(labelText: 'Preferred language'),
            items: [
              for (final l in S.supported) DropdownMenuItem(value: l, child: Text(S.languageNames[l]!)),
            ],
            onChanged: (v) => setState(() => _lang = v ?? _lang),
          ),
          const SizedBox(height: 24),
          PrimaryButton(widget.submitLabel, onPressed: _submit, loading: widget.busy),
        ],
      ),
    );
  }
}
