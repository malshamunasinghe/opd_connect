import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/app_settings.dart';
import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/app_notification.dart';
import '../../models/appointment.dart';
import '../../models/clinic_session.dart';
import '../../models/hospital.dart';
import '../../services/booking_service.dart';
import '../../services/db.dart';
import '../../services/profile_service.dart';
import '../../services/schedule_service.dart';
import '../profile/help_screen.dart';
import '../profile/profile_screen.dart';
import '../records/my_health_screen.dart';
import '../schedule/notification_centre_screen.dart';
import '../schedule/settings_screen.dart';
import 'book_hospital_screen.dart';
import 'book_slot_screen.dart';
import 'clinics_screen.dart';
import 'live_queue_screen.dart';
import 'my_appointments_screen.dart';

/// Patient entry point: Home, Appointments (S04), My health, Notifications
/// (S19), Settings (S22). Owner: Lakmali M.A.D.M (IT23679344)
class PatientHome extends StatefulWidget {
  const PatientHome({super.key});

  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> {
  int _tab = 0;
  StreamSubscription<List<AppNotification>>? _notifSub;
  StreamSubscription<List<Appointment>>? _apptSub;
  final Set<String> _seen = {};
  bool _firstNotifBatch = true;
  bool _remindersChecked = false;
  late final Stream<List<AppNotification>> _notifStream = ScheduleService.notifications(me(context).uid);

  @override
  void initState() {
    super.initState();
    final uid = me(context).uid;

    // In-app alert when a new near-turn / change notification arrives (F4).
    _notifSub = ScheduleService.notifications(uid).listen((items) {
      if (_firstNotifBatch) {
        _seen.addAll(items.map((i) => i.id));
        _firstNotifBatch = false;
        return;
      }
      for (final n in items) {
        if (_seen.add(n.id) && !n.read && mounted) {
          HapticFeedback.heavyImpact();
          SystemSound.play(SystemSoundType.alert);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: n.type == NotificationTypes.nearTurn ? AppColors.accent : AppColors.n900,
            duration: const Duration(seconds: 6),
            content: Text('${n.title}\n${n.body}',
                style: TextStyle(color: n.type == NotificationTypes.nearTurn ? AppColors.n900 : Colors.white)),
          ));
        }
      }
    });

    // Reminders become due while the patient is not in the app; check once
    // per launch.
    _apptSub = BookingService.myAppointments(uid).listen((appts) {
      if (_remindersChecked) return;
      _remindersChecked = true;
      BookingService.sendDueReminders(uid, appts).catchError((_) {});
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _apptSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final pages = [
      _HomeTab(onSwitchTab: (i) => setState(() => _tab = i)),
      const MyAppointmentsScreen(),
      const MyHealthScreen(),
      const NotificationCentreScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: StreamBuilder<List<AppNotification>>(
        stream: _notifStream,
        builder: (context, snap) {
          final unread = (snap.data ?? const []).where((n) => !n.read).length;
          return NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                  icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: s.t('home')),
              NavigationDestination(
                  icon: const Icon(Icons.event_note_outlined),
                  selectedIcon: const Icon(Icons.event_note),
                  label: s.t('navBookings')),
              NavigationDestination(
                  icon: const Icon(Icons.favorite_border),
                  selectedIcon: const Icon(Icons.favorite),
                  label: s.t('records')),
              NavigationDestination(
                icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.notifications_outlined)),
                selectedIcon: const Icon(Icons.notifications),
                label: s.t('notifications'),
              ),
              NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: s.t('settings')),
            ],
          );
        },
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  final ValueChanged<int> onSwitchTab;
  const _HomeTab({required this.onSwitchTab});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late final Stream<List<Appointment>> _appts = BookingService.myAppointments(me(context).uid);
  late final Stream<List<ClinicSession>> _today = BookingService.clinicsToday();
  late final Stream<List<AppNotification>> _notifs = ScheduleService.notifications(me(context).uid);
  bool _verifyBusy = false;

  static const _tips = [
    'tip0',
    'tip1',
    'tip2',
    'tip3',
    'tip4',
    'tip5',
    'tip6',
  ];

  String _greeting(AppSettings s) {
    final h = DateTime.now().hour;
    return s.t(h < 12 ? 'goodMorning' : (h < 17 ? 'goodAfternoon' : 'goodEvening'));
  }

  Future<void> _refreshVerified() async {
    setState(() => _verifyBusy = true);
    try {
      final ok = await ProfileService.refreshVerified();
      if (!mounted) return;
      showSnack(context, context.read<AppSettings>().t(ok ? 'emailVerifiedOk' : 'notVerifiedYet'),
          error: !ok);
      setState(() {});
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _verifyBusy = false);
    }
  }

  void _openBooking() => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookHospitalScreen()));

  void _openClinic(ClinicSession x) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookSlotScreen(
              hospital: Hospital(id: x.hospitalId, name: x.hospitalName, district: '', address: '')),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final profile = me(context);
    final t = Theme.of(context).textTheme;
    final user = FirebaseAuth.instance.currentUser;
    final tip = s.t(_tips[DateTime.now().difference(DateTime(DateTime.now().year)).inDays % _tips.length]);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 56),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_greeting(s), style: const TextStyle(color: Colors.white70, fontSize: 15)),
                  Text(profile.name.split(' ').first,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ]),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(40),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                child: Semantics(label: s.t('profile'), button: true, child: InitialsAvatar(profile.name, radius: 28)),
              ),
            ]),
          ),
          // The primary action floats over the header (above the fold).
          Transform.translate(
            offset: const Offset(0, -32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 3,
                shadowColor: Colors.black26,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSizes.radius),
                  onTap: _openBooking,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.t('bookAppointment'), style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text(s.t('bookSub'), style: t.bodySmall),
                        ]),
                      ),
                      const Icon(Icons.chevron_right),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Transform.translate(
              offset: const Offset(0, -16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (user != null && !user.emailVerified) ...[
                  InfoBanner(
                    icon: Icons.mark_email_unread_outlined,
                    color: AppColors.accent,
                    message: s.t('verifyEmailMsg'),
                    action: _verifyBusy
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : TextButton(onPressed: _refreshVerified, child: Text(s.t('iVerified'))),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => runGuarded(context, ProfileService.resendVerification,
                          success: 'Verification e-mail sent'),
                      child: Text(s.t('resendEmail')),
                    ),
                  ),
                ],
                _NextAppointment(stream: _appts, s: s),
                const SizedBox(height: 8),
                SectionTitle(s.t('quickActions')),
                ActionGrid(children: [
                  QuickAction(
                      icon: Icons.local_hospital_outlined,
                      label: s.t('clinics'),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClinicsScreen()))),
                  QuickAction(
                      icon: Icons.event_note_outlined,
                      label: s.t('myBookings'),
                      color: AppColors.primaryDark,
                      onTap: () => widget.onSwitchTab(1)),
                  QuickAction(
                      icon: Icons.favorite_border,
                      label: s.t('records'),
                      color: AppColors.danger,
                      onTap: () => widget.onSwitchTab(2)),
                  QuickAction(
                      icon: Icons.notifications_outlined,
                      label: s.t('notifications'),
                      color: AppColors.accent,
                      onTap: () => widget.onSwitchTab(3)),
                  QuickAction(
                      icon: Icons.person_outline,
                      label: s.t('profile'),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
                  QuickAction(
                      icon: Icons.help_outline,
                      label: s.t('help'),
                      color: AppColors.n600,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()))),
                  QuickAction(
                      icon: Icons.settings_outlined,
                      label: s.t('settings'),
                      color: AppColors.n600,
                      onTap: () => widget.onSwitchTab(4)),
                  QuickAction(
                      icon: Icons.local_phone,
                      label: s.t('emergency1990'),
                      color: AppColors.danger,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()))),
                ]),
                const SizedBox(height: 8),
                _Stats(stream: _appts),
                SectionTitle(s.t('clinicsToday')),
                _ClinicsToday(stream: _today, s: s, onTap: _openClinic),
                const SizedBox(height: 16),
                _RecentNotifications(stream: _notifs, s: s, onSeeAll: () => widget.onSwitchTab(3)),
                const SizedBox(height: 16),
                InfoBanner(icon: Icons.tips_and_updates_outlined, color: AppColors.success, message: tip),
                const SizedBox(height: 12),
                Card(
                  color: AppColors.danger.withValues(alpha: 0.06),
                  child: ListTile(
                    leading: const Icon(Icons.local_phone, color: AppColors.danger),
                    title: Text(s.t('emergencyTitle'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(s.t('emergencyBody')),
                    isThreeLine: true,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// The patient's next active appointment with its live queue position.
class _NextAppointment extends StatelessWidget {
  final Stream<List<Appointment>> stream;
  final AppSettings s;
  const _NextAppointment({required this.stream, required this.s});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamView<List<Appointment>>(
      stream: stream,
      builder: (context, list) {
        final upcoming = list.where((a) => a.isActive).toList();
        if (upcoming.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const Icon(Icons.event_available, size: 52, color: AppColors.n400),
                const SizedBox(height: 8),
                Text(s.t('noUpcoming'), textAlign: TextAlign.center, style: t.bodyLarge),
                const SizedBox(height: 4),
                Text(s.t('noTokenYet'),
                    textAlign: TextAlign.center, style: t.bodySmall),
              ]),
            ),
          );
        }
        final next = upcoming.first;
        final isToday = next.dateKey == DateKeys.of(DateTime.now());
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle(s.t('nextAppointment'), trailing: isToday ? Pill(s.t('today').toUpperCase(), color: AppColors.success) : null),
          _TokenHero(appointment: next, s: s),
          if (upcoming.length > 1) ...[
            const SizedBox(height: 12),
            for (final a in upcoming.skip(1).take(2)) ...[
              AppointmentCard(
                appointment: a,
                statusText: s.t('status_${a.status}'),
                onTap: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => LiveQueueScreen(appointmentId: a.id))),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ]);
      },
    );
  }
}

/// One line under the next appointment: where the queue is right now.
class _LiveStatus extends StatelessWidget {
  final Appointment appointment;
  final AppSettings s;
  const _LiveStatus({required this.appointment, required this.s});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ClinicSession?>(
      stream: BookingService.liveSession(appointment.sessionId),
      builder: (context, snap) {
        final session = snap.data;
        if (session == null) return const SizedBox.shrink();
        final state = QueueLogic.stateFor(
          appointmentId: appointment.id,
          currentServingId: session.currentServingId,
          waitingIds: session.waitingIds,
        );
        final ahead = QueueLogic.patientsAhead(session.waitingIds, appointment.id);
        late final IconData icon;
        late final Color color;
        late final String text;
        if (state == QueueState.yourTurn) {
          icon = Icons.campaign;
          color = AppColors.success;
          text = s.t('yourTurn');
        } else if (ahead < 0) {
          icon = Icons.event;
          color = AppColors.n600;
          text = s.tf('clinicHours', {'start': session.startTime, 'end': session.endTime});
        } else {
          final wait = QueueLogic.estimatedWaitMinutes(
            patientsAhead: ahead,
            avgConsultMinutes: session.avgConsultMinutes,
            someoneBeingServed: session.currentServingId != null,
          );
          icon = state == QueueState.nearTurn ? Icons.notifications_active : Icons.people_alt_outlined;
          color = state == QueueState.nearTurn ? AppColors.accent : AppColors.primary;
          text = session.currentServingId == null
              ? s.tf('liveNotStarted', {'n': '$ahead'})
              : s.tf('liveNowServing', {'token': session.currentTokenLabel ?? '-', 'n': '$ahead', 'm': '$wait'});
        }
        return InfoBanner(icon: icon, message: text, color: color);
      },
    );
  }
}

class _Stats extends StatelessWidget {
  final Stream<List<Appointment>> stream;
  const _Stats({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Appointment>>(
      stream: stream,
      builder: (context, snap) {
        final all = snap.data ?? const <Appointment>[];
        final upcoming = all.where((a) => a.isActive).length;
        final done = all.where((a) => a.status == AppointmentStatus.completed).length;
        final missed = all.where((a) => a.status == AppointmentStatus.noShow || a.status == AppointmentStatus.cancelled).length;
        return Row(children: [
          Expanded(child: StatTile(value: '$upcoming', label: context.watch<AppSettings>().t('upcoming'), icon: Icons.event, color: AppColors.primary)),
          const SizedBox(width: 8),
          Expanded(child: StatTile(value: '$done', label: context.watch<AppSettings>().t('completed'), icon: Icons.check_circle_outline, color: AppColors.success)),
          const SizedBox(width: 8),
          Expanded(child: StatTile(value: '$missed', label: context.watch<AppSettings>().t('cancelledMissed'), icon: Icons.event_busy, color: AppColors.n600)),
        ]);
      },
    );
  }
}

class _ClinicsToday extends StatelessWidget {
  final Stream<List<ClinicSession>> stream;
  final AppSettings s;
  final ValueChanged<ClinicSession> onTap;
  const _ClinicsToday({required this.stream, required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamView<List<ClinicSession>>(
      stream: stream,
      builder: (context, list) {
        if (list.isEmpty) {
          return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(s.t('noClinicsToday'))));
        }
        return SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final x = list[i];
              final full = x.isFull;
              return SizedBox(
                width: 220,
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSizes.radius),
                    onTap: full ? null : () => onTap(x),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(x.department, style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(x.hospitalName, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.schedule, size: 16, color: AppColors.n600),
                          const SizedBox(width: 4),
                          Text('${x.startTime} – ${x.endTime}', style: t.bodySmall),
                        ]),
                        const Spacer(),
                        Pill(full ? s.t('full') : '${x.placesLeft} ${s.t('placesLeftShort')}',
                            color: full ? AppColors.danger : (x.placesLeft <= 5 ? AppColors.accent : AppColors.success)),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _RecentNotifications extends StatelessWidget {
  final Stream<List<AppNotification>> stream;
  final AppSettings s;
  final VoidCallback onSeeAll;
  const _RecentNotifications({required this.stream, required this.s, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: stream,
      builder: (context, snap) {
        final items = (snap.data ?? const <AppNotification>[]).take(2).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle(s.t('notifications'), trailing: TextButton(onPressed: onSeeAll, child: Text(s.t('all')))),
          for (final n in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Icon(n.read ? Icons.notifications_none : Icons.notifications_active,
                      color: n.read ? AppColors.n400 : AppColors.primary),
                  title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: onSeeAll,
                ),
              ),
            ),
        ]);
      },
    );
  }
}

/// The patient's own token, front and centre: big number, live status, where
/// and when. Tapping opens the live queue.
class _TokenHero extends StatelessWidget {
  final Appointment appointment;
  final AppSettings s;
  const _TokenHero({required this.appointment, required this.s});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final t = Theme.of(context).textTheme;
    void open() =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => LiveQueueScreen(appointmentId: a.id)));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primary]),
            ),
            child: Column(children: [
              Row(children: [
                Text(s.t('yourToken').toUpperCase(),
                    style: const TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 2)),
                const Spacer(),
                StatusPill(status: a.status, text: s.t('status_${a.status}')),
              ]),
              const SizedBox(height: 4),
              Semantics(
                label: '${s.t('yourToken')} ${a.tokenLabel}',
                child: Text(a.tokenLabel,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 60, fontWeight: FontWeight.bold, letterSpacing: 3)),
              ),
              if (a.bookedFor == 'other')
                Text(s.tf('forPerson', {'name': '${a.patientName}${a.relation.isEmpty ? '' : ' (${a.relation})'}'}),
                    style: const TextStyle(color: Colors.white70)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.department, style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.local_hospital_outlined, size: 18, color: AppColors.n600),
                const SizedBox(width: 6),
                Expanded(child: Text(a.hospitalName, style: t.bodyMedium)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.event, size: 18, color: AppColors.n600),
                const SizedBox(width: 6),
                Text('${formatDay(a.date)} · ${a.startTime}', style: t.bodyMedium),
              ]),
              if (a.doctorName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.person_outline, size: 18, color: AppColors.n600),
                  const SizedBox(width: 6),
                  Text(a.doctorName, style: t.bodyMedium),
                ]),
              ],
              const SizedBox(height: 12),
              _LiveStatus(appointment: a, s: s),
              const SizedBox(height: 12),
              PrimaryButton(s.t('viewLiveQueue'), icon: Icons.people_alt_outlined, onPressed: open),
            ]),
          ),
        ]),
      ),
    );
  }
}
