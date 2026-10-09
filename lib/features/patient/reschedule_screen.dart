import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/appointment.dart';
import '../../models/clinic_session.dart';
import '../../services/booking_service.dart';
import '../../services/db.dart';
import 'book_slot_screen.dart';

/// S05 - Reschedule appointment (F1).
/// Variant B: the current booking is shown above the new options so the
/// patient can compare before committing.
/// Owner: Lakmali M.A.D.M (IT23679344)
/// CRUD: READ current booking and open sessions; UPDATE appointment
///       (plus both sessions' counters, in one transaction).
class RescheduleScreen extends StatelessWidget {
  final Appointment appointment;
  const RescheduleScreen({super.key, required this.appointment});

  Future<void> _pick(BuildContext context, ClinicSession target) async {
    final s = context.read<AppSettings>();
    final ok = await confirm(
      context,
      title: s.t('confirmChange'),
      message: '${appointment.department}\n'
          '${formatDay(appointment.date)} ${appointment.startTime}  →  '
          '${formatDay(target.date)} ${target.startTime}\n${target.doctorName}',
      confirmLabel: s.t('confirmChange'),
      cancelLabel: s.t('back'),
    );
    if (!ok || !context.mounted) return;
    try {
      await BookingService.reschedule(appointment, target);
      if (!context.mounted) return;
      showSnack(context, s.t('saved'));
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      final msg = e is AppException && e.code == 'full' ? s.t('sessionFull') : friendlyError(e);
      showSnack(context, msg, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final a = appointment;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('reschedule'))),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.t('currentBooking'), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 15)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.n200.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppSizes.radius),
            ),
            child: Row(children: [
              TokenChip(a.tokenLabel, filled: false, fontSize: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${a.department}\n${formatDay(a.date)} · ${a.startTime}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Text(s.t('newDay'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Expanded(
            child: SessionPicker(
              hospitalId: a.hospitalId,
              initialDepartment: a.department,
              excludeSessionId: a.sessionId,
              onPick: (target) => _pick(context, target),
            ),
          ),
        ]),
      ),
    );
  }
}
