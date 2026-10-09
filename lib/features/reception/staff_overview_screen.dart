import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/clinic_session.dart';
import '../../services/schedule_service.dart';
import '../profile/profile_screen.dart';
import '../records/register_patient_screen.dart';
import '../schedule/create_session_screen.dart';
import '../schedule/hospitals_screen.dart';
import 'check_in_screen.dart';
import 'queue_dashboard_screen.dart';
import 'reports_screen.dart';

/// Staff "Overview" tab: today's clinics at a glance, alerts and shortcuts.
class StaffOverviewScreen extends StatefulWidget {
  final ValueChanged<int> onSwitchTab;
  const StaffOverviewScreen({super.key, required this.onSwitchTab});

  @override
  State<StaffOverviewScreen> createState() => _StaffOverviewScreenState();
}

class _StaffOverviewScreenState extends State<StaffOverviewScreen> {
  /// The next 7 days of clinics, live: today's tiles and the "Coming up"
  /// list both come from this one stream, so a clinic created for any of
  /// those days shows up immediately.
  late final Stream<List<ClinicSession>> _week = ScheduleService.week(DateTime.now());

  void _openQueue({ClinicSession? session}) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QueueDashboardScreen(initialDay: session?.date, initialSessionId: session?.id),
        ),
      );

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
  }

  @override
  Widget build(BuildContext context) {
    final profile = me(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 28),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_greeting(), style: const TextStyle(color: Colors.white70, fontSize: 15)),
                  Text(profile.name,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${profile.isAdmin ? 'Admin' : 'OPD staff'} · ${DateFormat('EEEE, d MMMM').format(DateTime.now())}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ]),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(40),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                child: InitialsAvatar(profile.name, radius: 26),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: StreamView<List<ClinicSession>>(
              stream: _week,
              builder: (context, week) {
                final todayKey = DateKeys.of(DateTime.now());
                final sessions = week.where((s) => s.dateKey == todayKey).toList();
                final upcoming = week.where((s) => s.dateKey != todayKey && s.isActive).toList();
                final live = sessions.where((s) => s.isActive).toList();
                final booked = live.fold<int>(0, (a, s) => a + s.bookedCount);
                final capacity = live.fold<int>(0, (a, s) => a + s.capacity);
                final waiting = live.fold<int>(0, (a, s) => a + s.waitingIds.length);
                final serving = live.where((s) => s.currentServingId != null).length;
                final now = DateTime.now();
                // Clinics that should have started but nobody has been called.
                final delayed = live.where((s) {
                  final start = DateKeys.startOf(s.date, s.startTime);
                  return start.isBefore(now) && s.currentServingId == null && s.waitingIds.isNotEmpty;
                }).toList();
                final nearlyFull = live.where((s) => !s.isFull && s.capacity > 0 && s.bookedCount / s.capacity >= 0.85);
                final cancelled = sessions.length - live.length;

                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionTitle(
                    'Today · ${DateFormat('EEE d MMM').format(DateTime.now())}',
                    trailing: upcoming.isEmpty
                        ? null
                        : Pill('${upcoming.length} more coming up', color: AppColors.primary, icon: Icons.event),
                  ),
                  Row(children: [
                    Expanded(child: StatTile(value: '${live.length}', label: 'Clinics', icon: Icons.local_hospital_outlined)),
                    const SizedBox(width: 8),
                    Expanded(child: StatTile(value: '$booked/$capacity', label: 'Booked', icon: Icons.event_seat_outlined, color: AppColors.primaryDark)),
                    const SizedBox(width: 8),
                    Expanded(child: StatTile(value: '$waiting', label: 'Waiting', icon: Icons.people_alt_outlined, color: AppColors.accent)),
                    const SizedBox(width: 8),
                    Expanded(child: StatTile(value: '$serving', label: 'In room', icon: Icons.medical_services_outlined, color: AppColors.success)),
                  ]),
                  const SizedBox(height: 16),
                  if (delayed.isNotEmpty) ...[
                    InfoBanner(
                      icon: Icons.schedule,
                      color: AppColors.danger,
                      message: '${delayed.length} clinic${delayed.length == 1 ? ' has' : 's have'} patients waiting but nobody has been called: '
                          '${delayed.map((s) => s.department).join(', ')}.',
                      action: TextButton(onPressed: _openQueue, child: const Text('Open queue')),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (nearlyFull.isNotEmpty) ...[
                    InfoBanner(
                      icon: Icons.warning_amber,
                      color: AppColors.accent,
                      message: 'Nearly full: ${nearlyFull.map((s) => '${s.department} (${s.placesLeft} left)').join(', ')}.',
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (cancelled > 0) ...[
                    InfoBanner(
                      icon: Icons.event_busy,
                      color: AppColors.n600,
                      message: '$cancelled clinic${cancelled == 1 ? ' was' : 's were'} cancelled today.',
                    ),
                    const SizedBox(height: 8),
                  ],
                  SectionTitle('Shortcuts'),
                  ActionGrid(
                        children: [
                          QuickAction(icon: Icons.people_alt_outlined, label: 'Queue', onTap: _openQueue),
                          QuickAction(
                              icon: Icons.qr_code_scanner,
                              label: 'Check-in',
                              color: AppColors.success,
                              onTap: () =>
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckInScreen()))),
                          QuickAction(
                              icon: Icons.person_add_alt_1,
                              label: 'New patient',
                              color: AppColors.success,
                              onTap: () => Navigator.push(
                                  context, MaterialPageRoute(builder: (_) => const RegisterPatientScreen()))),
                          QuickAction(
                              icon: Icons.add_box_outlined,
                              label: 'New clinic',
                              color: AppColors.primaryDark,
                              onTap: () => Navigator.push(
                                  context, MaterialPageRoute(builder: (_) => const CreateSessionScreen()))),
                          QuickAction(
                              icon: Icons.local_hospital_outlined,
                              label: 'Hospitals',
                              color: AppColors.primary,
                              onTap: () => Navigator.push(
                                  context, MaterialPageRoute(builder: (_) => const HospitalsScreen()))),
                          QuickAction(
                              icon: Icons.bar_chart,
                              label: 'Reports',
                              color: AppColors.accent,
                              onTap: () =>
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()))),
                        ],
                  ),
                  SectionTitle("Today's clinics"),
                  if (sessions.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(children: [
                          const Icon(Icons.event_busy, size: 48, color: AppColors.n400),
                          const SizedBox(height: 8),
                          Text('No clinics are scheduled for today.', style: t.bodyLarge),
                          const SizedBox(height: 12),
                          SecondaryButton('Create a clinic session', icon: Icons.add,
                              onPressed: () => Navigator.push(
                                  context, MaterialPageRoute(builder: (_) => const CreateSessionScreen()))),
                        ]),
                      ),
                    ),
                  for (final s in sessions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SessionRow(session: s, onTap: () => _openQueue(session: s)),
                    ),
                  SectionTitle('Coming up (next 7 days)',
                      trailing: TextButton.icon(
                        onPressed: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const CreateSessionScreen())),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New clinic'),
                      )),
                  if (upcoming.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('No clinics are planned for the coming days.', style: t.bodySmall),
                      ),
                    ),
                  for (final s in upcoming)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SessionRow(session: s, showDate: true, onTap: () => _openQueue(session: s)),
                    ),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final ClinicSession session;
  final VoidCallback onTap;
  final bool showDate;
  const _SessionRow({required this.session, required this.onTap, this.showDate = false});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final t = Theme.of(context).textTheme;
    final ratio = s.capacity == 0 ? 0.0 : s.bookedCount / s.capacity;
    final color = !s.isActive ? AppColors.n400 : (s.isFull ? AppColors.danger : (ratio > 0.85 ? AppColors.accent : AppColors.success));
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('${showDate ? '${DateFormat('EEE d MMM').format(s.date)} · ' : ''}${s.department} · ${s.startTime}–${s.endTime}',
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              if (!s.isActive)
                const Pill('Cancelled', color: AppColors.danger)
              else if (s.currentTokenLabel != null)
                Pill('Serving ${s.currentTokenLabel}', color: AppColors.success, icon: Icons.campaign)
              else
                const Pill('Not started', color: AppColors.n600),
            ]),
            Text('${s.hospitalName} · ${s.doctorName}${s.room.isEmpty ? '' : ' · ${s.room}'}', style: t.bodySmall),
            const SizedBox(height: 10),
            MeterBar(value: ratio, color: color),
            const SizedBox(height: 4),
            Row(children: [
              Text(
                '${s.bookedCount}/${s.capacity} booked${s.isFull ? ' · FULL' : (ratio > 0.85 ? ' · nearly full' : '')}',
                style: t.bodySmall?.copyWith(
                    color: s.isFull ? AppColors.danger : null, fontWeight: s.isFull ? FontWeight.bold : null),
              ),
              const Spacer(),
              Text('${s.waitingIds.length} waiting', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );
  }
}
