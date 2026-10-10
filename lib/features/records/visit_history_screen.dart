import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/patient.dart';
import '../../services/patient_service.dart';

/// Patient-facing "Visit history": every consultation recorded in the
/// patient's own centralised record (F3), newest first, with a search box
/// and a clinic filter. Read-only: visits are written by staff when a
/// consultation is completed (S11) or entered on the patient's record (S14).
/// Security rules let a patient read only their own visits (NF1).
class VisitHistoryScreen extends StatefulWidget {
  const VisitHistoryScreen({super.key});

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  late final String? _patientId = me(context).patientId;
  late final Stream<List<Visit>>? _visits = _patientId == null ? null : PatientService.visits(_patientId);
  final _search = TextEditingController();
  String _query = '';
  String? _department;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Visit v) {
    if (_department != null && v.department != _department) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return v.department.toLowerCase().contains(q) ||
        v.doctorName.toLowerCase().contains(q) ||
        v.diagnosis.toLowerCase().contains(q) ||
        v.hospitalName.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('visitHistory'))),
      body: _visits == null
          ? EmptyView(icon: Icons.folder_off_outlined, message: s.t('healthLoading'))
          : StreamView<List<Visit>>(
              stream: _visits,
              loadingMessage: s.t('loading'),
              builder: (context, visits) {
                if (visits.isEmpty) return EmptyView(icon: Icons.history, message: s.t('noVisits'));
                final departments =
                    visits.map((v) => v.department).where((d) => d.isNotEmpty).toSet().toList()..sort();
                final shown = visits.where(_matches).toList();
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(children: [
                      Expanded(
                        child: StatTile(
                            value: '${visits.length}',
                            label: s.t('totalVisits'),
                            icon: Icons.local_hospital_outlined),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatTile(
                          value: DateFormat('d MMM yyyy').format(visits.first.date),
                          label: s.t('lastVisit'),
                          icon: Icons.event_available,
                          color: AppColors.success,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: s.t('searchVisits'),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(() {
                                  _search.clear();
                                  _query = '';
                                }),
                              ),
                      ),
                    ),
                    if (departments.length > 1) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(s.t('all')),
                              selected: _department == null,
                              onSelected: (_) => setState(() => _department = null),
                            ),
                          ),
                          for (final d in departments)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(d),
                                selected: _department == d,
                                onSelected: (_) => setState(() => _department = _department == d ? null : d),
                              ),
                            ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: EmptyView(icon: Icons.search_off, message: s.t('noMatchingVisits')),
                      )
                    else
                      for (final v in shown) VisitCard(patientId: _patientId!, visit: v),
                  ],
                );
              },
            ),
    );
  }
}

/// One expandable visit: clinic and date on top, details when opened.
class VisitCard extends StatelessWidget {
  final String patientId;
  final Visit visit;
  const VisitCard({super.key, required this.patientId, required this.visit});

  Future<void> _deleteVisit(BuildContext context) async {
    final place = visit.hospitalName.isNotEmpty ? visit.hospitalName : visit.department;
    final ok = await confirm(
      context,
      title: 'Delete visit history?',
      message: 'Delete the visit at $place on ${formatDay(visit.date)}? This action cannot be undone.',
      confirmLabel: 'Delete visit',
      danger: true,
    );
    if (!ok || !context.mounted) return;

    await runGuarded(
      context,
      () => PatientService.deleteVisit(patientId, visit.id),
      success: 'Visit history deleted',
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = visit;
    final s = context.watch<AppSettings>();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const CircleAvatar(
          backgroundColor: AppColors.n50,
          child: Icon(Icons.medical_services_outlined, color: AppColors.primary),
        ),
        title: Text(v.department.isEmpty ? s.t('clinic') : v.department,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${formatDay(v.date)}${v.hospitalName.isEmpty ? '' : '\n${v.hospitalName}'}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (v.doctorName.isNotEmpty) InfoRow(s.t('doctor'), v.doctorName, icon: Icons.person_outline),
          if (v.tokenLabel.isNotEmpty)
            InfoRow('Token', v.tokenLabel, icon: Icons.confirmation_number_outlined),
          InfoRow(s.t('diagnosis'), v.diagnosis.isEmpty ? s.t('notRecorded') : v.diagnosis,
              icon: Icons.assignment_outlined),
          if (v.notes.isNotEmpty) InfoRow(s.t('notes'), v.notes, icon: Icons.notes),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _deleteVisit(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete visit history'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
