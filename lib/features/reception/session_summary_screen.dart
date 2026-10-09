import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/appointment.dart';
import '../../models/clinic_session.dart';
import '../../services/queue_service.dart';

/// End-of-clinic summary for one session: how many were seen, how long the
/// doctor took per patient on average, how long people waited, no-shows.
/// READ only - the figures come from the timestamps recorded by "Call next".
class SessionSummaryScreen extends StatelessWidget {
  final ClinicSession session;
  const SessionSummaryScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Session summary')),
      body: StreamView<List<Appointment>>(
        stream: QueueService.sessionAppointments(s.id),
        builder: (context, appts) {
          int count(String st) => appts.where((a) => a.status == st).length;
          final seen = count(AppointmentStatus.completed);
          final noShow = count(AppointmentStatus.noShow);
          final cancelled = count(AppointmentStatus.cancelled);
          final waiting = appts.where((a) => a.status == AppointmentStatus.waiting).length;

          final consults = [
            for (final a in appts)
              if (a.status == AppointmentStatus.completed && a.calledAt != null && a.completedAt != null)
                a.completedAt!.difference(a.calledAt!).inSeconds / 60
          ];
          final avgConsult = consults.isEmpty ? null : consults.reduce((a, b) => a + b) / consults.length;

          // Waiting time = from the clinic's start (or the moment the token
          // was issued, if that was later) until the patient was called.
          final clinicStart = DateKeys.startOf(s.date, s.startTime);
          final waits = <int>[
            for (final a in appts)
              if (a.calledAt != null && a.createdAt != null)
                a.calledAt!
                    .difference(a.createdAt!.isAfter(clinicStart) ? a.createdAt! : clinicStart)
                    .inMinutes
                    .clamp(0, 600)
          ];
          final avgWait = waits.isEmpty ? null : waits.reduce((a, b) => a + b) / waits.length;
          final walkIns = appts.where((a) => a.channel == 'walkIn').length;
          final phone = appts.where((a) => a.channel == 'phone').length;
          final priority = appts.where((a) => a.priority).length;
          final times = [
            for (final a in appts)
              if (a.completedAt != null) a.completedAt!
          ]..sort();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${s.department} · ${s.hospitalName}', style: t.titleLarge),
              Text('${formatDay(s.date)} · ${s.startTime}–${s.endTime} · ${s.doctorName}', style: t.bodySmall),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: StatTile(value: '${appts.length}', label: 'Tokens issued', icon: Icons.confirmation_number_outlined)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(value: '$seen', label: 'Seen', icon: Icons.check_circle_outline, color: AppColors.success)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(value: '$waiting', label: 'Still waiting', icon: Icons.hourglass_empty, color: AppColors.accent)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: StatTile(value: '$noShow', label: 'No-shows', icon: Icons.person_off_outlined, color: AppColors.accent)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(value: '$cancelled', label: 'Cancelled', icon: Icons.event_busy, color: AppColors.n600)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(value: '$priority', label: 'Priority', icon: Icons.star_outline, color: AppColors.accent)),
              ]),
              SectionTitle('Timing'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    InfoRow('Avg. consultation',
                        avgConsult == null ? 'Not enough data yet' : '${avgConsult.toStringAsFixed(1)} min (planned ${s.avgConsultMinutes} min)',
                        icon: Icons.timer_outlined),
                    InfoRow('Avg. waiting time',
                        avgWait == null ? 'Not enough data yet' : '${avgWait.round()} min',
                        icon: Icons.hourglass_bottom),
                    InfoRow('Patients called', '${waits.length}', icon: Icons.campaign_outlined),
                    if (times.isNotEmpty) ...[
                      InfoRow('First finished', DateFormat('h:mm a').format(times.first), icon: Icons.flag_outlined),
                      InfoRow('Last finished', DateFormat('h:mm a').format(times.last), icon: Icons.flag),
                    ],
                    if (s.delayMinutes > 0) InfoRow('Delay announced', '${s.delayMinutes} min', icon: Icons.schedule),
                  ]),
                ),
              ),
              SectionTitle('How patients came'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    InfoRow('Booked in the app', '${appts.length - walkIns - phone}', icon: Icons.smartphone),
                    InfoRow('Phone bookings', '$phone', icon: Icons.call_outlined),
                    InfoRow('Walk-ins', '$walkIns', icon: Icons.directions_walk),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                  'Capacity used: ${s.bookedCount} of ${s.capacity} (${s.capacity == 0 ? 0 : (s.bookedCount * 100 / s.capacity).round()}%). '
                  'Average consultation time is measured from "Call next" to the next call or "Finish".',
                  style: t.bodySmall),
            ],
          );
        },
      ),
    );
  }
}
