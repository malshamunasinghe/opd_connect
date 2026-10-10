// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/patient.dart';
import '../../services/patient_service.dart';
import 'patient_profile_screen.dart';
import 'register_patient_screen.dart';

/// Patient records home (entry to S13-S16): search by name, NIC or phone.
/// Owner: Weerasinghe W.D.S.U (IT23685802)
class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final _search = TextEditingController();
  final _stream = PatientService.allPatients();
  String _query = '';
  bool _archived = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Patient records')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPatientScreen())),
        icon: const Icon(Icons.person_add),
        label: const Text('New patient'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search by name, NIC or mobile',
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Active'), icon: Icon(Icons.folder_open)),
              ButtonSegment(value: true, label: Text('Archived'), icon: Icon(Icons.archive_outlined)),
            ],
            selected: {_archived},
            onSelectionChanged: (s) => setState(() => _archived = s.first),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamView<List<Patient>>(
            stream: _stream,
            builder: (context, all) {
              final list = PatientService.filter(all, _query, archived: _archived);
              if (list.isEmpty) {
                return EmptyView(
                  icon: Icons.person_search,
                  message: _query.isEmpty
                      ? (_archived ? 'No archived records.' : 'No patient records yet.')
                      : 'No patient matches "$_query".',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = list[i];
                  return Card(
                    child: ListTile(
                      minVerticalPadding: 12,
                      leading: CircleAvatar(
                        backgroundColor: p.archived ? AppColors.n200 : AppColors.primary.withValues(alpha: 0.12),
                        child: Text(p.fullName.isEmpty ? '?' : p.fullName[0].toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      title: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${p.nic} · ${p.phone}${p.age != null ? ' · ${p.age} yrs' : ''}'),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Patient actions',
                        onSelected: (value) async {
                          if (value == 'delete') {
                            if (!mounted) return;
                            final ok = await confirm(
                              context,
                              title: 'Delete patient?',
                              message: 'This permanently deletes ${p.fullName} from the database: the record, visit '
                                  'history, bookings, notifications and app profile. Audit entries are kept. '
                                  'This cannot be undone.',
                              confirmLabel: 'Delete patient',
                              danger: true,
                            );
                            if (!ok || !mounted) return;
                            final admin = me(context);
                            await runGuarded(
                              context,
                              () => PatientService.deletePatient(p, admin),
                              success: 'Patient deleted',
                            );
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'delete', child: Text('Delete patient')),
                        ],
                      ),
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => PatientProfileScreen(patientId: p.id))),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
