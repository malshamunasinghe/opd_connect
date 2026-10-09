import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/widgets.dart';
import '../../models/patient.dart';
import '../../services/db.dart';
import '../../services/patient_service.dart';
import 'patient_form.dart';

/// S15 - Edit patient details (F3, NF1).
/// Thamara persona: "I have to write everything down by hand, it's so easy
/// to make mistakes" - corrections are now made in place, validated, and
/// every change is written to the audit log.
/// Owner: Weerasinghe W.D.S.U (IT23685802)
/// CRUD: READ current record; UPDATE record (+ CREATE audit entry).
class EditPatientScreen extends StatefulWidget {
  final Patient patient;
  const EditPatientScreen({super.key, required this.patient});

  @override
  State<EditPatientScreen> createState() => _EditPatientScreenState();
}

class _EditPatientScreenState extends State<EditPatientScreen> {
  bool _busy = false;

  Future<void> _save(Map<String, dynamic> data) async {
    setState(() => _busy = true);
    try {
      await PatientService.update(widget.patient, data, me(context));
      if (!mounted) return;
      showSnack(context, 'Changes saved');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit ${widget.patient.fullName}')),
      body: PatientForm(
        initial: widget.patient,
        submitLabel: 'Save changes',
        busy: _busy,
        onSubmit: _save,
      ),
    );
  }
}
