import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/clinic_session.dart';
import '../../services/db.dart';
import '../../services/schedule_service.dart';
import 'cancel_session_screen.dart';
import 'session_form.dart';

/// S20 - Edit session and reminder settings (F1, F4).
/// If the date, time or doctor changes, every booked patient is notified
/// automatically - nobody has to phone them (Staff Q4 "time management").
/// Owner: Nethmini K (IT23669130)
/// CRUD: READ session; UPDATE session + booked appointments;
///       CREATE change notifications; DELETE session (staff: only if never
///       booked; admin: always, together with its bookings).
class EditSessionScreen extends StatefulWidget {
  final ClinicSession session;
  const EditSessionScreen({super.key, required this.session});

  @override
  State<EditSessionScreen> createState() => _EditSessionScreenState();
}

class _EditSessionScreenState extends State<EditSessionScreen> {
  bool _busy = false;

  Future<void> _save(SessionFormValues v) async {
    final old = widget.session;
    setState(() => _busy = true);
    try {
      final dateKey = DateKeys.of(v.date);
      final clashes = await ScheduleService.conflicts(
        hospitalId: old.hospitalId,
        dateKey: dateKey,
        doctorName: v.doctorName,
        room: v.room,
        startTime: v.startTime,
        endTime: v.endTime,
        exceptId: old.id,
      );
      if (!mounted) return;
      final timeChanged = dateKey != old.dateKey || v.startTime != old.startTime || v.endTime != old.endTime;
      final active = old.waitingIds.length + (old.currentServingId == null ? 0 : 1);
      final warnings = <String>[
        if (clashes.isNotEmpty)
          'Clashes with ${clashes.first.department} (${clashes.first.startTime}-${clashes.first.endTime}).',
        if ((timeChanged || v.doctorName != old.doctorName) && active > 0)
          '$active booked patient(s) will be notified of the change.',
      ];
      if (warnings.isNotEmpty) {
        final go = await confirm(context, title: 'Save changes?', message: warnings.join('\n\n'), confirmLabel: 'Save');
        if (!go || !mounted) {
          setState(() => _busy = false);
          return;
        }
      }
      final notified = await ScheduleService.update(old, {
        'department': v.department,
        'doctorName': v.doctorName,
        'room': v.room,
        'date': Timestamp.fromDate(v.date),
        'dateKey': dateKey,
        'startTime': v.startTime,
        'endTime': v.endTime,
        'capacity': v.capacity,
        'tokenPrefix': v.tokenPrefix,
        'avgConsultMinutes': v.avgConsultMinutes,
        'remindersEnabled': v.remindersEnabled,
        'reminderHoursBefore': v.reminderHoursBefore,
        'notes': v.notes,
      });
      if (!mounted) return;
      showSnack(context, notified > 0 ? 'Saved - $notified patient(s) notified' : 'Saved');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(context,
        title: 'Delete this session?',
        message: 'Only sessions created by mistake, with no bookings, can be deleted.',
        confirmLabel: 'Delete',
        danger: true);
    if (!ok || !mounted) return;
    final done = await runGuarded(context, () => ScheduleService.delete(widget.session), success: 'Session deleted');
    if (done && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final admin = context.watch<CurrentUser>().profile?.isAdmin ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit session'),
        actions: [
          if (admin)
            IconButton(
              tooltip: 'Delete clinic permanently',
              icon: const Icon(Icons.delete_forever_outlined),
              onPressed: () async {
                if (await deleteClinicWithConfirm(context, s) && context.mounted) Navigator.pop(context);
              },
            )
          else if (s.bookedCount == 0 && s.lastToken == 0)
            IconButton(tooltip: 'Delete session', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Column(children: [
        if (!s.isActive)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: AppColors.danger.withValues(alpha: 0.1),
            child: Text('This session is cancelled: ${s.cancelReason ?? ''}'),
          ),
        Expanded(
          child: SessionForm(initial: s, submitLabel: 'Save changes', busy: _busy, onSubmit: _save),
        ),
        if (s.isActive)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.event_busy),
                label: const Text('Cancel this session…'),
                onPressed: () => Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => CancelSessionScreen(session: s))),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Admin only: asks first, then permanently deletes [s] and all of its bookings
/// from the database. Returns true when the clinic was deleted.
Future<bool> deleteClinicWithConfirm(BuildContext context, ClinicSession s) async {
  final admin = me(context);
  final ok = await confirm(
    context,
    title: 'Delete this clinic?',
    message: 'This permanently deletes ${s.department} on ${formatDay(s.date)} (${s.startTime}-${s.endTime}) at '
        '${s.hospitalName} from the database, together with all of its bookings. Patients with an active '
        'booking are notified. This cannot be undone.',
    confirmLabel: 'Delete clinic',
    danger: true,
  );
  if (!ok || !context.mounted) return false;
  try {
    final r = await ScheduleService.deleteSessionPermanently(s, admin);
    if (context.mounted) {
      showSnack(context, 'Clinic deleted - ${r.bookings} booking(s) removed, ${r.notified} patient(s) notified');
    }
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, friendlyError(e), error: true);
    return false;
  }
}
