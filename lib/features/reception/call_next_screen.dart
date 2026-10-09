import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/appointment.dart';
import '../../models/clinic_session.dart';
import '../../services/db.dart';
import '../../services/queue_service.dart';
import '../../services/schedule_service.dart';

/// S11 - Call next patient (F5).
/// One large button replaces shouting names across the waiting area. The
/// finished consultation is written to the patient's visit history (F3) and
/// the next patients get "near turn" / "your turn" notifications (F4).
/// Owner: P.A.J. Sithmini (IT23671874)
/// CRUD: READ current/next patients; UPDATE statuses + queue;
///       CREATE visit record and notifications.
class CallNextScreen extends StatefulWidget {
  final String sessionId;
  const CallNextScreen({super.key, required this.sessionId});

  @override
  State<CallNextScreen> createState() => _CallNextScreenState();
}

class _CallNextScreenState extends State<CallNextScreen> {
  bool _busy = false;
  late final _sessionStream = ScheduleService.session(widget.sessionId);
  late final _apptStream = QueueService.sessionAppointments(widget.sessionId);

  Future<void> _callNext() async {
    setState(() => _busy = true);
    try {
      final label = await QueueService.callNext(widget.sessionId);
      if (mounted) showSnack(context, label == null ? 'Queue is empty' : 'Now calling $label');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    setState(() => _busy = true);
    await runGuarded(context, () => QueueService.completeCurrent(widget.sessionId), success: 'Consultation completed');
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _noShow(Appointment a) async {
    final ok = await confirm(context,
        title: 'Mark ${a.tokenLabel} as no-show?',
        message: '${a.patientName} did not respond. The token will be closed; '
            'you can put them back in the queue from the No-shows list if they return.',
        confirmLabel: 'Mark no-show',
        danger: true);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    await runGuarded(context, () => QueueService.markNoShow(a), success: '${a.tokenLabel} marked as no-show');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Call next patient')),
      body: StreamView<ClinicSession?>(
        stream: _sessionStream,
        builder: (context, s) {
          if (s == null) return const EmptyView(icon: Icons.event_busy, message: 'Session not found');
          return StreamView<List<Appointment>>(
            stream: _apptStream,
            builder: (context, appts) {
              final byId = {for (final a in appts) a.id: a};
              final current = s.currentServingId == null ? null : byId[s.currentServingId];
              final upNext = [
                for (final id in s.waitingIds.take(3))
                  if (byId[id] != null) byId[id]!
              ];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('${s.department} · ${s.room}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Card(
                    color: current == null ? null : AppColors.success,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        Text('With the doctor',
                            style: TextStyle(color: current == null ? AppColors.n600 : Colors.white70)),
                        const SizedBox(height: 8),
                        Text(current?.tokenLabel ?? '—',
                            style: TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                color: current == null ? AppColors.n400 : Colors.white)),
                        if (current != null) ...[
                          Text(current.patientName, style: const TextStyle(color: Colors.white, fontSize: 18)),
                          if (current.priority)
                            Text('★ ${current.priorityReason ?? 'Priority'}',
                                style: const TextStyle(color: Colors.white)),
                        ],
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 72,
                    child: PrimaryButton(
                      s.waitingIds.isEmpty
                          ? (current == null ? 'Queue is empty' : 'Finish (nobody waiting)')
                          : 'Call next: ${upNext.isNotEmpty ? upNext.first.tokenLabel : ''}',
                      icon: Icons.campaign,
                      loading: _busy,
                      onPressed: !s.isActive
                          ? null
                          : (s.waitingIds.isEmpty ? (current == null ? null : _complete) : _callNext),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (current != null)
                    Row(children: [
                      Expanded(
                        child: SecondaryButton('Complete only', icon: Icons.done, onPressed: _busy ? null : _complete),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DangerButton('No-show',
                            icon: Icons.person_off, onPressed: _busy ? null : () => _noShow(current)),
                      ),
                    ]),
                  const SizedBox(height: 24),
                  const SectionTitle('Up next'),
                  if (upNext.isEmpty) const Text('Nobody is waiting.'),
                  for (final a in upNext)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: TokenChip(a.tokenLabel,
                              fontSize: 16, color: a.priority ? AppColors.accent : AppColors.primary),
                          title: Text(a.patientName),
                          subtitle: Text(a.arrived ? 'Arrived' : 'Not confirmed as arrived'),
                          trailing: Icon(a.arrived ? Icons.how_to_reg : Icons.help_outline,
                              color: a.arrived ? AppColors.success : AppColors.accent),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
