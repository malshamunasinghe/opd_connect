import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// Help & support: how-to answers, what to bring, emergency numbers.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faq = [
    (
      'How do I book an appointment?',
      'Tap "Book appointment" on the home screen. Choose a hospital, then a clinic and a day, '
          'review the details and confirm. You get a token number straight away.'
    ),
    (
      'What is a token number?',
      'It is your place in the queue, for example A-012. Show it at the OPD counter. The live queue '
          'screen shows which token is being seen now and how many people are ahead of you.'
    ),
    (
      'Can I change or cancel a booking?',
      'Yes. Open Appointments, then choose Reschedule or Cancel. You can change a booking until the '
          'doctor starts seeing you. Cancelling frees your place for another patient.'
    ),
    (
      'How will I know when it is my turn?',
      'The app alerts you when your turn is near and again when it is your turn. Keep the app open '
          'or check Notifications. You can also open the live queue at any time.'
    ),
    (
      'I booked but cannot come. What should I do?',
      'Please cancel so another patient can use your place. Missed appointments are marked as no-shows.'
    ),
    (
      'What should I bring?',
      'Your NIC, your clinic book or previous reports, and any medicines you are taking. Arrive 15 minutes early.'
    ),
    (
      'Why can I not book a clinic?',
      'A clinic day may be full, cancelled or already finished. Try another day, or ask at the OPD counter.'
    ),
    (
      'How do I change the language or text size?',
      'Go to Settings. You can choose English, Sinhala or Tamil, make the text larger, or turn on high contrast.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('help'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: AppColors.danger.withValues(alpha: 0.06),
            child: const ListTile(
              leading: Icon(Icons.local_phone, color: AppColors.danger, size: 32),
              title: Text('Emergency: 1990', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text('Suwa Seriya free ambulance, 24 hours. Police 119. Do not wait in an OPD queue for an emergency.'),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 12),
          const InfoBanner(
            icon: Icons.health_and_safety_outlined,
            message: 'Health hotline 1999 (Ministry of Health) for general health information.',
          ),
          const SizedBox(height: 16),
          Text(s.t('faq'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final q in _faq)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(q.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(q.$2)],
              ),
            ),
          const SizedBox(height: 16),
          Center(
            child: Text('OPD Connect 1.0 · IT3060 HCI, Group WE_81',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
