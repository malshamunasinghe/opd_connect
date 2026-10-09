import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/patient.dart';
import '../../services/patient_service.dart';

/// S16 - Archive record with audit note (F3, NF1).
/// Records are never hard-deleted: archiving hides the record from daily
/// lists but keeps clinical history, and the reason is written to an
/// append-only audit log (Staff Q9 concern about data recovery).
/// Owner: Weerasinghe W.D.S.U (IT23685802)
/// CRUD: READ record + audit trail; UPDATE archived flag;
///       CREATE audit entry; UPDATE restore.
class ArchivePatientScreen extends StatefulWidget {
  final Patient patient;
  const ArchivePatientScreen({super.key, required this.patient});

  @override
  State<ArchivePatientScreen> createState() => _ArchivePatientScreenState();
}

class _ArchivePatientScreenState extends State<ArchivePatientScreen> {
  static const _reasons = [
    'Duplicate record',
    'Patient deceased',
    'Transferred to another hospital',
    'Registered in error',
    'Other',
  ];
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  String _reason = _reasons.first;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final p = widget.patient;
    final restoring = p.archived;
    final note =
        restoring ? _note.text.trim() : '$_reason${_note.text.trim().isEmpty ? '' : ' - ${_note.text.trim()}'}';
    final ok = await confirm(
      context,
      title: restoring ? 'Restore ${p.fullName}?' : 'Archive ${p.fullName}?',
      message: restoring
          ? 'The record will appear in active lists again.'
          : 'The record will be hidden from active lists. Visit history is kept and the record can be restored.',
      confirmLabel: restoring ? 'Restore' : 'Archive',
      danger: !restoring,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final staff = me(context);
    final done = await runGuarded(
      context,
      () => restoring ? PatientService.restore(p, note, staff) : PatientService.archive(p, note, staff),
      success: restoring ? 'Record restored' : 'Record archived',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    final restoring = p.archived;
    return Scaffold(
      appBar: AppBar(title: Text(restoring ? 'Restore record' : 'Archive record')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(p.fullName),
                subtitle: Text('${p.nic} · ${p.phone}'),
              ),
            ),
            const SizedBox(height: 16),
            if (!restoring) ...[
              const Text('Reason', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in _reasons)
                  ChoiceChip(label: Text(r), selected: _reason == r, onSelected: (_) => setState(() => _reason = r)),
              ]),
              const SizedBox(height: 16),
            ],
            AppInput(
              label: restoring ? 'Why is this record being restored? *' : 'Audit note',
              hint: restoring ? 'e.g. Archived by mistake' : 'Optional detail (required for "Other")',
              controller: _note,
              maxLines: 3,
              validator: (v) {
                final empty = (v ?? '').trim().isEmpty;
                if (restoring && empty) return 'A note is required';
                if (!restoring && _reason == 'Other' && empty) return 'Describe the reason';
                if ((v ?? '').trim().length > 200) return 'Keep the note under 200 characters';
                return null;
              },
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.n200.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppSizes.radius),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.verified_user_outlined, color: AppColors.n600),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Your name, the time and this note are saved permanently in the audit log.'),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            restoring
                ? PrimaryButton('Restore record', icon: Icons.unarchive, onPressed: _submit, loading: _busy)
                : DangerButton('Archive record', icon: Icons.archive, onPressed: _submit, loading: _busy),
            const SizedBox(height: 24),
            const SectionTitle('Audit trail'),
            StreamView<List<AuditEntry>>(
              stream: PatientService.audit(p.id),
              builder: (context, entries) => Column(children: [
                if (entries.isEmpty) const Text('No entries yet.'),
                for (final e in entries)
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
      ),
    );
  }
}
