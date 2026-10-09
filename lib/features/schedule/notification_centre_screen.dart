import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/app_settings.dart';
import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/app_notification.dart';
import '../../services/schedule_service.dart';
import '../patient/live_queue_screen.dart';

/// S19 - Notification centre (F4). Booking confirmations, reminders,
/// near-turn alerts and clinic changes/cancellations in one place, grouped
/// by day and filterable.
/// Owner: Nethmini K (IT23669130)
/// CRUD: READ notifications (live); UPDATE read / mark all read;
///       DELETE (swipe to dismiss, or clear all read).
class NotificationCentreScreen extends StatefulWidget {
  const NotificationCentreScreen({super.key});

  @override
  State<NotificationCentreScreen> createState() => _NotificationCentreScreenState();
}

class _NotificationCentreScreenState extends State<NotificationCentreScreen> {
  late final _stream = ScheduleService.notifications(me(context).uid);
  List<AppNotification> _latest = const [];
  String _filter = 'all';

  static const _filters = {
    'all': 'all',
    'unread': 'f_unread',
    'queue': 'f_queue',
    'booking': 'f_bookings',
    'changes': 'f_changes',
  };

  bool _inFilter(AppNotification n) {
    switch (_filter) {
      case 'unread':
        return !n.read;
      case 'queue':
        return n.type == NotificationTypes.nearTurn;
      case 'booking':
        return n.type == NotificationTypes.booking || n.type == NotificationTypes.reminder;
      case 'changes':
        return n.type == NotificationTypes.sessionChanged || n.type == NotificationTypes.sessionCancelled;
      default:
        return true;
    }
  }

  static IconData _icon(String type) {
    switch (type) {
      case NotificationTypes.booking:
        return Icons.check_circle_outline;
      case NotificationTypes.reminder:
        return Icons.alarm;
      case NotificationTypes.nearTurn:
        return Icons.campaign_outlined;
      case NotificationTypes.sessionChanged:
        return Icons.edit_calendar;
      case NotificationTypes.sessionCancelled:
        return Icons.event_busy;
      default:
        return Icons.notifications_none;
    }
  }

  static Color _color(String type) {
    switch (type) {
      case NotificationTypes.nearTurn:
        return AppColors.accent;
      case NotificationTypes.sessionCancelled:
        return AppColors.danger;
      case NotificationTypes.booking:
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  String _dayLabel(DateTime? d) {
    if (d == null) return 'Just now';
    final today = DateKeys.dayOnly(DateTime.now());
    final diff = today.difference(DateKeys.dayOnly(d)).inDays;
    if (diff <= 0) return context.read<AppSettings>().t('today');
    if (diff == 1) return context.read<AppSettings>().t('yesterday');
    return formatDay(d);
  }

  Future<void> _clearRead() async {
    final read = _latest.where((n) => n.read).toList();
    if (read.isEmpty) {
      showSnack(context, 'No read notifications to clear');
      return;
    }
    final ok = await confirm(context,
        title: 'Clear read notifications?',
        message: '${read.length} notification(s) will be deleted.',
        confirmLabel: 'Clear',
        danger: true);
    if (!ok || !mounted) return;
    await runGuarded(context, () => ScheduleService.deleteMany(read.map((n) => n.id).toList()),
        success: 'Cleared');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('notifications')),
        actions: [
          IconButton(
            tooltip: s.t('markAllRead'),
            icon: const Icon(Icons.done_all),
            onPressed: () => runGuarded(context, () => ScheduleService.markAllRead(_latest)),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') _clearRead();
            },
            itemBuilder: (_) => [PopupMenuItem(value: 'clear', child: Text(s.t('clearRead')))],
          ),
        ],
      ),
      body: StreamView<List<AppNotification>>(
        stream: _stream,
        builder: (context, items) {
          _latest = items;
          if (items.isEmpty) return EmptyView(icon: Icons.notifications_none, message: s.t('noNotifications'));
          final unread = items.where((n) => !n.read).length;
          final shown = items.where(_inFilter).toList();

          // Group by day, newest first (the list is already sorted).
          final rows = <Object>[];
          String? last;
          for (final n in shown) {
            final label = _dayLabel(n.createdAt);
            if (label != last) {
              rows.add(label);
              last = label;
            }
            rows.add(n);
          }

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(unread == 0 ? s.t('allCaughtUp') : s.tf('nUnread', {'n': '$unread'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final e in _filters.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s.t(e.value)),
                          selected: _filter == e.key,
                          onSelected: (_) => setState(() => _filter = e.key),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
            Expanded(
              child: shown.isEmpty
                  ? EmptyView(icon: Icons.filter_list_off, message: s.t('nothingFilter'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final row = rows[i];
                        if (row is String) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: Text(row, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          );
                        }
                        return Padding(padding: const EdgeInsets.only(bottom: 8), child: _tile(context, row as AppNotification));
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _tile(BuildContext context, AppNotification n) {
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(AppSizes.radius),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => runGuarded(context, () => ScheduleService.deleteNotification(n.id)),
      child: Card(
        color: n.read ? null : _color(n.type).withValues(alpha: 0.08),
        child: ListTile(
          minVerticalPadding: 12,
          leading: Icon(_icon(n.type), color: _color(n.type), size: 30),
          title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
          subtitle: Text('${n.body}${n.createdAt == null ? '' : '\n${formatDateTime(n.createdAt!)}'}'),
          isThreeLine: n.createdAt != null,
          trailing: n.read ? null : const Icon(Icons.circle, size: 12, color: AppColors.primary),
          onTap: () {
            if (!n.read) ScheduleService.markRead(n.id).catchError((_) {});
            if (n.appointmentId != null && n.type != NotificationTypes.sessionCancelled) {
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => LiveQueueScreen(appointmentId: n.appointmentId!)));
            }
          },
        ),
      ),
    );
  }
}
