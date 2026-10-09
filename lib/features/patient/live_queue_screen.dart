import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_settings.dart';
import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/appointment.dart';
import '../../models/clinic_session.dart';
import '../../services/booking_service.dart';
import '../../services/feedback_service.dart';
import 'cancel_appointment_screen.dart';
import 'reschedule_screen.dart';

/// S07a/b/c - Live queue (F2, F4, NF2, NF4).
/// Driven by Firestore real-time listeners: the screen changes state on its
/// own as reception calls patients - no refresh needed.
///   S07a waiting   - own token filled, served token muted, expected call time
///   S07b near turn - amber banner appears only when the turn is close
///   S07c your turn - full-bleed green, no top bar, token centred
/// Extras: visit progress timeline, check-in QR code, reschedule / cancel,
/// and a rating once the visit is completed.
/// Owner: Lakmali M.A.D.M (IT23679344)
/// CRUD: READ appointment + session queue (live); UPDATE "I'm at the
///       hospital" (arrived flag seen by reception); CREATE visit rating.
class LiveQueueScreen extends StatefulWidget {
  final String appointmentId;
  const LiveQueueScreen({super.key, required this.appointmentId});

  @override
  State<LiveQueueScreen> createState() => _LiveQueueScreenState();
}

class _LiveQueueScreenState extends State<LiveQueueScreen> {
  QueueState? _lastState;
  late final Stream<Appointment?> _apptStream = BookingService.appointment(widget.appointmentId);
  String? _sessionId;
  Stream<ClinicSession?>? _sessionStream;

  void _onState(QueueState state) {
    if (_lastState != null && state != _lastState && (state == QueueState.nearTurn || state == QueueState.yourTurn)) {
      // A changed tone + vibration, not just a changed number (M02 §6).
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    }
    _lastState = state;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    // Material ground so the loading/error states (which have no Scaffold of
    // their own) render correctly on this route.
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _body(s),
    );
  }

  Widget _body(AppSettings s) {
    return StreamView<Appointment?>(
      stream: _apptStream,
      builder: (context, a) {
        if (a == null) return _scaffold(s, EmptyView(icon: Icons.search_off, message: s.t('somethingWrong')));
        // Re-subscribe to the session only if the appointment moved
        // (reschedule), not on every appointment update.
        if (a.sessionId != _sessionId) {
          _sessionId = a.sessionId;
          _sessionStream = BookingService.liveSession(a.sessionId);
        }
        return StreamView<ClinicSession?>(
          stream: _sessionStream!,
          builder: (context, session) {
            if (session == null) {
              return _scaffold(s, EmptyView(icon: Icons.event_busy, message: s.t('somethingWrong')));
            }
            final state = QueueLogic.stateFor(
              appointmentId: a.id,
              currentServingId: session.currentServingId,
              waitingIds: session.waitingIds,
            );
            _onState(state);
            if (state == QueueState.yourTurn) return _YourTurn(a: a, session: session, s: s);
            return _scaffold(s, _QueueBody(a: a, session: session, state: state, s: s));
          },
        );
      },
    );
  }

  Widget _scaffold(AppSettings s, Widget body) => Scaffold(appBar: AppBar(title: Text(s.t('liveQueue'))), body: body);
}

class _QueueBody extends StatelessWidget {
  final Appointment a;
  final ClinicSession session;
  final QueueState state;
  final AppSettings s;
  const _QueueBody({required this.a, required this.session, required this.state, required this.s});

  @override
  Widget build(BuildContext context) {
    // Recompute the clock-based figures every 30 seconds without waiting for
    // the queue itself to change.
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 30), (i) => i),
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final inQueue = state != QueueState.notInQueue;
    final ahead = QueueLogic.patientsAhead(session.waitingIds, a.id);
    final served = session.currentServingId != null;
    final wait = QueueLogic.estimatedWaitMinutes(
      patientsAhead: ahead,
      avgConsultMinutes: session.avgConsultMinutes,
      someoneBeingServed: served,
    );
    final expected = QueueLogic.expectedAt(
      now: DateTime.now(),
      clinicStart: DateKeys.startOf(session.date, session.startTime).add(Duration(minutes: session.delayMinutes)),
      patientsAhead: ahead,
      avgConsultMinutes: session.avgConsultMinutes,
      someoneBeingServed: served,
    );
    final near = state == QueueState.nearTurn;
    final next = near && ahead == 0;
    final step = QueueLogic.journeyStep(status: a.status, arrived: a.arrived, state: state);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // The amber banner only appears when the turn is actually close.
        if (inQueue && near)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: next ? AppColors.success : AppColors.accent,
              borderRadius: BorderRadius.circular(AppSizes.radius),
            ),
            child: Row(children: [
              Icon(next ? Icons.directions_walk : Icons.notifications_active,
                  color: next ? Colors.white : AppColors.n900, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  next ? s.t('youAreNext') : s.t('nearTurn'),
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 17, color: next ? Colors.white : AppColors.n900),
                ),
              ),
            ]),
          ),
        if (inQueue && session.paused)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InfoBanner(
              icon: Icons.pause_circle_outline,
              color: AppColors.danger,
              message: s.tf('queuePausedMsg', {'reason': session.pauseReason}),
            ),
          ),
        if (inQueue && session.delayMinutes > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InfoBanner(
              icon: Icons.schedule,
              color: AppColors.accent,
              message: s.tf('clinicLateMsg', {'n': '${session.delayMinutes}'}),
            ),
          ),
        if (inQueue && session.announcement.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InfoBanner(
              icon: Icons.campaign_outlined,
              color: AppColors.primary,
              message: s.tf('receptionMsg', {'msg': session.announcement}),
            ),
          ),
        Text('${a.department} · ${a.hospitalName}', style: t.bodySmall?.copyWith(fontSize: 15)),
        if (a.bookedFor == 'other')
          Text('${s.t('patientLabel')}: ${a.patientName}${a.relation.isEmpty ? '' : ' (${a.relation})'}', style: t.bodySmall),
        const SizedBox(height: 12),
        Row(children: [
          // Two clearly separated, labelled cards (M02 lo-fi feedback).
          Expanded(
            child: _TokenCard(
              label: s.t('nowServing'),
              child: TokenChip(session.currentTokenLabel ?? '—', filled: false, fontSize: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TokenCard(
              label: s.t('yourToken'),
              child: TokenChip(a.tokenLabel, filled: true, fontSize: 26),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (inQueue)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.t('patientsAhead'), style: t.bodySmall?.copyWith(fontSize: 15)),
                      Text('$ahead',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: near ? AppColors.accent : AppColors.n900,
                          )),
                    ]),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.t('estimatedWait'), style: t.bodySmall?.copyWith(fontSize: 15)),
                      Text('~$wait ${s.t('minutes')}',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ]),
                const Divider(height: 24),
                Row(children: [
                  const Icon(Icons.access_time_filled, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: '${s.t('expectedCall')} '),
                      TextSpan(
                          text: DateFormat('h:mm a').format(expected),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ])),
                  ),
                ]),
              ]),
            ),
          ),
        if (!served && inQueue) ...[
          const SizedBox(height: 8),
          Text(s.t('queueNotStarted'), style: t.bodySmall),
        ],
        const SizedBox(height: 16),
        if (inQueue || a.status == AppointmentStatus.completed) _Journey(step: step),
        if (!inQueue)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: InfoBanner(
              icon: a.status == AppointmentStatus.completed ? Icons.check_circle_outline : Icons.info_outline,
              color: a.status == AppointmentStatus.completed ? AppColors.success : AppColors.n600,
              message: '${a.tokenLabel} · ${s.t('status_${a.status}')}'
                  '${a.cancelReason != null ? '\n${a.cancelReason}' : ''}',
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              InfoRow(s.t('date'), formatDay(a.date), icon: Icons.event),
              InfoRow(s.t('time'), '${a.startTime} – ${session.endTime}', icon: Icons.schedule),
              InfoRow(s.t('doctor'), a.doctorName, icon: Icons.person_outline),
              if (session.room.isNotEmpty) InfoRow(s.t('room'), session.room, icon: Icons.meeting_room_outlined),
              if (a.visitReason.isNotEmpty) InfoRow(s.t('reasonLabel'), a.visitReason, icon: Icons.notes),
              InfoRow(s.t('referenceLabel'), a.reference, icon: Icons.confirmation_number_outlined),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        if (inQueue) ...[
          if (a.arrived)
            InfoBanner(icon: Icons.check_circle, color: AppColors.success, message: s.t('arrivedNoted'))
          else
            PrimaryButton(
              s.t('imHere'),
              icon: Icons.where_to_vote_outlined,
              onPressed: () => runGuarded(context, () => BookingService.markArrived(a.id)),
            ),
          const SizedBox(height: 12),
          _QrTicket(a: a),
          if (a.status == AppointmentStatus.waiting) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: SecondaryButton(
                  s.t('reschedule'),
                  icon: Icons.edit_calendar,
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => RescheduleScreen(appointment: a))),
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
        ],
        if (a.status == AppointmentStatus.completed) _RateVisit(a: a),
      ],
    );
  }
}

class _TokenCard extends StatelessWidget {
  final String label;
  final Widget child;
  const _TokenCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            child,
          ]),
        ),
      );
}

/// Booked -> Checked in -> Turn near -> With doctor -> Done.
class _Journey extends StatelessWidget {
  final int step;
  const _Journey({required this.step});

  static const _labels = ['tl_booked', 'tl_checkedIn', 'tl_near', 'tl_doctor', 'tl_done'];
  static const _icons = [
    Icons.event_available,
    Icons.where_to_vote,
    Icons.notifications_active,
    Icons.medical_services,
    Icons.check_circle,
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Row(children: [
          for (var i = 0; i < _labels.length; i++) ...[
            Expanded(
              child: Semantics(
                label: '${context.watch<AppSettings>().t(_labels[i])}${i <= step ? ', ✓' : ''}',
                child: Column(children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: i < step ? AppColors.success : (i == step ? AppColors.primary : AppColors.n200),
                    child: Icon(i < step ? Icons.check : _icons[i],
                        size: 18, color: i <= step ? Colors.white : AppColors.n400),
                  ),
                  const SizedBox(height: 6),
                  Text(context.watch<AppSettings>().t(_labels[i]),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: i == step ? FontWeight.bold : FontWeight.normal,
                          color: i <= step ? AppColors.n900 : AppColors.n400)),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// The patient's check-in QR. Reception can look the booking up by this
/// reference (or scan it) instead of asking for details.
class _QrTicket extends StatefulWidget {
  final Appointment a;
  const _QrTicket({required this.a});

  @override
  State<_QrTicket> createState() => _QrTicketState();
}

class _QrTicketState extends State<_QrTicket> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    return Card(
      child: Column(children: [
        ListTile(
          leading: const Icon(Icons.qr_code_2, color: AppColors.primary, size: 32),
          title: Text(context.watch<AppSettings>().t('qrTitle'), style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(context.watch<AppSettings>().t('qrSub')),
          trailing: Icon(_open ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() => _open = !_open),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radius),
                  border: Border.all(color: AppColors.n200),
                ),
                child: QrImageView(
                  data: 'OPD:${a.id}',
                  size: 200,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'Check-in QR code for ${a.tokenLabel}',
                ),
              ),
              const SizedBox(height: 8),
              Text('${a.tokenLabel} · ${a.reference}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: a.reference));
                  showSnack(context, context.read<AppSettings>().t('refCopied'));
                },
                icon: const Icon(Icons.copy, size: 18),
                label: Text(context.watch<AppSettings>().t('copyRef')),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// After the visit: 1-5 stars and an optional comment, given once.
class _RateVisit extends StatefulWidget {
  final Appointment a;
  const _RateVisit({required this.a});

  @override
  State<_RateVisit> createState() => _RateVisitState();
}

class _RateVisitState extends State<_RateVisit> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _busy = false;
  late final Stream<VisitFeedback?> _stream = FeedbackService.forAppointment(widget.a.id);

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      showSnack(context, context.read<AppSettings>().t('tapStars'), error: true);
      return;
    }
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => FeedbackService.submit(widget.a, rating: _rating, comment: _comment.text),
      success: context.read<AppSettings>().t('thanksFeedback'),
    );
    if (mounted && !ok) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VisitFeedback?>(
      stream: _stream,
      builder: (context, snap) {
        final given = snap.data;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.watch<AppSettings>().t('rateTitle'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      tooltip: '$i star${i == 1 ? '' : 's'}',
                      iconSize: 36,
                      onPressed: given != null ? null : () => setState(() => _rating = i),
                      icon: Icon(
                        i <= (given?.rating ?? _rating) ? Icons.star : Icons.star_border,
                        color: AppColors.accent,
                      ),
                    ),
                ]),
                if (given != null)
                  InfoBanner(icon: Icons.favorite, color: AppColors.success, message: context.watch<AppSettings>().t('thanksFeedback'))
                else ...[
                  TextField(
                    controller: _comment,
                    maxLines: 2,
                    maxLength: 300,
                    decoration: InputDecoration(hintText: context.watch<AppSettings>().t('rateHint')),
                  ),
                  const SizedBox(height: 8),
                  PrimaryButton(context.watch<AppSettings>().t('submitFeedback'), icon: Icons.send, onPressed: _submit, loading: _busy),
                ],
              ]),
            ),
          ),
        );
      },
    );
  }
}

/// S07c - deliberately unlike every other screen so it is noticed at a
/// glance in a noisy OPD (Patient Q9: "I didn't hear them calling my name").
class _YourTurn extends StatelessWidget {
  final Appointment a;
  final ClinicSession session;
  final AppSettings s;
  const _YourTurn({required this.a, required this.session, required this.s});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: s.highContrast ? Colors.black : AppColors.success,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                tooltip: s.t('back'),
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            const Spacer(),
            const Icon(Icons.campaign, color: Colors.white, size: 80),
            const SizedBox(height: 16),
            Text(s.t('yourTurn'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppSizes.radius)),
              child: Text(a.tokenLabel,
                  style: const TextStyle(
                      fontSize: 56, fontWeight: FontWeight.bold, color: AppColors.success, letterSpacing: 2)),
            ),
            const SizedBox(height: 24),
            Text(s.t('goToRoom'),
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20)),
            if (session.room.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(session.room,
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            ],
            const Spacer(flex: 2),
          ]),
        ),
      ),
    );
  }
}
