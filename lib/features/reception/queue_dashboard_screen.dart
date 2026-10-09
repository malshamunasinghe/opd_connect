import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/appointment.dart';
import '../../models/clinic_session.dart';
import '../../services/db.dart';
import '../../services/queue_service.dart';
import '../schedule/create_session_screen.dart';
import 'call_next_screen.dart';
import 'check_in_screen.dart';
import 'manage_queue_sheet.dart';
import 'no_show_screen.dart';
import 'priority_sheet.dart';
import 'queue_board_screen.dart';
import 'session_summary_screen.dart';
import 'walk_in_screen.dart';

/// S08 - Reception queue console (F2, F5).
///
/// The Schedule tab is for PLANNING (which clinics run on which days). This
/// tab is for OPERATING the clinics that are running now, the way an OPD
/// counter works through the day:
///   1. pick the clinic you are looking after,
///   2. check patients in as they arrive (or add walk-ins),
///   3. call the next patient who is actually here,
///   4. deal with people who do not respond (skip / no-show),
///   5. react to the day (doctor late, break, announcements),
///   6. read the summary at the end.
/// Every change appears on patients' phones within the same second (NF4).
/// Owner: P.A.J. Sithmini (IT23671874)
/// CRUD: READ sessions + queue (live); UPDATE queue order / arrived flag.
class QueueDashboardScreen extends StatefulWidget {
  /// Optional: open on a given day / clinic (used by the Overview shortcuts).
  /// When opened that way it is a normal pushed screen, so it gets a back arrow.
  final DateTime? initialDay;
  final String? initialSessionId;
  const QueueDashboardScreen({super.key, this.initialDay, this.initialSessionId});

  @override
  State<QueueDashboardScreen> createState() => _QueueDashboardScreenState();
}

class _QueueDashboardScreenState extends State<QueueDashboardScreen> {
  late DateTime _day = DateKeys.dayOnly(widget.initialDay ?? DateTime.now());
  late String? _sessionId = widget.initialSessionId;

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (d != null) _goToDay(d);
  }

  void _goToDay(DateTime d) => setState(() {
        _day = DateKeys.dayOnly(d);
        _sessionId = null;
      });

  Future<void> _jumpToNextClinic() async {
    final next = await QueueService.nextClinicDay(DateTime.now());
    if (!mounted) return;
    if (next == null) {
      showSnack(context, 'No upcoming clinic sessions. Create one first.', error: true);
    } else {
      _goToDay(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _day == DateKeys.dayOnly(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live queue'),
        actions: [
          IconButton(
            tooltip: 'Previous day',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _goToDay(_day.subtract(const Duration(days: 1))),
          ),
          TextButton(
            onPressed: _pickDay,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: Text(isToday ? 'Today' : formatDay(_day)),
          ),
          IconButton(
            tooltip: 'Next day',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _goToDay(_day.add(const Duration(days: 1))),
          ),
        ],
      ),
      body: StreamView<List<ClinicSession>>(
        stream: QueueService.sessionsOn(_day),
        builder: (context, sessions) {
          if (sessions.isEmpty) return _EmptyDay(day: _day, isToday: isToday, onJump: _jumpToNextClinic, onToday: () => _goToDay(DateTime.now()));
          final selected = sessions.firstWhere((x) => x.id == _sessionId, orElse: () => sessions.first);
          return Column(children: [
            _SessionPicker(
              sessions: sessions,
              selectedId: selected.id,
              onPick: (id) => setState(() => _sessionId = id),
            ),
            Expanded(child: _Console(key: ValueKey(selected.id), session: selected)),
          ]);
        },
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final VoidCallback onJump;
  final VoidCallback onToday;
  const _EmptyDay({required this.day, required this.isToday, required this.onJump, required this.onToday});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.event_busy, size: 64, color: AppColors.n400),
          const SizedBox(height: 16),
          Text(isToday ? 'No clinics are running today.' : 'No clinics on ${formatDay(day)}.',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'This tab runs the live queue for a clinic. Clinics are planned in the Schedule tab; '
            'as soon as one exists for the day it appears here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          PrimaryButton('Create a clinic for ${isToday ? 'today' : formatDay(day)}',
              icon: Icons.add,
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => CreateSessionScreen(initialDate: day)))),
          const SizedBox(height: 12),
          SecondaryButton('Jump to the next clinic day', icon: Icons.skip_next, onPressed: onJump),
          if (!isToday) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onToday, child: const Text('Back to today')),
          ],
        ]),
      ),
    );
  }
}

/// Horizontal strip with one card per clinic of the day.
class _SessionPicker extends StatelessWidget {
  final List<ClinicSession> sessions;
  final String selectedId;
  final ValueChanged<String> onPick;
  const _SessionPicker({required this.sessions, required this.selectedId, required this.onPick});

  ({String text, Color color}) _state(ClinicSession s) {
    if (!s.isActive) return (text: 'Cancelled', color: AppColors.danger);
    if (s.paused) return (text: 'Paused', color: AppColors.danger);
    if (s.currentServingId != null) return (text: 'Live', color: AppColors.success);
    if (DateKeys.hasEnded(s.date, s.endTime)) return (text: 'Ended', color: AppColors.n600);
    return (text: 'Not started', color: AppColors.accent);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        itemCount: sessions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = sessions[i];
          final sel = s.id == selectedId;
          final st = _state(s);
          return Semantics(
            button: true,
            selected: sel,
            label: '${s.department} ${s.startTime}, ${st.text}, ${s.waitingIds.length} waiting',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSizes.radius),
              onTap: () => onPick(s.id),
              child: Container(
                width: 170,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primaryDark : Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radius),
                  border: Border.all(color: sel ? AppColors.primaryDark : AppColors.n200),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.department,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, color: sel ? Colors.white : AppColors.n900)),
                  Text('${s.startTime} · ${s.hospitalName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: sel ? Colors.white70 : AppColors.n600)),
                  const Spacer(),
                  Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: st.color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(st.text,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : st.color)),
                    const Spacer(),
                    Text('${s.waitingIds.length} waiting',
                        style: TextStyle(fontSize: 12, color: sel ? Colors.white : AppColors.n900)),
                  ]),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The working area for one clinic.
class _Console extends StatefulWidget {
  final ClinicSession session;
  const _Console({super.key, required this.session});

  @override
  State<_Console> createState() => _ConsoleState();
}

class _ConsoleState extends State<_Console> {
  final _search = TextEditingController();
  String _query = '';
  String _view = 'ready'; // ready | notHere | done | missed
  bool _busy = false;
  late final Stream<List<Appointment>> _appts = QueueService.sessionAppointments(widget.session.id);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Appointment a) {
    if (_query.isEmpty) return true;
    return a.tokenLabel.toLowerCase().contains(_query) ||
        a.patientName.toLowerCase().contains(_query) ||
        a.patientPhone.contains(_query) ||
        a.patientNic.toLowerCase().contains(_query) ||
        a.reference.toLowerCase().contains(_query);
  }

  Future<void> _call(Appointment? target, {bool confirmAbsent = false}) async {
    if (confirmAbsent && target != null && !target.arrived) {
      final ok = await confirm(context,
          title: 'Call ${target.tokenLabel}?',
          message: '${target.patientName} has not checked in yet. Call them anyway?',
          confirmLabel: 'Call anyway');
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final label = await QueueService.callNext(widget.session.id, appointmentId: target?.id);
      if (mounted) showSnack(context, label == null ? 'Queue is empty' : 'Now calling $label');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishOnly() async {
    setState(() => _busy = true);
    await runGuarded(context, () => QueueService.completeCurrent(widget.session.id), success: 'Consultation finished');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session; // live: the parent listens to the day's sessions
    return StreamView<List<Appointment>>(
      stream: _appts,
      builder: (context, appts) {
        final byId = {for (final a in appts) a.id: a};
        final waiting = [
          for (final id in s.waitingIds)
            if (byId[id] != null) byId[id]!
        ];
        final ready = waiting.where((a) => a.arrived).toList();
        final notHere = waiting.where((a) => !a.arrived).toList();
        final serving = s.currentServingId == null ? null : byId[s.currentServingId];
        final done = appts.where((a) => a.status == AppointmentStatus.completed).toList();
        final missed = appts
            .where((a) => a.status == AppointmentStatus.noShow || a.status == AppointmentStatus.cancelled)
            .toList();
        final priorityIds = waiting.where((a) => a.priority).map((a) => a.id).toSet();

        // Who should be called next: the first patient who is actually here,
        // otherwise whoever is at the front.
        final target = ready.isNotEmpty ? ready.first : (waiting.isNotEmpty ? waiting.first : null);
        final canCall = s.isActive && !s.paused && !_busy;

        return Stack(children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              if (!s.isActive)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InfoBanner(
                      icon: Icons.event_busy,
                      color: AppColors.danger,
                      message: 'This clinic was cancelled: ${s.cancelReason ?? ''}'),
                ),
              if (s.paused)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InfoBanner(
                    icon: Icons.pause_circle_outline,
                    color: AppColors.danger,
                    message: 'Queue paused: ${s.pauseReason}',
                    action: TextButton(
                      onPressed: () =>
                          runGuarded(context, () => QueueService.setPaused(s, false), success: 'Queue resumed'),
                      child: const Text('Resume'),
                    ),
                  ),
                ),
              if (s.delayMinutes > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InfoBanner(
                    icon: Icons.schedule,
                    color: AppColors.accent,
                    message: 'Running ${s.delayMinutes} minutes late. Patients have been told.',
                  ),
                ),
              Text(
                '${s.hospitalName} · ${s.doctorName}${s.room.isEmpty ? '' : ' · ${s.room}'} · ${s.startTime}–${s.endTime}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              // ---- NOW SERVING / call
              _NowServing(
                session: s,
                serving: serving,
                target: target,
                hasWaiting: waiting.isNotEmpty,
                canCall: canCall,
                busy: _busy,
                onCall: () => _call(target, confirmAbsent: target != null && !target.arrived),
                onFinishOnly: _finishOnly,
                onNoShow: serving == null
                    ? null
                    : () async {
                        final ok = await confirm(context,
                            title: 'Mark ${serving.tokenLabel} as no-show?',
                            message: '${serving.patientName} did not respond. Their token will be closed.',
                            confirmLabel: 'No-show',
                            danger: true);
                        if (ok && context.mounted) {
                          await runGuarded(context, () => QueueService.markNoShow(serving));
                        }
                      },
              ),
              const SizedBox(height: 12),
              // ---- counter actions
              Wrap(spacing: 8, runSpacing: 8, children: [
                _Action(
                  icon: Icons.person_add_alt_1,
                  label: 'Walk-in',
                  onTap: s.isActive
                      ? () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => WalkInScreen(session: s, priorityIds: priorityIds)))
                      : null,
                ),
                _Action(
                  icon: Icons.qr_code_scanner,
                  label: 'Check-in desk',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckInScreen())),
                ),
                _Action(
                  icon: Icons.tune,
                  label: 'Delay / pause / message',
                  onTap: s.isActive ? () => showManageQueueSheet(context, s) : null,
                ),
                _Action(
                  icon: Icons.tv,
                  label: 'Display board',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QueueBoardScreen(session: s))),
                ),
                _Action(
                  icon: Icons.person_off_outlined,
                  label: 'No-shows (${missed.length})',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoShowScreen(sessionId: s.id))),
                ),
                _Action(
                  icon: Icons.campaign_outlined,
                  label: 'Call screen',
                  onTap: s.isActive
                      ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => CallNextScreen(sessionId: s.id)))
                      : null,
                ),
                _Action(
                  icon: Icons.assessment_outlined,
                  label: 'Summary',
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => SessionSummaryScreen(session: s))),
                ),
              ]),
              const SizedBox(height: 12),
              // ---- numbers
              Row(children: [
                Expanded(child: StatTile(value: '${ready.length}', label: 'Ready (here)', color: AppColors.success)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(value: '${notHere.length}', label: 'Not here yet', color: AppColors.accent)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(value: '${done.length}', label: 'Seen', color: AppColors.primary)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(value: '${s.bookedCount}/${s.capacity}', label: 'Booked', color: AppColors.n600)),
              ]),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 'ready', label: Text('Ready ${ready.length}')),
                  ButtonSegment(value: 'notHere', label: Text('Not here ${notHere.length}')),
                  ButtonSegment(value: 'done', label: Text('Done ${done.length}')),
                  ButtonSegment(value: 'missed', label: Text('Missed ${missed.length}')),
                ],
                selected: {_view},
                onSelectionChanged: (v) => setState(() => _view = v.first),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Find by token, name, NIC, phone or OPD-reference',
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
              const SizedBox(height: 8),
              ..._list(context, waiting, ready, notHere, done, missed, priorityIds, canCall),
            ],
          ),
          if (s.isActive)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => WalkInScreen(session: s, priorityIds: priorityIds)),
                ),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Walk-in / phone'),
              ),
            ),
        ]);
      },
    );
  }

  List<Widget> _list(
    BuildContext context,
    List<Appointment> waiting,
    List<Appointment> ready,
    List<Appointment> notHere,
    List<Appointment> done,
    List<Appointment> missed,
    Set<String> priorityIds,
    bool canCall,
  ) {
    final t = Theme.of(context).textTheme;
    Widget empty(String text) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center, style: t.bodySmall),
        );

    if (_view == 'done' || _view == 'missed') {
      final list = (_view == 'done' ? done : missed).where(_matches).toList()
        ..sort((a, b) => b.tokenNumber.compareTo(a.tokenNumber));
      if (list.isEmpty) return [empty(_view == 'done' ? 'Nobody has been seen yet.' : 'No missed or cancelled patients.')];
      return [
        for (final a in list)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: TokenChip(a.tokenLabel, filled: false, fontSize: 15),
              title: Text(a.patientName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                _view == 'done'
                    ? [
                        if (a.calledAt != null) 'Called ${DateFormat('h:mm a').format(a.calledAt!)}',
                        if (a.calledAt != null && a.completedAt != null)
                          '${a.completedAt!.difference(a.calledAt!).inMinutes} min with doctor',
                      ].join(' · ')
                    : (a.status == AppointmentStatus.noShow
                        ? 'No-show'
                        : 'Cancelled${a.cancelReason == null ? '' : ': ${a.cancelReason}'}'),
                style: t.bodySmall,
              ),
              trailing: _view == 'missed'
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      if (a.status == AppointmentStatus.noShow)
                        TextButton(
                          onPressed: () => runGuarded(context, () => QueueService.requeue(a),
                              success: '${a.tokenLabel} is back in the queue'),
                          child: const Text('Re-queue'),
                        ),
                      // DELETE: remove a token that was issued in error.
                      IconButton(
                        tooltip: 'Delete token',
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        onPressed: () async {
                          final ok = await confirm(context,
                              title: 'Delete ${a.tokenLabel}?',
                              message: 'This removes the token for ${a.patientName} permanently. '
                                  'Use it only for a token issued by mistake.',
                              confirmLabel: 'Delete',
                              danger: true);
                          if (ok && context.mounted) {
                            await runGuarded(context, () => QueueService.deleteToken(a),
                                success: '${a.tokenLabel} deleted');
                          }
                        },
                      ),
                    ])
                  : null,
            ),
          ),
      ];
    }

    final source = _view == 'ready' ? ready : notHere;
    final shown = source.where(_matches).toList();
    if (shown.isEmpty) {
      return [
        empty(_view == 'ready'
            ? (notHere.isEmpty ? 'Nobody is waiting.' : 'Nobody has checked in yet. Use the Check-in desk or tick patients below.')
            : 'Everyone who booked is here.'),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          _view == 'ready'
              ? 'In calling order. Tap the green phone icon to call a patient now.'
              : 'Booked but not checked in. Tick them when they arrive; call or skip if they are late.',
          style: t.bodySmall,
        ),
      ),
      for (final a in shown)
        _QueueRow(
          position: waiting.indexOf(a) + 1,
          a: a,
          isFirst: waiting.first.id == a.id,
          isLast: waiting.last.id == a.id,
          priorityIds: priorityIds,
          canCall: canCall,
          onCall: () => _call(a, confirmAbsent: !a.arrived),
        ),
    ];
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _Action({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      );
}

/// The big card: who is with the doctor (with a running timer) and the one
/// button reception presses most.
class _NowServing extends StatelessWidget {
  final ClinicSession session;
  final Appointment? serving;
  final Appointment? target;
  final bool hasWaiting;
  final bool canCall;
  final bool busy;
  final VoidCallback onCall;
  final VoidCallback onFinishOnly;
  final VoidCallback? onNoShow;
  const _NowServing({
    required this.session,
    required this.serving,
    required this.target,
    required this.hasWaiting,
    required this.canCall,
    required this.busy,
    required this.onCall,
    required this.onFinishOnly,
    required this.onNoShow,
  });

  String _elapsed(Appointment a) {
    final since = a.calledAt;
    if (since == null) return '';
    final d = DateTime.now().difference(since);
    final m = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cur = serving;
    final tg = target;
    final String label;
    if (tg == null) {
      label = cur == null ? 'Nobody waiting' : 'Finish consultation';
    } else {
      label = '${cur == null ? 'Call' : 'Finish & call'} ${tg.tokenLabel}${tg.arrived ? '' : ' (not here)'}';
    }
    final overTime = cur?.calledAt != null &&
        DateTime.now().difference(cur!.calledAt!).inMinutes > session.avgConsultMinutes * 1.5;

    return Card(
      color: AppColors.primaryDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('NOW SERVING', style: TextStyle(color: Colors.white70, letterSpacing: 2, fontSize: 12)),
                Text(cur?.tokenLabel ?? '—',
                    style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold)),
                if (cur != null) ...[
                  Text(cur.patientName, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  if (cur.priority)
                    Text('★ ${cur.priorityReason ?? 'Priority'}', style: const TextStyle(color: AppColors.accent)),
                ] else
                  const Text('Nobody with the doctor', style: TextStyle(color: Colors.white70)),
              ]),
            ),
            if (cur != null)
              StreamBuilder<int>(
                stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
                builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('with doctor', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(_elapsed(cur),
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: overTime ? AppColors.accent : Colors.white,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                  Text('planned ${session.avgConsultMinutes} min',
                      style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ]),
              ),
          ]),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: AppColors.primaryDark, minimumSize: const Size.fromHeight(56)),
            onPressed: !canCall || (tg == null && cur == null) ? null : (tg == null ? onFinishOnly : onCall),
            icon: busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.campaign),
            label: Text(label),
          ),
          if (cur != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: busy ? null : () => runGuarded(context, () => QueueService.recall(session.id), success: 'Patient called again'),
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('Call again'),
                ),
              ),
              if (tg != null)
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: busy ? null : onFinishOnly,
                    icon: const Icon(Icons.done, size: 18),
                    label: const Text('Finish only'),
                  ),
                ),
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                  onPressed: busy ? null : onNoShow,
                  icon: const Icon(Icons.person_off, size: 18),
                  label: const Text('No-show'),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  final int position;
  final Appointment a;
  final bool isFirst;
  final bool isLast;
  final Set<String> priorityIds;
  final bool canCall;
  final VoidCallback onCall;
  const _QueueRow({
    required this.position,
    required this.a,
    required this.isFirst,
    required this.isLast,
    required this.priorityIds,
    required this.canCall,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        shape: a.priority
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius),
                side: const BorderSide(color: AppColors.accent, width: 2))
            : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          onLongPress: () => showPrioritySheet(context, a, priorityIds),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(children: [
              SizedBox(width: 24, child: Text('$position', style: const TextStyle(fontWeight: FontWeight.bold))),
              TokenChip(a.tokenLabel, fontSize: 16, color: a.priority ? AppColors.accent : AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.patientName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (a.patientNic.isNotEmpty || a.patientAge != null)
                    Text(
                      [
                        if (a.patientNic.isNotEmpty) a.patientNic,
                        if (a.patientAge != null) '${a.patientAge} yrs',
                        if (a.patientGender.isNotEmpty) a.patientGender,
                        if (a.bookedFor == 'other') 'for ${a.relation.isEmpty ? 'relative' : a.relation.toLowerCase()}',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  Wrap(spacing: 6, children: [
                    Text(const {'walkIn': 'Walk-in', 'phone': 'Phone booking'}[a.channel] ?? 'App booking',
                        style: Theme.of(context).textTheme.bodySmall),
                    if (a.priority)
                      Text('★ ${a.priorityReason ?? 'Priority'}',
                          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                ]),
              ),
              IconButton(
                tooltip: a.arrived ? 'Checked in (tap to undo)' : 'Check in',
                icon: Icon(a.arrived ? Icons.how_to_reg : Icons.how_to_reg_outlined,
                    color: a.arrived ? AppColors.success : AppColors.n400),
                onPressed: () => runGuarded(context, () => QueueService.setArrived(a.id, !a.arrived)),
              ),
              IconButton(
                tooltip: 'Call this patient now',
                icon: Icon(Icons.phone_in_talk, color: canCall ? AppColors.success : AppColors.n400),
                onPressed: canCall ? onCall : null,
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (v) async {
                  if (v == 'skip') {
                    final ok = await confirm(context,
                        title: 'Skip ${a.tokenLabel}?',
                        message: '${a.patientName} will move back 3 places and be notified.',
                        confirmLabel: 'Skip');
                    if (ok && context.mounted) await runGuarded(context, () => QueueService.skip(a));
                  } else if (v == 'noshow') {
                    final ok = await confirm(context,
                        title: 'Mark ${a.tokenLabel} as no-show?',
                        message: '${a.patientName} will be removed from the queue.',
                        confirmLabel: 'No-show',
                        danger: true);
                    if (ok && context.mounted) await runGuarded(context, () => QueueService.markNoShow(a));
                  } else if (v == 'priority') {
                    showPrioritySheet(context, a, priorityIds);
                  } else if (v == 'up') {
                    await runGuarded(context, () => QueueService.move(a.sessionId, a.id, -1));
                  } else if (v == 'down') {
                    await runGuarded(context, () => QueueService.move(a.sessionId, a.id, 1));
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'skip', child: Text('Skip back 3 places')),
                  const PopupMenuItem(value: 'priority', child: Text('Priority…')),
                  if (!isFirst) const PopupMenuItem(value: 'up', child: Text('Move up one')),
                  if (!isLast) const PopupMenuItem(value: 'down', child: Text('Move down one')),
                  const PopupMenuItem(value: 'noshow', child: Text('Mark as no-show')),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
