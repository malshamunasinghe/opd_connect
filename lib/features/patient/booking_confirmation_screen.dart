import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/appointment.dart';
import '../../services/booking_service.dart';
import 'live_queue_screen.dart';

/// S03 - Booking confirmation and token (F1, F4).
/// Variant B: the token is shown first and largest. Includes the explicit
/// success state + booking reference added after M02 usability issue U1.
/// Owner: Lakmali M.A.D.M (IT23679344)
/// CRUD: READ appointment; UPDATE reminder on/off.
class BookingConfirmationScreen extends StatelessWidget {
  final String appointmentId;
  const BookingConfirmationScreen({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('bookingConfirmed')), automaticallyImplyLeading: false),
      body: StreamView<Appointment?>(
        stream: BookingService.appointment(appointmentId),
        loadingMessage: s.t('loading'),
        builder: (context, a) {
          if (a == null) return EmptyView(icon: Icons.search_off, message: s.t('somethingWrong'));
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Center(child: Icon(Icons.check_circle, color: AppColors.success, size: 72)),
              const SizedBox(height: 8),
              Text(s.t('bookingConfirmed'), textAlign: TextAlign.center, style: t.headlineMedium),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSizes.radius),
                ),
                child: Column(children: [
                  Text(s.t('yourToken'), style: const TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  Semantics(
                    label: '${s.t('yourToken')} ${a.tokenLabel}',
                    child: Text(a.tokenLabel,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                  const SizedBox(height: 4),
                  Text(s.t('showAtCounter'),
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ]),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    InfoRow(s.t('reference'), a.reference, icon: Icons.confirmation_number_outlined),
                    InfoRow(s.t('patientLabel'), a.patientName, icon: Icons.person),
                    if (a.patientNic.isNotEmpty) InfoRow('NIC', a.patientNic, icon: Icons.badge_outlined),
                    InfoRow(s.t('contact'), a.patientPhone, icon: Icons.phone_outlined),
                    InfoRow(s.t('hospital'), a.hospitalName, icon: Icons.local_hospital_outlined),
                    InfoRow(s.t('clinic'), a.department, icon: Icons.medical_services_outlined),
                    InfoRow(s.t('doctor'), a.doctorName, icon: Icons.person_outline),
                    InfoRow(s.t('date'), formatDay(a.date), icon: Icons.event),
                    InfoRow(s.t('time'), a.startTime, icon: Icons.schedule),
                    if (a.visitReason.isNotEmpty) InfoRow(s.t('reasonLabel'), a.visitReason, icon: Icons.notes),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              const InfoBanner(
                icon: Icons.checklist,
                message: 'On the day: bring your NIC, arrive 15 minutes early, and tap "I\'m at the hospital" '
                    'in the live queue so reception knows you are here.',
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: a.reminderEnabled,
                onChanged: (v) => runGuarded(context, () => BookingService.setReminder(a.id, v), success: s.t('saved')),
                title: Text(s.t('remindMe')),
                secondary: const Icon(Icons.notifications_active_outlined),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                s.t('viewLiveQueue'),
                icon: Icons.people_alt_outlined,
                onPressed: () => Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => LiveQueueScreen(appointmentId: a.id))),
              ),
              const SizedBox(height: 12),
              SecondaryButton(s.t('done'), onPressed: () => Navigator.popUntil(context, (r) => r.isFirst)),
            ],
          );
        },
      ),
    );
  }
}
