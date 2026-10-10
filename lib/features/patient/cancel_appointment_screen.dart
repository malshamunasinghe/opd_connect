import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/appointment.dart';
import '../../services/booking_service.dart';

/// S06 - Cancel appointment (F1, F5).
/// Variant B: repeats what is being cancelled, captures a reason and states
/// the consequence (the place is released to another patient).
/// Owner: Lakmali M.A.D.M (IT23679344)
/// CRUD: READ the appointment; UPDATE status to cancelled and UPDATE the
///       session (place released, removed from live queue).
class CancelAppointmentScreen extends StatefulWidget {
  final Appointment appointment;
  const CancelAppointmentScreen({super.key, required this.appointment});

  @override
  State<CancelAppointmentScreen> createState() => _CancelAppointmentScreenState();
}

class _CancelAppointmentScreenState extends State<CancelAppointmentScreen> {
  static const _reasons = ['reason_better', 'reason_clash', 'reason_transport', 'reason_wrong', 'reason_other'];
  String? _reason;
  final _other = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    final s = context.read<AppSettings>();
    if (_reason == null) {
      showSnack(context, s.t('cancelReason'), error: true);
      return;
    }
    // Stored in English so staff reports read consistently.
    var reasonText = S.of('en', _reason!);
    if (_reason == 'reason_other') {
      final detail = _other.text.trim();
      if (detail.length < 3) {
        showSnack(context, 'Please describe your reason (at least 3 characters)', error: true);
        return;
      }
      if (detail.length > 150) {
        showSnack(context, 'Please keep the reason under 150 characters', error: true);
        return;
      }
      reasonText = 'Other: $detail';
    }
    setState(() => _busy = true);
    final ok = await runGuarded(context, () => BookingService.cancel(widget.appointment, reasonText),
        success: s.t('status_cancelled'));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final a = widget.appointment;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('cancel'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppointmentCard(appointment: a, statusText: s.t('status_${a.status}')),
          const SizedBox(height: 24),
          Text(s.t('cancelReason'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v),
            child: Column(children: [
              for (final r in _reasons)
                RadioListTile<String>(value: r, title: Text(s.t(r)), contentPadding: EdgeInsets.zero),
            ]),
          ),
          if (_reason == 'reason_other') AppInput(label: s.t('reason_other'), controller: _other, maxLines: 2),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
  color: AppColors.danger.withValues(alpha: 0.12),
  border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
  borderRadius: BorderRadius.circular(AppSizes.radius),
),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(s.t('cancelConsequence'))),
            ]),
          ),
          const SizedBox(height: 24),
          DangerButton(s.t('yesCancel'), onPressed: _cancel, loading: _busy),
          const SizedBox(height: 12),
          SecondaryButton(s.t('keepAppointment'), onPressed: _busy ? null : () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
