import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/appointment.dart';
import '../../models/clinic_session.dart';
import '../../services/booking_service.dart';
import '../../services/db.dart';
import 'book_slot_screen.dart';

/// S05 - Reschedule appointment (F1).
/// The current booking is shown above the new options so the patient can
/// compare, the token change is announced up front, and the move is
/// confirmed as "from -> to" before anything is saved.
/// Owner: Lakmali M.A.D.M (IT23679344)
/// CRUD: READ current booking and open sessions; UPDATE appointment
///       (plus both sessions' counters, in one transaction).
class RescheduleScreen extends StatelessWidget {
  final Appointment appointment;
  const RescheduleScreen({super.key, required this.appointment});

  Future<void> _pick(BuildContext context, ClinicSession target) {
    final s = context.read<AppSettings>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _ConfirmMoveSheet(appointment: appointment, target: target, s: s, screenContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final a = appointment;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('reschedule'))),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.t('currentBooking'), style: t.bodySmall?.copyWith(fontSize: 15)),
          const SizedBox(height: 8),
          _BookingSummary(a: a, s: s),
          const SizedBox(height: 12),
          InfoBanner(icon: Icons.confirmation_number_outlined, message: s.t('tokenWillChange')),
          const SizedBox(height: 16),
          Text(s.t('newDay'), style: t.titleLarge),
          const SizedBox(height: 8),
          Expanded(
            child: SessionPicker(
              hospitalId: a.hospitalId,
              initialDepartment: a.department,
              excludeSessionId: a.sessionId,
              currentDepartment: a.department,
              onPick: (target) => _pick(context, target),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Token, clinic, hospital, doctor and date of the booking being moved.
class _BookingSummary extends StatelessWidget {
  final Appointment a;
  final AppSettings s;
  const _BookingSummary({required this.a, required this.s});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.n200.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TokenChip(a.tokenLabel, filled: false, fontSize: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.department, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text('${formatDay(a.date)} · ${a.startTime}', style: t.bodyMedium),
            const SizedBox(height: 2),
            Text('${a.doctorName} · ${a.hospitalName}', style: t.bodySmall),
          ]),
        ),
      ]),
    );
  }
}

/// Bottom sheet that shows the move as old -> new and performs it.
class _ConfirmMoveSheet extends StatefulWidget {
  final Appointment appointment;
  final ClinicSession target;
  final AppSettings s;
  final BuildContext screenContext;
  const _ConfirmMoveSheet({
    required this.appointment,
    required this.target,
    required this.s,
    required this.screenContext,
  });

  @override
  State<_ConfirmMoveSheet> createState() => _ConfirmMoveSheetState();
}

class _ConfirmMoveSheetState extends State<_ConfirmMoveSheet> {
  bool _busy = false;

  Future<void> _confirm() async {
    final s = widget.s;
    final nav = Navigator.of(widget.screenContext);
    // Captured before the await; the messenger lives above the routes, so
    // the message survives both pops below.
    final messenger = ScaffoldMessenger.of(widget.screenContext);
    setState(() => _busy = true);
    try {
      final token = await BookingService.reschedule(widget.appointment, widget.target);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(s.tf('rescheduledTo', {'date': formatDay(widget.target.date), 'token': token})),
          backgroundColor: AppColors.n900,
          behavior: SnackBarBehavior.floating,
        ));
      Navigator.pop(context); // sheet
      nav.pop(); // reschedule screen
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final msg = e is AppException && e.code == 'full' ? s.t('sessionFull') : friendlyError(e);
      showSnack(context, msg, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final a = widget.appointment;
    final x = widget.target;
    final changesClinic = a.department != x.department;
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.t('confirmChange'), style: t.titleLarge),
          const SizedBox(height: 16),
          _MoveCard(
            label: s.t('moveFrom'),
            muted: true,
            token: a.tokenLabel,
            clinic: a.department,
            when: '${formatDay(a.date)} · ${a.startTime}',
            doctor: a.doctorName,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Icon(Icons.arrow_downward, color: AppColors.primary),
          ),
          _MoveCard(
            label: s.t('moveTo'),
            muted: false,
            token: null,
            clinic: x.department,
            when: '${formatDay(x.date)} · ${x.startTime}',
            doctor: x.doctorName,
            highlightClinic: changesClinic,
          ),
          const SizedBox(height: 16),
          InfoBanner(icon: Icons.confirmation_number_outlined, message: s.t('tokenWillChange')),
          const SizedBox(height: 16),
          PrimaryButton(s.t('confirmChange'), onPressed: _confirm, loading: _busy),
          const SizedBox(height: 8),
          SecondaryButton(s.t('back'), onPressed: _busy ? null : () => Navigator.pop(context)),
        ]),
      ),
    );
  }
}

class _MoveCard extends StatelessWidget {
  final String label;
  final bool muted;
  final String? token;
  final String clinic;
  final String when;
  final String doctor;
  final bool highlightClinic;
  const _MoveCard({
    required this.label,
    required this.muted,
    required this.token,
    required this.clinic,
    required this.when,
    required this.doctor,
    this.highlightClinic = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: muted ? AppColors.n200.withValues(alpha: 0.6) : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: muted ? AppColors.n200 : AppColors.primary, width: muted ? 1 : 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (token != null) Pill(token!, color: AppColors.n600),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Flexible(child: Text(clinic, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
          if (highlightClinic) ...[
            const SizedBox(width: 8),
            const Icon(Icons.swap_horiz, size: 18, color: AppColors.accent),
          ],
        ]),
        Text(when, style: t.bodyMedium),
        Text(doctor, style: t.bodySmall),
      ]),
    );
  }
}
