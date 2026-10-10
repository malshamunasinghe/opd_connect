import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/app_settings.dart';
import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/appointment.dart';
import '../../services/booking_service.dart';
import 'book_hospital_screen.dart';
import 'cancel_appointment_screen.dart';
import 'live_queue_screen.dart';
import 'reschedule_screen.dart';

/// S04 - My appointments (F1, NF2).
/// Upcoming and past tabs with search and filters; the next appointment is
/// highlighted and every card has its actions on it.
/// Owner: Lakmali M.A.D.M (IT23679344)
/// CRUD: READ the patient's appointments; DELETE past entries from history.
class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  late final Stream<List<Appointment>> _stream = BookingService.myAppointments(me(context).uid);
  final _search = TextEditingController();
  String _query = '';
  String _upFilter = 'all'; // all | today | week
  String _pastFilter = 'all'; // all | completed | cancelled | missed

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Appointment a) {
    if (_query.isEmpty) return true;
    return a.department.toLowerCase().contains(_query) ||
        a.hospitalName.toLowerCase().contains(_query) ||
        a.doctorName.toLowerCase().contains(_query) ||
        a.tokenLabel.toLowerCase().contains(_query) ||
        a.reference.toLowerCase().contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.t('appointments')),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [Tab(text: s.t('upcoming')), Tab(text: s.t('past'))],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookHospitalScreen())),
          icon: const Icon(Icons.add),
          label: Text(s.t('bookAppointment')),
        ),
        body: StreamView<List<Appointment>>(
          stream: _stream,
          loadingMessage: s.t('loading'),
          builder: (context, all) {
            final today = DateKeys.of(DateTime.now());
            final weekEnd = DateKeys.dayOnly(DateTime.now()).add(const Duration(days: 7));
            var upcoming = all.where((a) => a.isActive).toList();
            var past = all.where((a) => !a.isActive).toList().reversed.toList();
            final upTotal = upcoming.length;
            final pastTotal = past.length;

            upcoming = upcoming.where(_matches).where((a) {
              if (_upFilter == 'today') return a.dateKey == today;
              if (_upFilter == 'week') return a.date.isBefore(weekEnd);
              return true;
            }).toList();
            past = past.where(_matches).where((a) {
              switch (_pastFilter) {
                case 'completed':
                  return a.status == AppointmentStatus.completed;
                case 'cancelled':
                  return a.status == AppointmentStatus.cancelled;
                case 'missed':
                  return a.status == AppointmentStatus.noShow;
                default:
                  return true;
              }
            }).toList();

            return Column(children: [
              if (upTotal + pastTotal > 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: s.t('searchAppts'),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                _search.clear();
                                _query = '';
                              }),
                            ),
                    ),
                  ),
                ),
              Expanded(
                child: TabBarView(children: [
                  _UpcomingList(
                    items: upcoming,
                    total: upTotal,
                    filter: _upFilter,
                    onFilter: (f) => setState(() => _upFilter = f),
                  ),
                  _PastList(
                    items: past,
                    total: pastTotal,
                    filter: _pastFilter,
                    onFilter: (f) => setState(() => _pastFilter = f),
                  ),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  const _FilterRow({required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final e in options.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(e.value),
                selected: selected == e.key,
                onSelected: (_) => onSelected(e.key),
              ),
            ),
        ]),
      );
}

class _UpcomingList extends StatelessWidget {
  final List<Appointment> items;
  final int total;
  final String filter;
  final ValueChanged<String> onFilter;
  const _UpcomingList({required this.items, required this.total, required this.filter, required this.onFilter});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    if (total == 0) {
      // Empty state from M02: a clear next action, not a blank screen.
      return const _NoAppointments();
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        _FilterRow(
          options: {'all': s.t('all'), 'today': s.t('today'), 'week': s.t('next7')},
          selected: filter,
          onSelected: onFilter,
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(s.t('noApptMatch'), textAlign: TextAlign.center),
          ),
        for (var i = 0; i < items.length; i++) ...[
          _upcomingCard(context, s, items[i], i == 0 && filter == 'all'),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _upcomingCard(BuildContext context, AppSettings s, Appointment a, bool first) {
    final canChange = a.status == AppointmentStatus.waiting;
    void openQueue() =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => LiveQueueScreen(appointmentId: a.id)));
    return AppointmentCard(
      appointment: a,
      highlight: first,
      statusText: s.t('status_${a.status}'),
      onTap: openQueue,
      footer: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (a.visitReason.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              const Icon(Icons.notes, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(a.visitReason, style: Theme.of(context).textTheme.bodySmall)),
            ]),
          ),
        PrimaryButton(s.t('viewLiveQueue'), icon: Icons.people_alt_outlined, onPressed: openQueue),
        if (canChange) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: SecondaryButton(
                s.t('reschedule'),
                icon: Icons.edit_calendar,
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RescheduleScreen(appointment: a))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SecondaryButton(
                s.t('cancel'),
                icon: Icons.event_busy,
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => CancelAppointmentScreen(appointment: a))),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _NoAppointments extends StatelessWidget {
  const _NoAppointments();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.event_available, size: 64, color: AppColors.n400),
          const SizedBox(height: 16),
          Text(s.t('noApptsTitle'), textAlign: TextAlign.center, style: t.titleLarge),
          const SizedBox(height: 8),
          Text(s.t('noApptsBody'), textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: AppColors.n600)),
          const SizedBox(height: 24),
          PrimaryButton(
            s.t('bookAppointment'),
            icon: Icons.add,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookHospitalScreen())),
          ),
        ]),
      ),
    );
  }
}

class _PastList extends StatelessWidget {
  final List<Appointment> items;
  final int total;
  final String filter;
  final ValueChanged<String> onFilter;
  const _PastList({required this.items, required this.total, required this.filter, required this.onFilter});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    if (total == 0) return EmptyView(icon: Icons.history, message: s.t('noPast'));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        _FilterRow(
          options: {
            'all': s.t('all'),
            'completed': s.t('status_completed'),
            'cancelled': s.t('status_cancelled'),
            'missed': s.t('status_noShow'),
          },
          selected: filter,
          onSelected: onFilter,
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(s.t('noApptMatch'), textAlign: TextAlign.center),
          ),
        for (final a in items) ...[
          AppointmentCard(
            appointment: a,
            statusText: s.t('status_${a.status}'),
            footer: Row(children: [
              if (a.cancelReason != null && a.cancelReason!.isNotEmpty)
                Expanded(child: Text(a.cancelReason!, style: Theme.of(context).textTheme.bodySmall))
              else
                const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: Text(s.t('removeFromList')),
                onPressed: () async {
                  final ok = await confirm(context,
                      title: s.t('removeFromList'),
                      message: '${a.tokenLabel} · ${a.department} · ${formatDay(a.date)}\n\n${s.t('removePermanent')}',
                      confirmLabel: s.t('removeFromList'),
                      cancelLabel: s.t('back'),
                      danger: true);
                  if (ok && context.mounted) {
                    await runGuarded(context, () => BookingService.deleteFromHistory(a));
                  }
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
