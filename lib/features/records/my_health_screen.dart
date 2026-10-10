import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/patient.dart';
import '../../services/patient_service.dart';
import '../../services/profile_service.dart';
import '../profile/edit_profile_screen.dart';
import 'visit_history_screen.dart';

/// "My health" tab: the patient's own health summary and visit history
/// (read from their centralised record, F3). Read-only except for the
/// profile details, which open the edit screen.
class MyHealthScreen extends StatelessWidget {
  const MyHealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final patientId = me(context).patientId;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('records'))),
      body: patientId == null
          ? EmptyView(icon: Icons.folder_off_outlined, message: s.t('healthLoading'))
          : StreamView<Patient?>(
              stream: ProfileService.myRecord(patientId),
              loadingMessage: s.t('loading'),
              builder: (context, record) {
                if (record == null) {
                  return EmptyView(icon: Icons.folder_off_outlined, message: s.t('somethingWrong'));
                }
                return _Body(record: record);
              },
            ),
    );
  }
}

class _Body extends StatefulWidget {
  final Patient record;
  const _Body({required this.record});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final Stream<List<Visit>> _visits = PatientService.visits(widget.record.id);

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final s = context.watch<AppSettings>();
    final t = Theme.of(context).textTheme;
    final allergies = r.allergies.trim();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(s.t('healthProfile'), style: t.titleLarge)),
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(s.t('edit')),
                  onPressed: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(record: r))),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _Fact(icon: Icons.bloodtype, label: s.t('bloodGroup'), value: r.bloodGroup.isEmpty ? '—' : r.bloodGroup, color: AppColors.danger)),
                Expanded(child: _Fact(icon: Icons.cake_outlined, label: s.t('ageLabel'), value: r.age == null ? '—' : '${r.age}', color: AppColors.primary)),
                Expanded(child: _Fact(icon: Icons.wc, label: s.t('genderLabel'), value: r.gender.isEmpty ? '—' : r.gender, color: AppColors.n600)),
              ]),
              const Divider(height: 24),
              Text(s.t('allergies'), style: t.bodySmall),
              const SizedBox(height: 4),
              if (allergies.isEmpty)
                Text(s.t('noneRecorded'))
              else
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final a in allergies.split(RegExp(r'[,;\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty))
                    Pill(a, color: AppColors.danger, icon: Icons.warning_amber),
                ]),
              if (r.emergencyContact.isNotEmpty) ...[
                const SizedBox(height: 12),
                InfoRow(s.t('emergencyContact'), r.emergencyContact, icon: Icons.contact_phone_outlined),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 8),
        SectionTitle(s.t('visitHistory')),
        StreamView<List<Visit>>(
          stream: _visits,
          builder: (context, visits) {
            if (visits.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: EmptyView(
                  icon: Icons.history,
                  message: s.t('noVisits'),
                ),
              );
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: StatTile(value: '${visits.length}', label: s.t('totalVisits'), icon: Icons.local_hospital_outlined)),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    value: '${visits.first.date.day}/${visits.first.date.month}',
                    label: s.t('lastVisit'),
                    icon: Icons.event_available,
                    color: AppColors.success,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              // Latest three here; the full list, search and filter live on
              // the Visit history screen.
              for (final v in visits.take(3)) VisitCard(patientId: r.id, visit: v),
              const SizedBox(height: 4),
              SecondaryButton(
                s.t('viewAllVisits'),
                icon: Icons.history,
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const VisitHistoryScreen())),
              ),
            ]);
          },
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _Fact({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}
