import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/appointment.dart';
import '../../services/db.dart';
import '../../services/feedback_service.dart';

/// Staff reports: how busy the OPD was, who came, and who did not.
/// Computed from the appointments of the chosen period (READ only).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _days = 7;
  late Future<List<Appointment>> _future = _load();
  late Future<List<VisitFeedback>> _feedback = FeedbackService.recent(_days);

  Future<List<Appointment>> _load() async {
    final end = DateKeys.dayOnly(DateTime.now()).add(const Duration(days: 1));
    final start = end.subtract(Duration(days: _days));
    final q = await Db.appointments
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    return q.docs.map(Appointment.fromDoc).toList();
  }

  void _setDays(int d) => setState(() {
        _days = d;
        _future = _load();
        _feedback = FeedbackService.recent(d);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _future = _load()),
          ),
        ],
      ),
      body: FutureBuilder<List<Appointment>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView(message: 'Crunching numbers…');
          if (snap.hasError) {
            return ErrorView(error: snap.error!, onRetry: () => setState(() => _future = _load()));
          }
          return _Report(days: _days, items: snap.data!, onDays: _setDays, feedback: _feedback);
        },
      ),
    );
  }
}

class _Report extends StatelessWidget {
  final int days;
  final List<Appointment> items;
  final ValueChanged<int> onDays;
  final Future<List<VisitFeedback>> feedback;
  const _Report({required this.days, required this.items, required this.onDays, required this.feedback});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    int count(String status) => items.where((a) => a.status == status).length;
    final total = items.length;
    final completed = count(AppointmentStatus.completed);
    final cancelled = count(AppointmentStatus.cancelled);
    final noShow = count(AppointmentStatus.noShow);
    // No-show rate only counts bookings that reached the clinic day.
    final decided = completed + noShow;
    final noShowRate = decided == 0 ? 0 : (noShow * 100 / decided).round();
    final priority = items.where((a) => a.priority).length;

    final byChannel = <String, int>{};
    for (final a in items) {
      final label = const {'walkIn': 'Walk-in', 'phone': 'Phone'}[a.channel] ?? 'App';
      byChannel[label] = (byChannel[label] ?? 0) + 1;
    }
    final byDept = <String, int>{};
    for (final a in items) {
      byDept[a.department] = (byDept[a.department] ?? 0) + 1;
    }
    final deptList = byDept.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final today = DateKeys.dayOnly(DateTime.now());
    final dayCounts = <DateTime, int>{
      for (var i = days - 1; i >= 0; i--) today.subtract(Duration(days: i)): 0,
    };
    for (final a in items) {
      final d = DateKeys.dayOnly(a.date);
      if (dayCounts.containsKey(d)) dayCounts[d] = dayCounts[d]! + 1;
    }
    final maxDay = dayCounts.values.fold<int>(1, (m, v) => v > m ? v : m);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7 days')),
            ButtonSegment(value: 14, label: Text('14 days')),
            ButtonSegment(value: 30, label: Text('30 days')),
          ],
          selected: {days},
          onSelectionChanged: (v) => onDays(v.first),
        ),
        const SizedBox(height: 16),
        if (total == 0)
          const EmptyView(icon: Icons.insert_chart_outlined, message: 'No appointments in this period yet.')
        else ...[
          Row(children: [
            Expanded(child: StatTile(value: '$total', label: 'Appointments', icon: Icons.event_note)),
            const SizedBox(width: 8),
            Expanded(child: StatTile(value: '$completed', label: 'Completed', icon: Icons.check_circle_outline, color: AppColors.success)),
            const SizedBox(width: 8),
            Expanded(child: StatTile(value: '$cancelled', label: 'Cancelled', icon: Icons.event_busy, color: AppColors.n600)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: StatTile(value: '$noShow', label: 'No-shows', icon: Icons.person_off_outlined, color: AppColors.accent)),
            const SizedBox(width: 8),
            Expanded(child: StatTile(value: '$noShowRate%', label: 'No-show rate', icon: Icons.percent, color: noShowRate > 20 ? AppColors.danger : AppColors.accent)),
            const SizedBox(width: 8),
            Expanded(child: StatTile(value: '$priority', label: 'Priority patients', icon: Icons.star_outline, color: AppColors.accent)),
          ]),
          SectionTitle('Appointments per day'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 140,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final e in dayCounts.entries)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                          Text('${e.value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Container(
                            height: 90 * e.value / maxDay + 2,
                            decoration: BoxDecoration(
                              color: e.key == today ? AppColors.accent : AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(days <= 14 ? DateFormat('E').format(e.key).substring(0, 1) : '',
                              style: const TextStyle(fontSize: 11)),
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
          ),
          SectionTitle('Patient satisfaction'),
          FutureBuilder<List<VisitFeedback>>(
            future: feedback,
            builder: (context, snap) {
              final list = snap.data ?? const <VisitFeedback>[];
              if (snap.connectionState != ConnectionState.done) {
                return const Card(child: Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()));
              }
              if (list.isEmpty) {
                return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No ratings yet in this period.')));
              }
              final avg = list.fold<int>(0, (a, f) => a + f.rating) / list.length;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Text(avg.toStringAsFixed(1), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          for (var i = 1; i <= 5; i++)
                            Icon(i <= avg.round() ? Icons.star : Icons.star_border, color: AppColors.accent),
                        ]),
                        Text('${list.length} rating${list.length == 1 ? '' : 's'}', style: t.bodySmall),
                      ]),
                    ),
                  ]),
                ),
              );
            },
          ),
          SectionTitle('By clinic'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                for (final e in deptList.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Expanded(flex: 3, child: Text(e.key.isEmpty ? 'Unknown' : e.key, overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 4, child: MeterBar(value: e.value / deptList.first.value, color: AppColors.primary)),
                      SizedBox(width: 36, child: Text('${e.value}', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold))),
                    ]),
                  ),
              ]),
            ),
          ),
          SectionTitle('How patients booked'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                for (final e in byChannel.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Expanded(flex: 3, child: Text(e.key)),
                      Expanded(flex: 4, child: MeterBar(value: e.value / total, color: AppColors.primaryDark)),
                      SizedBox(
                          width: 56,
                          child: Text('${(e.value * 100 / total).round()}%',
                              textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold))),
                    ]),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text(
              'Average ${(total / days).toStringAsFixed(1)} appointments per day over the last $days days. '
              'The no-show rate is no-shows ÷ (completed + no-shows).',
              style: t.bodySmall),
        ],
      ],
    );
  }
}
