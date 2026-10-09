import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/appointment.dart';
import '../../models/clinic_session.dart';
import '../../services/booking_service.dart';
import '../../services/queue_service.dart';

/// Waiting-room display board. Open it on a tablet or TV at the OPD:
/// the token being served is shown very large, with the next few tokens
/// beneath. It updates by itself as reception calls patients (NF4).
class QueueBoardScreen extends StatefulWidget {
  final ClinicSession session;
  const QueueBoardScreen({super.key, required this.session});

  @override
  State<QueueBoardScreen> createState() => _QueueBoardScreenState();
}

class _QueueBoardScreenState extends State<QueueBoardScreen> {
  late final Stream<ClinicSession?> _session = BookingService.liveSession(widget.session.id);
  late final Stream<List<Appointment>> _appts = QueueService.sessionAppointments(widget.session.id);
  String? _lastServing;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: StreamView<ClinicSession?>(
          stream: _session,
          builder: (context, s) {
            if (s == null) return const EmptyView(icon: Icons.event_busy, message: 'This session no longer exists.');
            // A short beep + vibration when a new token is called.
            if (s.currentTokenLabel != null && s.currentTokenLabel != _lastServing) {
              if (_lastServing != null) {
                HapticFeedback.heavyImpact();
                SystemSound.play(SystemSoundType.alert);
              }
              _lastServing = s.currentTokenLabel;
            }
            return StreamView<List<Appointment>>(
              stream: _appts,
              builder: (context, appts) {
                final byId = {for (final a in appts) a.id: a};
                final next = [
                  for (final id in s.waitingIds.take(6))
                    if (byId[id] != null) byId[id]!
                ];
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Row(children: [
                      IconButton(
                        tooltip: 'Close board',
                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.department,
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          Text('${s.hospitalName} · ${s.doctorName}${s.room.isEmpty ? '' : ' · ${s.room}'}',
                              style: const TextStyle(color: Colors.white70, fontSize: 15)),
                        ]),
                      ),
                      Text('${s.startTime} – ${s.endTime}',
                          style: const TextStyle(color: Colors.white70, fontSize: 18)),
                    ]),
                    const Spacer(),
                    const Text('NOW SERVING',
                        style: TextStyle(color: Colors.white70, fontSize: 22, letterSpacing: 4)),
                    const SizedBox(height: 8),
                    FittedBox(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                        decoration: BoxDecoration(
                          color: s.currentTokenLabel == null ? Colors.white24 : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          s.currentTokenLabel ?? '—',
                          style: TextStyle(
                            fontSize: 120,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: s.currentTokenLabel == null ? Colors.white70 : AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ),
                    if (s.paused)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text('QUEUE PAUSED · ${s.pauseReason}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.accent, fontSize: 22, fontWeight: FontWeight.bold)),
                      )
                    else if (s.delayMinutes > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text('Running about ${s.delayMinutes} minutes late',
                            style: const TextStyle(color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                    if (!s.isActive)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('This clinic has been cancelled',
                            style: TextStyle(color: AppColors.accent, fontSize: 20, fontWeight: FontWeight.bold)),
                      )
                    else if (s.currentTokenLabel == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('The clinic will begin shortly', style: TextStyle(color: Colors.white70, fontSize: 18)),
                      ),
                    const Spacer(),
                    Text('NEXT  ·  ${s.waitingIds.length} waiting',
                        style: const TextStyle(color: Colors.white70, fontSize: 18, letterSpacing: 2)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
                      if (next.isEmpty)
                        const Text('Nobody waiting', style: TextStyle(color: Colors.white54, fontSize: 18)),
                      for (final a in next)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: a.priority ? AppColors.accent : Colors.white12,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(a.tokenLabel,
                              style: TextStyle(
                                  color: a.priority ? AppColors.n900 : Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ]),
                    const Spacer(),
                  ]),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
