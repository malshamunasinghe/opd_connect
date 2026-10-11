import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/clinic_session.dart';
import '../../services/schedule_service.dart';
import 'create_session_screen.dart';
import 'edit_session_screen.dart';

/// S19 - Weekly clinic schedule (F1, F4). The notification centre half of
/// S19 is notification_centre_screen.dart.
/// Owner: Nethmini K (IT23669130)
/// CRUD: READ sessions for the week (live). Tapping a session opens S20.
/// Admins also get an Edit / Delete menu on every session; Delete removes the
/// clinic and its bookings from the database.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _weekStart = DateKeys.startOfWeek(DateTime.now());
  late Stream<List<ClinicSession>> _stream = ScheduleService.week(_weekStart);
  String? _hospitalFilter;

  void _shift(int weeks) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * weeks));
      _stream = ScheduleService.week(_weekStart);
    });
  }

  @override
  Widget build(BuildContext context) {
    final end = _weekStart.add(const Duration(days: 6));
    final range = '${DateFormat('d MMM').format(_weekStart)} – ${DateFormat('d MMM yyyy').format(end)}';
    return Scaffold(
      appBar: AppBar(title: const Text('Clinic schedule')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateSessionScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New session'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(children: [
            IconButton(tooltip: 'Previous week', icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
            Expanded(
              child: Text(range, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(tooltip: 'Next week', icon: const Icon(Icons.chevron_right), onPressed: () => _shift(1)),
          ]),
        ),
        Expanded(
          child: StreamView<List<ClinicSession>>(
            stream: _stream,
            builder: (context, sessions) {
              final hospitals = sessions.map((x) => x.hospitalName).toSet().toList()..sort();
              final filter = hospitals.contains(_hospitalFilter) ? _hospitalFilter : null;
              final shown = sessions.where((x) => filter == null || x.hospitalName == filter).toList();
              return Column(children: [
                if (hospitals.length > 1)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('All hospitals'),
                          selected: filter == null,
                          onSelected: (_) => setState(() => _hospitalFilter = null),
                        ),
                      ),
                      for (final h in hospitals)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(h),
                            selected: filter == h,
                            onSelected: (_) => setState(() => _hospitalFilter = h),
                          ),
                        ),
                    ]),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      for (var d = 0; d < 7; d++) ..._day(context, _weekStart.add(Duration(days: d)), shown),
                    ],
                  ),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }

  List<Widget> _day(BuildContext context, DateTime day, List<ClinicSession> all) {
    final key = DateKeys.of(day);
    final items = all.where((x) => x.dateKey == key).toList();
    final isToday = key == DateKeys.of(DateTime.now());
    final admin = context.watch<CurrentUser>().profile?.isAdmin ?? false;
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Row(children: [
          Text(DateFormat('EEEE, d MMM').format(day),
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: isToday ? AppColors.primary : AppColors.n900)),
          if (isToday) const Text('  · Today', style: TextStyle(color: AppColors.primary)),
          const Spacer(),
          if (!day.isBefore(DateKeys.dayOnly(DateTime.now())))
            IconButton(
              tooltip: 'Add session on this day',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CreateSessionScreen(initialDate: day))),
            ),
        ]),
      ),
      if (items.isEmpty)
        Text('No sessions', style: Theme.of(context).textTheme.bodySmall)
      else
        for (final x in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditSessionScreen(session: x))),
                leading: Container(
                  width: 6,
                  height: 40,
                  decoration: BoxDecoration(
                    color: x.isActive ? AppColors.primary : AppColors.danger,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                title: Text('${x.startTime}–${x.endTime} · ${x.department}',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, decoration: x.isActive ? null : TextDecoration.lineThrough)),
                subtitle: Text('${x.doctorName} · ${x.hospitalName}'
                    '${x.isActive ? '' : '\nCancelled: ${x.cancelReason ?? ''}'}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('${x.bookedCount}/${x.capacity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Icon(x.remindersEnabled ? Icons.notifications_active : Icons.notifications_off,
                        size: 16, color: AppColors.n600),
                  ]),
                  if (admin)
                    PopupMenuButton<String>(
                      tooltip: 'Clinic actions',
                      onSelected: (v) {
                        if (v == 'edit') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => EditSessionScreen(session: x)));
                        } else {
                          deleteClinicWithConfirm(context, x);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit clinic')),
                        PopupMenuItem(value: 'delete', child: Text('Delete clinic')),
                      ],
                    ),
                ]),
              ),
            ),
          ),
    ];
  }
}
