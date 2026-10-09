import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/clinic_session.dart';
import '../../services/queue_service.dart';

/// Opens the queue controls for one clinic: delay, pause and announcements.
/// Patients with the app are notified automatically (F4).
Future<void> showManageQueueSheet(BuildContext context, ClinicSession session) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _ManageQueue(session: session),
  );
}

class _ManageQueue extends StatefulWidget {
  final ClinicSession session;
  const _ManageQueue({required this.session});

  @override
  State<_ManageQueue> createState() => _ManageQueueState();
}

class _ManageQueueState extends State<_ManageQueue> {
  static const _delays = [0, 10, 15, 30, 45, 60, 90];
  static const _pauseReasons = ['Doctor break', 'Emergency case', 'System / power problem', 'Other'];

  final _message = TextEditingController();
  final _msgKey = GlobalKey<FormState>();
  late int _delay = _delays.contains(widget.session.delayMinutes) ? widget.session.delayMinutes : 0;
  String _reason = _pauseReasons.first;
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _run(Future<int> Function() action, String Function(int) done) async {
    setState(() => _busy = true);
    int? n;
    final ok = await runGuarded(context, () async => n = await action());
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      showSnack(context, done(n ?? 0));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Manage queue', style: t.titleLarge),
        Text('${s.department} · ${s.startTime}–${s.endTime}', style: t.bodySmall),
        const SizedBox(height: 16),
        // ---- Delay
        Text('Doctor running late?', style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Patients\' expected times move by this amount and they are told.', style: t.bodySmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final d in _delays)
            ChoiceChip(
              label: Text(d == 0 ? 'On time' : '+$d min'),
              selected: _delay == d,
              onSelected: (_) => setState(() => _delay = d),
            ),
        ]),
        const SizedBox(height: 8),
        SecondaryButton(
          'Apply delay',
          icon: Icons.schedule_send,
          onPressed: _busy || _delay == s.delayMinutes
              ? null
              : () => _run(() => QueueService.setDelay(s, _delay),
                  (n) => 'Delay updated · $n patient${n == 1 ? '' : 's'} notified'),
        ),
        const Divider(height: 32),
        // ---- Pause
        Text('Pause the queue', style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Stops "Call next" until you resume. Use for a break or an emergency.', style: t.bodySmall),
        const SizedBox(height: 8),
        if (s.paused)
          InfoBanner(icon: Icons.pause_circle_outline, color: AppColors.danger, message: 'Paused: ${s.pauseReason}')
        else
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: [for (final r in _pauseReasons) DropdownMenuItem(value: r, child: Text(r))],
            onChanged: (v) => setState(() => _reason = v ?? _reason),
          ),
        const SizedBox(height: 8),
        s.paused
            ? PrimaryButton('Resume queue', icon: Icons.play_arrow, loading: _busy, onPressed: () =>
                _run(() => QueueService.setPaused(s, false), (n) => 'Queue resumed · $n notified'))
            : DangerButton('Pause queue', icon: Icons.pause, loading: _busy, onPressed: () =>
                _run(() => QueueService.setPaused(s, true, reason: _reason), (n) => 'Queue paused · $n notified')),
        const Divider(height: 32),
        // ---- Announcement
        Text('Message to patients', style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Form(
          key: _msgKey,
          child: TextFormField(
            controller: _message,
            maxLines: 2,
            maxLength: 200,
            decoration: const InputDecoration(hintText: 'e.g. Please keep your clinic book and NIC ready'),
            validator: (v) {
              final x = (v ?? '').trim();
              if (x.length < 5) return 'Write at least 5 characters';
              return null;
            },
          ),
        ),
        PrimaryButton(
          'Send to everyone booked',
          icon: Icons.campaign,
          loading: _busy,
          onPressed: () {
            if (!_msgKey.currentState!.validate()) return;
            _run(() => QueueService.broadcast(s, _message.text),
                (n) => 'Message sent to $n patient${n == 1 ? '' : 's'}');
          },
        ),
      ]),
    );
  }
}
