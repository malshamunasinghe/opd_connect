import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/widgets.dart';
import '../../services/db.dart';
import '../../services/patient_service.dart';
import 'patient_form.dart';

/// S13 - New patient registration (F3, F5). Replaces the paper register
/// (Staff Q3: "Manual system", "paper record").
/// Owner: Weerasinghe W.D.S.U (IT23685802)
/// CRUD: READ (duplicate-NIC check); CREATE patient record + audit entry.
/// Returns the new patient id to the caller (used by S09 walk-in).
class RegisterPatientScreen extends StatefulWidget {
  final String initialNic;
  const RegisterPatientScreen({super.key, this.initialNic = ''});

  @override
  State<RegisterPatientScreen> createState() => _RegisterPatientScreenState();
}

class _RegisterPatientScreenState extends State<RegisterPatientScreen> {
  bool _busy = false;

  Future<void> _save(Map<String, dynamic> data) async {
    setState(() => _busy = true);
    try {
      final id = await PatientService.create(data, me(context));
      if (!mounted) return;
      showSnack(context, '${data['fullName']} registered');
      Navigator.pop(context, id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register new patient')),
      body: PatientForm(
        initialNic: widget.initialNic,
        submitLabel: 'Register patient',
        busy: _busy,
        onSubmit: _save,
      ),
    );
  }
}
