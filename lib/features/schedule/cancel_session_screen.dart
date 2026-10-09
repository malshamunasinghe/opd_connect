import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/clinic_session.dart';
import '../../services/db.dart';
import '../../services/schedule_service.dart';

/// S21 - Cancel session with automatic notification (F4).
/// Patient Q9: patients were not told about changes in time. Cancelling here
/// cancels every booking in the session and notifies each app patient.
/// Owner: Nethmini K (IT23669130)
/// CRUD: READ session; UPDATE session + appointments to cancelled;
///       CREATE one notification per affected patient.
class CancelSessionScreen extends StatefulWidget {
  final ClinicSession session;
  const CancelSessionScreen({super.key, required this.session});

  @override
  State<CancelSessionScreen> createState() => _CancelSessionScreenState();
}

class _CancelSessionScreenState extends State<CancelSessionScreen> {
  static const _reasons = [
    'Doctor unavailable',
    'Public holiday',
    'Hospital emergency',
    'Facility maintenance',
    'Other'
  ];
  final _formKey = GlobalKey<FormState>();
  final _detail = TextEditingController();
  String _reason = _reasons.first;
  bool _busy = false;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (!_formKey.currentState!.validate()) return;
    final s = widget.session;
    final reason = _reason == 'Other' || _detail.text.trim().isNotEmpty
        ? '$_reason${_detail.text.trim().isEmpty ? '' : ': ${_detail.text.trim()}'}'
        : _reason;
    final ok = await confirm(context,
        title: 'Cancel ${s.department} on ${s.dateKey}?',
        message: 'All ${s.bookedCount} booking(s) will be cancelled and patients with the app '
            'will be notified straight away. This cannot be undone.',
        confirmLabel: 'Cancel session',
        cancelLabel: 'Keep session',
        danger: true);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final n = await ScheduleService.cancel(s, reason);
      if (!mounted) return;
      showSnack(context, 'Session cancelled - $n patient(s) notified');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return Scaffold(
      appBar: AppBar(title: const Text('Cancel session')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  InfoRow('Clinic', s.department, icon: Icons.medical_services_outlined),
                  InfoRow('Hospital', s.hospitalName, icon: Icons.local_hospital_outlined),
                  InfoRow('Date', formatDay(s.date), icon: Icons.event),
                  InfoRow('Time', '${s.startTime} – ${s.endTime}', icon: Icons.schedule),
                  InfoRow('Doctor', s.doctorName, icon: Icons.person_outline),
                  InfoRow('Bookings', '${s.bookedCount}', icon: Icons.people_outline),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Reason (shown to patients)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in _reasons)
                ChoiceChip(label: Text(r), selected: _reason == r, onSelected: (_) => setState(() => _reason = r)),
            ]),
            const SizedBox(height: 16),
            AppInput(
              label: 'More detail',
              hint: 'e.g. Clinic moved to next Monday',
              controller: _detail,
              maxLines: 2,
              validator: (v) {
                final t = (v ?? '').trim();
                if (_reason == 'Other' && t.isEmpty) return 'Describe the reason';
                if (t.length > 200) return 'Keep the detail under 200 characters';
                return null;
              },
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSizes.radius),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.notifications_active_outlined, color: AppColors.danger),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Each booked patient receives a notification with this reason and is asked '
                      'to book another day. Walk-in patients without the app should be told at the counter.'),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            DangerButton('Cancel session and notify patients', onPressed: _cancel, loading: _busy),
            const SizedBox(height: 12),
            SecondaryButton('Keep session', onPressed: _busy ? null : () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}
