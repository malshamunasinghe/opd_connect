import 'package:flutter/material.dart';

import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/appointment.dart';
import '../../services/db.dart';
import '../../services/queue_service.dart';

/// Reception check-in desk: find today's booking by what the patient shows
/// or says (the QR text "OPD:...", the OPD-reference, token, NIC, mobile
/// number or name) and tick them in. No scrolling through the queue.
/// CRUD: READ today's appointments (live); UPDATE arrived flag.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  late final Stream<List<Appointment>> _today = Db.appointments
      .where('dateKey', isEqualTo: DateKeys.of(DateTime.now()))
      .snapshots()
      .map((q) => q.docs.map(Appointment.fromDoc).toList()..sort((a, b) => a.tokenLabel.compareTo(b.tokenLabel)));
  final _query = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matches(Appointment a) {
    var q = _q;
    if (q.startsWith('opd:')) q = q.substring(4); // text read from the patient's QR code
    if (q.isEmpty) return false;
    return a.id.toLowerCase() == q ||
        a.reference.toLowerCase() == q ||
        a.tokenLabel.toLowerCase().contains(q) ||
        a.patientName.toLowerCase().contains(q) ||
        a.patientPhone.contains(q) ||
        a.patientNic.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Check-in desk')),
      body: StreamView<List<Appointment>>(
        stream: _today,
        builder: (context, all) {
          final active = all.where((a) => a.isActive).toList();
          final results = active.where(_matches).toList();
          final arrived = active.where((a) => a.arrived).length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(child: StatTile(value: '${active.length}', label: 'Booked today', icon: Icons.event_note)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(value: '$arrived', label: 'Checked in', icon: Icons.how_to_reg, color: AppColors.success)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(value: '${active.length - arrived}', label: 'Not here yet', icon: Icons.hourglass_empty, color: AppColors.accent)),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: _query,
                autofocus: true,
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.qr_code_scanner),
                  hintText: 'QR text, OPD-reference, token, NIC, mobile or name',
                  suffixIcon: _q.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _query.clear();
                            _q = '';
                          }),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              if (_q.isEmpty)
                const InfoBanner(
                  icon: Icons.info_outline,
                  message: 'Ask the patient for their token or show-QR reference. A scanner or keyboard that '
                      'types the QR text into this box works too.',
                )
              else if (results.isEmpty)
                const InfoBanner(
                  icon: Icons.search_off,
                  color: AppColors.accent,
                  message: 'No active booking found for today. Check the spelling, or register them as a walk-in '
                      'from the Queue tab.',
                ),
              const SizedBox(height: 8),
              for (final a in results)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          TokenChip(a.tokenLabel, fontSize: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(a.patientName, style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              Text(
                                [
                                  if (a.patientNic.isNotEmpty) a.patientNic,
                                  if (a.patientAge != null) '${a.patientAge} yrs',
                                  if (a.patientPhone.isNotEmpty) a.patientPhone,
                                ].join(' · '),
                                style: t.bodySmall,
                              ),
                            ]),
                          ),
                          if (a.priority) const Pill('Priority', color: AppColors.accent, icon: Icons.star),
                        ]),
                        const SizedBox(height: 8),
                        Text('${a.department} · ${a.startTime} · ${a.doctorName}', style: t.bodyMedium),
                        Text('${a.hospitalName} · ${a.reference}', style: t.bodySmall),
                        if (a.visitReason.isNotEmpty) Text('Reason: ${a.visitReason}', style: t.bodySmall),
                        const SizedBox(height: 12),
                        a.arrived
                            ? Row(children: [
                                const Icon(Icons.check_circle, color: AppColors.success),
                                const SizedBox(width: 8),
                                const Expanded(child: Text('Checked in')),
                                TextButton(
                                  onPressed: () => runGuarded(context, () => QueueService.setArrived(a.id, false)),
                                  child: const Text('Undo'),
                                ),
                              ])
                            : PrimaryButton(
                                'Check in',
                                icon: Icons.how_to_reg,
                                onPressed: () => runGuarded(
                                  context,
                                  () => QueueService.setArrived(a.id, true),
                                  success: '${a.tokenLabel} checked in',
                                ),
                              ),
                      ]),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
