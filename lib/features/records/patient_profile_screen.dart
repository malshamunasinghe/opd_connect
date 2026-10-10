// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/appointment.dart';
import '../../models/patient.dart';
import '../../services/patient_service.dart';
import 'archive_patient_screen.dart';
import 'edit_patient_screen.dart';

/// S14 - Patient profile and visit history (F3).
/// Nuwan persona: "If we had a centralised database, half these problems
/// would disappear." Visits are added automatically when reception finishes
/// a consultation (S11) and can also be added or corrected here.
/// Owner: Weerasinghe W.D.S.U (IT23685802)
/// CRUD: READ profile + visits; CREATE visit; UPDATE visit notes;
///       DELETE a visit entered by mistake.
class PatientProfileScreen extends StatefulWidget {
  final String patientId;
  const PatientProfileScreen({super.key, required this.patientId});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  late final _patientStream = PatientService.patient(widget.patientId);
  late final _visitStream = PatientService.visits(widget.patientId);
  late final _appointmentStream = PatientService.bookedAppointments(widget.patientId);

  Future<void> _visitDialog({Visit? existing}) async {
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _VisitDialog(existing: existing),
    );
    if (res == null || !mounted) return;
    if (existing == null) {
      await runGuarded(context, () => PatientService.addVisit(widget.patientId, res), success: 'Visit added');
    } else {
      await runGuarded(context, () => PatientService.updateVisit(widget.patientId, existing.id, res),
          success: 'Visit updated');
    }
  }

  Future<void> _deleteVisit(Visit v) async {
    final ok = await confirm(context,
        title: 'Delete this visit?',
        message: '${formatDay(v.date)} · ${v.department}\nOnly delete a visit entered by mistake.',
        confirmLabel: 'Delete',
        danger: true);
    if (ok && mounted) {
      await runGuarded(context, () => PatientService.deleteVisit(widget.patientId, v.id), success: 'Visit deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<CurrentUser>().profile?.isAdmin ?? false;
    if (!isAdmin) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Admin access required to view patient records.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }
    return StreamView<Patient?>(
      stream: _patientStream,
      builder: (context, p) {
        if (p == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyView(icon: Icons.search_off, message: 'Record not found'),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(p.fullName),
            actions: [
              IconButton(
                tooltip: 'Edit details',
                icon: const Icon(Icons.edit),
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => EditPatientScreen(patient: p))),
              ),
              IconButton(
                tooltip: p.archived ? 'Restore record' : 'Archive record',
                icon: Icon(p.archived ? Icons.unarchive : Icons.archive_outlined),
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ArchivePatientScreen(patient: p))),
              ),
              IconButton(
                tooltip: 'Delete patient',
                icon: const Icon(Icons.delete_forever_outlined),
                onPressed: () async {
                  if (!mounted) return;
                  final ok = await confirm(
                    context,
                    title: 'Delete patient?',
                    message: 'This will permanently remove ${p.fullName} from the patient records. This action cannot be undone.',
                    confirmLabel: 'Delete patient',
                    danger: true,
                  );
                  if (!ok || !mounted) return;
                  final deleted = await runGuarded(
                    context,
                    () => PatientService.deletePatient(p.id),
                    success: 'Patient deleted',
                  );
                  if (deleted && mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
          floatingActionButton: p.archived
              ? null
              : FloatingActionButton.extended(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  onPressed: () => _visitDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add visit'),
                ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (p.archived)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSizes.radius),
                  ),
                  child: Text('Archived: ${p.archiveNote ?? ''}'),
                ),
              if (p.allergies.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radius),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Allergies: ${p.allergies}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    InfoRow('NIC', p.nic, icon: Icons.badge_outlined),
                    InfoRow('Mobile', p.phone, icon: Icons.phone_outlined),
                    InfoRow('Date of birth', p.dob == null ? '' : '${formatDay(p.dob!)} (${p.age} yrs)',
                        icon: Icons.cake_outlined),
                    InfoRow('Gender', p.gender, icon: Icons.person_outline),
                    InfoRow('Blood group', p.bloodGroup, icon: Icons.bloodtype_outlined),
                    InfoRow('Address', p.address, icon: Icons.home_outlined),
                    InfoRow('Emergency', p.emergencyContact, icon: Icons.contact_phone_outlined),
                    InfoRow('App account', p.linkedUid == null ? 'No' : 'Yes', icon: Icons.phone_android),
                    if (p.updatedAt != null) InfoRow('Last updated', formatDateTime(p.updatedAt!), icon: Icons.update),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              const SectionTitle('Booked hospitals'),
              StreamView<List<Appointment>>(
                stream: _appointmentStream,
                builder: (context, appointments) {
                  final hospitals = HistoryLogic.hospitalNamesInOrder(
                    appointments.map((a) => a.hospitalName),
                  );
                  if (hospitals.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No booked appointments yet.'),
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final hospital in hospitals)
                        Chip(
                          avatar: const Icon(Icons.local_hospital_outlined, size: 18),
                          label: Text(hospital),
                          backgroundColor: AppColors.n50,
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const SectionTitle('Visit history'),
              StreamView<List<Visit>>(
                stream: _visitStream,
                builder: (context, visits) {
                  if (visits.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No visits recorded yet.'),
                    );
                  }
                  return Column(children: [
                    for (final v in visits)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            isThreeLine: true,
                            leading: const Icon(Icons.medical_information_outlined, color: AppColors.primary),
                            title: Text([
                              formatDay(v.date),
                              if (v.department.isNotEmpty) v.department,
                              if (v.hospitalName.isNotEmpty) v.hospitalName,
                            ].join(' · ')),
                            subtitle: Text([
                              '${v.doctorName}${v.tokenLabel.isNotEmpty ? ' · ${v.tokenLabel}' : ''}',
                              if (v.diagnosis.isNotEmpty) 'Diagnosis: ${v.diagnosis}',
                              if (v.notes.isNotEmpty) v.notes,
                              if (v.diagnosis.isEmpty && v.notes.isEmpty) 'Tap to add notes',
                            ].join('\n')),
                            onTap: p.archived ? null : () => _visitDialog(existing: v),
                            trailing: p.archived
                                ? null
                                : IconButton(
                                    tooltip: 'Delete visit',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _deleteVisit(v),
                                  ),
                          ),
                        ),
                      ),
                  ]);
                },
              ),
              const SizedBox(height: 16),
              const SectionTitle('Audit trail'),
              StreamView<List<AuditEntry>>(
                stream: PatientService.audit(p.id),
                builder: (context, entries) => Column(children: [
                  if (entries.isEmpty) const Text('No changes recorded.'),
                  for (final e in entries.take(10))
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.history, size: 20),
                      title: Text('${e.action} · ${e.byName}'),
                      subtitle: Text('${e.at == null ? '' : formatDateTime(e.at!)}\n${e.note}'),
                    ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VisitDialog extends StatefulWidget {
  final Visit? existing;
  const _VisitDialog({this.existing});

  @override
  State<_VisitDialog> createState() => _VisitDialogState();
}

class _VisitDialogState extends State<_VisitDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _dept = TextEditingController(text: widget.existing?.department ?? 'General OPD');
  late final _hospital = TextEditingController(text: widget.existing?.hospitalName ?? '');
  late final _doctor = TextEditingController(text: widget.existing?.doctorName ?? '');
  late final _diagnosis = TextEditingController(text: widget.existing?.diagnosis ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late DateTime _date = widget.existing?.date ?? DateTime.now();

  @override
  void dispose() {
    for (final c in [_dept, _hospital, _doctor, _diagnosis, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Edit visit' : 'Add visit'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(formatDay(_date)),
              onTap: editing
                  ? null
                  : () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setState(() => _date = d);
                    },
            ),
            TextFormField(
              controller: _dept,
              enabled: !editing,
              decoration: const InputDecoration(labelText: 'Clinic / department'),
              validator: (v) => Validators.text(v, field: 'Department', min: 3, max: 50),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hospital,
              decoration: const InputDecoration(labelText: 'Hospital (optional)'),
              validator: (v) => (v ?? '').trim().isEmpty ? null : Validators.text(v, field: 'Hospital', max: 80),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _doctor,
              decoration: const InputDecoration(labelText: 'Doctor (optional)'),
              validator: (v) => (v ?? '').trim().isEmpty ? null : Validators.personName(v, 'Doctor name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _diagnosis,
              decoration: const InputDecoration(labelText: 'Diagnosis'),
              validator: (v) {
                // A new visit needs at least a diagnosis or some notes.
                if (!editing && (v ?? '').trim().isEmpty && _notes.text.trim().isEmpty) {
                  return 'Enter a diagnosis or notes';
                }
                return Validators.text(v, field: 'Diagnosis', max: 300);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes'),
              validator: (v) => Validators.text(v, field: 'Notes', max: 500),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, <String, dynamic>{
              if (!editing) 'date': Timestamp.fromDate(_date),
              if (!editing) 'department': _dept.text.trim(),
              if (!editing) 'tokenLabel': '',
              'hospitalName': _hospital.text.trim(),
              'doctorName': _doctor.text.trim(),
              'diagnosis': _diagnosis.text.trim(),
              'notes': _notes.text.trim(),
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
