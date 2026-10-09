import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/appointment.dart';
import '../../services/queue_service.dart';

class PriorityReasons {
  static const all = [
    'Elderly (70+)',
    'Disability',
    'Pregnant',
    'Urgent / unwell',
    'Child under 5',
    'Other',
  ];
}

/// S10 - Priority flag and queue reorder (F2, F5).
/// Variant B: a long-press opens a reason-capture sheet, so priority is a
/// deliberate, recorded exception rather than a one-tap icon (Staff Q5).
/// Owner: P.A.J. Sithmini (IT23671874)
/// CRUD: READ current flag; UPDATE priority + reason (moves the patient
///       ahead of non-priority patients in the live queue); UPDATE remove.
Future<void> showPrioritySheet(BuildContext context, Appointment a, Set<String> priorityIds) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PrioritySheet(a: a, priorityIds: priorityIds),
  );
}

class _PrioritySheet extends StatefulWidget {
  final Appointment a;
  final Set<String> priorityIds;
  const _PrioritySheet({required this.a, required this.priorityIds});

  @override
  State<_PrioritySheet> createState() => _PrioritySheetState();
}

class _PrioritySheetState extends State<_PrioritySheet> {
  late String _reason;
  final _other = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final current = widget.a.priorityReason;
    if (current != null && PriorityReasons.all.contains(current)) {
      _reason = current;
    } else if (current != null) {
      _reason = 'Other';
      _other.text = current;
    } else {
      _reason = PriorityReasons.all.first;
    }
  }

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  Future<void> _save(bool priority) async {
    var reason = _reason;
    if (_reason == 'Other') {
      final detail = _other.text.trim();
      if (detail.length < 3 || detail.length > 100) {
        showSnack(context, 'Describe the reason in 3 to 100 characters', error: true);
        return;
      }
      reason = _other.text.trim();
    }
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => QueueService.setPriority(
        appointment: widget.a,
        priority: priority,
        reason: reason,
        currentPriorityIds: widget.priorityIds,
      ),
      success: priority ? '${widget.a.tokenLabel} moved up as priority' : 'Priority removed',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            TokenChip(a.tokenLabel, fontSize: 18, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(child: Text(a.patientName, style: Theme.of(context).textTheme.titleLarge)),
          ]),
          const SizedBox(height: 16),
          const Text('Reason for priority', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in PriorityReasons.all)
              ChoiceChip(
                label: Text(r),
                selected: _reason == r,
                onSelected: (_) => setState(() => _reason = r),
              ),
          ]),
          if (_reason == 'Other') ...[
            const SizedBox(height: 12),
            TextField(controller: _other, decoration: const InputDecoration(hintText: 'Describe the reason')),
          ],
          const SizedBox(height: 16),
          Text(
            'Priority patients are placed after any other priority patients but ahead of everyone else.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.n900),
            onPressed: _busy ? null : () => _save(true),
            icon: const Icon(Icons.star),
            label: Text(a.priority ? 'Update priority' : 'Flag as priority'),
          ),
          if (a.priority) ...[
            const SizedBox(height: 8),
            SecondaryButton('Remove priority', onPressed: _busy ? null : () => _save(false)),
          ],
        ]),
      ),
    );
  }
}
