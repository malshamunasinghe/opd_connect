import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/logic.dart';
import '../../core/widgets.dart';
import '../../models/clinic_session.dart';
import '../../services/db.dart';
import '../../services/schedule_service.dart';
import 'session_form.dart';

/// S18 - Create clinic session (F1).
/// Staff Q4 named "clinic days" as a scheduling constraint; sessions created
/// here are the only days patients can book (S02).
/// Owner: Nethmini K (IT23669130)
/// CRUD: READ (clash check against same-day sessions); CREATE session.
class CreateSessionScreen extends StatefulWidget {
  final DateTime? initialDate;
  const CreateSessionScreen({super.key, this.initialDate});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  bool _busy = false;

  Future<void> _save(SessionFormValues v) async {
    setState(() => _busy = true);
    try {
      final dateKey = DateKeys.of(v.date);
      final clashes = await ScheduleService.conflicts(
        hospitalId: v.hospital!.id,
        dateKey: dateKey,
        doctorName: v.doctorName,
        room: v.room,
        startTime: v.startTime,
        endTime: v.endTime,
      );
      if (!mounted) return;
      if (clashes.isNotEmpty) {
        final c = clashes.first;
        final go = await confirm(
          context,
          title: 'Time clash',
          message: '${c.doctorName} / ${c.room} already has ${c.department} '
              '${c.startTime}-${c.endTime} on this day. Create anyway?',
          confirmLabel: 'Create anyway',
        );
        if (!go || !mounted) {
          setState(() => _busy = false);
          return;
        }
      }
      await ScheduleService.create(ClinicSession.newSessionData(
        hospitalId: v.hospital!.id,
        hospitalName: v.hospital!.name,
        department: v.department,
        doctorName: v.doctorName,
        room: v.room,
        date: v.date,
        dateKey: dateKey,
        startTime: v.startTime,
        endTime: v.endTime,
        capacity: v.capacity,
        tokenPrefix: v.tokenPrefix,
        avgConsultMinutes: v.avgConsultMinutes,
        remindersEnabled: v.remindersEnabled,
        reminderHoursBefore: v.reminderHoursBefore,
        createdBy: me(context).uid,
        notes: v.notes,
      ));
      if (!mounted) return;
      showSnack(context,
          'Clinic created for ${formatDay(v.date)}. It is under "Coming up" on the Overview and open for booking.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New clinic session')),
      body: SessionForm(
        initialDate: widget.initialDate,
        submitLabel: 'Create session',
        busy: _busy,
        onSubmit: _save,
      ),
    );
  }
}
