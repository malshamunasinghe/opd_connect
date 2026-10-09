import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/appointment.dart';
import '../../services/queue_service.dart';

/// S12 - Mark no-show and close token (F5).
/// Patient Q8: 33.3% had missed their turn, which leaves stale entries that
/// block the queue. Staff can close them, bring a late patient back, or
/// delete a token issued in error.
/// Owner: P.A.J. Sithmini (IT23671874)
/// CRUD: READ waiting + no-show tokens; UPDATE (mark no-show / re-queue);
///       DELETE (token issued in error).
class NoShowScreen extends StatefulWidget {
  final String sessionId;
  const NoShowScreen({super.key, required this.sessionId});

  @override
  State<NoShowScreen> createState() => _NoShowScreenState();
}

class _NoShowScreenState extends State<NoShowScreen> {
  late final _stream = QueueService.sessionAppointments(widget.sessionId);

  Future<void> _markNoShow(Appointment a) async {
    final ok = await confirm(context,
        title: 'Close ${a.tokenLabel}?',
        message: '${a.patientName} will be removed from the queue and marked as a no-show.',
        confirmLabel: 'Mark no-show',
        danger: true);
    if (ok && mounted) {
      await runGuarded(context, () => QueueService.markNoShow(a), success: '${a.tokenLabel} closed');
    }
  }

  Future<void> _requeue(Appointment a) async {
    await runGuarded(context, () => QueueService.requeue(a),
        success: '${a.tokenLabel} is back at the end of the queue');
  }

  Future<void> _delete(Appointment a) async {
    final ok = await confirm(context,
        title: 'Delete ${a.tokenLabel}?',
        message: 'Only delete a token that was issued by mistake. This cannot be undone.',
        confirmLabel: 'Delete',
        danger: true);
    if (ok && mounted) {
      await runGuarded(context, () => QueueService.deleteToken(a), success: '${a.tokenLabel} deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('No-shows'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'Close a token'), Tab(text: 'Closed tokens')],
          ),
        ),
        body: StreamView<List<Appointment>>(
          stream: _stream,
          builder: (context, appts) {
            final open = appts.where((a) => a.isActive).toList();
            final closed = appts.where((a) => a.status == AppointmentStatus.noShow).toList();
            return TabBarView(children: [
              open.isEmpty
                  ? const EmptyView(icon: Icons.inbox, message: 'No open tokens.')
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final a in open)
                          _Row(
                            a: a,
                            subtitle: '${a.status == AppointmentStatus.serving ? 'With doctor' : 'Waiting'}'
                                ' · ${a.arrived ? 'arrived' : 'not confirmed as arrived'}',
                            actions: [
                              IconButton(
                                tooltip: 'Mark no-show',
                                icon: const Icon(Icons.person_off, color: AppColors.accent),
                                onPressed: () => _markNoShow(a),
                              ),
                              IconButton(
                                tooltip: 'Delete token (issued in error)',
                                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                onPressed: () => _delete(a),
                              ),
                            ],
                          ),
                      ],
                    ),
              closed.isEmpty
                  ? const EmptyView(icon: Icons.check_circle_outline, message: 'No no-shows in this session.')
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final a in closed)
                          _Row(
                            a: a,
                            subtitle: 'No-show',
                            actions: [
                              TextButton.icon(
                                icon: const Icon(Icons.replay),
                                label: const Text('Re-queue'),
                                onPressed: () => _requeue(a),
                              ),
                              IconButton(
                                tooltip: 'Delete token',
                                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                onPressed: () => _delete(a),
                              ),
                            ],
                          ),
                      ],
                    ),
            ]);
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final Appointment a;
  final String subtitle;
  final List<Widget> actions;
  const _Row({required this.a, required this.subtitle, required this.actions});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(children: [
              TokenChip(a.tokenLabel, fontSize: 16, filled: a.isActive),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.patientName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
              ...actions,
            ]),
          ),
        ),
      );
}
